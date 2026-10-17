#!/usr/bin/env python3
"""Configure Jellyfin maintenance triggers through its supported local API."""

import argparse
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import tempfile
import time
import urllib.error
import urllib.request

BASE_URL = "http://127.0.0.1:8096/ScheduledTasks"
DATABASE = "file:/home/jellyfin/data/jellyfin.db?mode=ro"
SCHEDULE = {
    "RefreshLibrary": (2, 0),
    "TaskExtractMediaSegments": (2, 15),
    "RefreshChapterImages": (2, 30),
    "RefreshTrickplayImages": (2, 45),
    "AudioNormalization": (3, 5),
    "OptimizeDatabaseTask": (3, 15),
    "DownloadLyrics": (4, 40),
    "DownloadSubtitles": (4, 45),
    "RefreshPeople": (4, 55),
    "PluginUpdates": (5, 0),
    "RefreshInternetChannels": (5, 5),
    "RefreshGuide": (5, 10),
    "TmdbRefreshUpcomingEpisodes": (5, 15),
    "DeleteCacheFiles": (5, 20),
    "CleanLogFiles": (5, 25),
    "DeleteTranscodeFiles": (5, 30),
}
REQUIRED = {
    "RefreshLibrary", "TaskExtractMediaSegments", "RefreshChapterImages",
    "RefreshTrickplayImages", "OptimizeDatabaseTask", "PluginUpdates",
}
WEEKLY = {"RefreshPeople", "TmdbRefreshUpcomingEpisodes"}


class ConfigurationError(Exception):
    """A safe-to-display error, never containing API responses or credentials."""


def normalized(triggers):
    # Jellyfin can return absent optional fields as null, and reorder triggers.
    return sorted(json.dumps({k: v for k, v in t.items() if v is not None},
                             sort_keys=True) for t in triggers)


def plan(tasks):
    if not isinstance(tasks, list) or any(not isinstance(t, dict) for t in tasks):
        raise ConfigurationError("Invalid scheduled-task response")
    selected = {}
    for task in tasks:
        key = task.get("Key")
        if key not in SCHEDULE:
            continue
        if key in selected:
            raise ConfigurationError("Duplicate scheduled-task key")
        selected[key] = task
    if REQUIRED - selected.keys():
        raise ConfigurationError("Required scheduled-task keys missing: " +
                                 ", ".join(sorted(REQUIRED - selected.keys())))
    changes = []
    ids = set()
    for key, task in selected.items():
        task_id = task.get("Id")
        if not isinstance(task_id, str) or not re.fullmatch(
                r"[0-9a-fA-F]{32}|[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", task_id):
            raise ConfigurationError("Invalid scheduled-task ID")
        if task_id.lower().replace("-", "") in ids:
            raise ConfigurationError("Duplicate scheduled-task ID")
        ids.add(task_id.lower().replace("-", ""))
        original = task.get("Triggers")
        if not isinstance(original, list) or any(not isinstance(t, dict) for t in original):
            raise ConfigurationError("Invalid scheduled-task triggers")
        if not original and key not in REQUIRED:
            continue
        limits = [t["MaxRuntimeTicks"] for t in original
                  if t.get("MaxRuntimeTicks") is not None]
        if any(type(v) is not int or v < 0 for v in limits) or len(set(limits)) > 1:
            raise ConfigurationError("Invalid or conflicting task runtime limits")
        hour, minute = SCHEDULE[key]
        # Jellyfin interprets these wall-clock ticks in its host timezone (Europe/Berlin).
        trigger = {"Type": "WeeklyTrigger" if key in WEEKLY else "DailyTrigger",
                   "TimeOfDayTicks": (hour * 3600 + minute * 60) * 10_000_000}
        if key in WEEKLY:
            trigger["DayOfWeek"] = "Sunday"
        if limits:
            trigger["MaxRuntimeTicks"] = limits[0]
        desired = [trigger]
        if key == "DeleteTranscodeFiles":
            desired += [t for t in original if t.get("Type") == "StartupTrigger"]
        # Validate serialization before any backup or API writes.
        json.dumps(desired, allow_nan=False)
        if normalized(original) != normalized(desired):
            changes.append((key, task_id, original, desired))
    return changes


class API:
    def __init__(self, token):
        self.token = token

    def request(self, method="GET", task_id=None, triggers=None):
        url = BASE_URL if task_id is None else f"{BASE_URL}/{task_id}/Triggers"
        data = None if triggers is None else json.dumps(triggers, allow_nan=False).encode()
        request = urllib.request.Request(
            url, data=data, method=method,
            headers={"Authorization": f'MediaBrowser Token="{self.token}"',
                     "Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=5) as response:
            return json.load(response) if method == "GET" else None


def connect():
    with sqlite3.connect(DATABASE, uri=True) as database:
        tokens = [row[0] for row in database.execute(
            'SELECT AccessToken FROM ApiKeys ORDER BY DateLastActivity DESC')]
    tokens = [t for t in tokens if isinstance(t, str) and t and
              all(32 <= ord(c) < 127 and c not in '\\"' for c in t)]
    if not tokens:
        raise ConfigurationError("No usable Jellyfin API keys")
    deadline = time.monotonic() + 120
    while True:
        unavailable = False
        for token in tokens:
            api = API(token)
            try:
                return api, api.request()
            except urllib.error.HTTPError as error:
                if error.code == 401:
                    continue
                if error.code < 500:
                    raise ConfigurationError("Jellyfin API rejected authentication/request") from None
                unavailable = True
                break
            except (urllib.error.URLError, TimeoutError, OSError):
                unavailable = True
                break
        if not unavailable:
            raise ConfigurationError("All Jellyfin API keys were rejected")
        if time.monotonic() >= deadline:
            raise ConfigurationError("Jellyfin API unavailable after startup wait")
        time.sleep(2)


def backup_once(directory, tasks):
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = directory.lstat()
    if directory.is_symlink() or not directory.is_dir() or info.st_uid != os.geteuid() or info.st_mode & 0o077:
        raise ConfigurationError("State directory must be private and owned by the running user")
    target = directory / "original-triggers.json"
    with tempfile.NamedTemporaryFile(mode="w", dir=directory, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            json.dump([{k: task[k] for k in ("Key", "Id", "Triggers")}
                       for task in tasks if task.get("Key") in SCHEDULE], stream)
            stream.flush()
            os.fsync(stream.fileno())
            try:
                os.link(temporary, target)
            except FileExistsError:
                pass
        finally:
            temporary.unlink()


def apply(api, tasks, directory):
    changes = plan(tasks)
    if not changes:
        return 0
    backup_once(directory, tasks)
    completed = 0
    try:
        for key, task_id, original, desired in changes:
            api.request("POST", task_id, desired)
            actual = api.request()
            matches = [t for t in actual if t.get("Id") == task_id]
            if len(matches) != 1 or normalized(matches[0]["Triggers"]) != normalized(desired):
                raise ConfigurationError("Trigger readback mismatch")
            completed += 1
    except Exception:
        raise ConfigurationError(
            f"Trigger update failed after {completed} verified updates; partial changes may remain. "
            "Original triggers are in the state-directory backup; no tasks were stopped or restarted.") from None
    return completed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-directory", type=Path,
                        default=Path("/var/lib/jellyfin-maintenance"))
    args = parser.parse_args()
    if os.geteuid() != 0 or not args.state_directory.is_absolute():
        parser.error("Run as root with an absolute --state-directory")
    try:
        api, tasks = connect()
        count = apply(api, tasks, args.state_directory)
    except ConfigurationError as error:
        print(str(error), file=sys.stderr)
        return 1
    except Exception as error:
        # Exception text can contain response content, SQL, or credentials.
        print(f"Jellyfin maintenance failed ({type(error).__name__})", file=sys.stderr)
        return 1
    print(f"Jellyfin maintenance: {count} task trigger sets updated and verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
