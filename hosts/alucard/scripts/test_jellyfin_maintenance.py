"""Run with: python3 -m unittest discover -s hosts/alucard/scripts -v."""

import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import urllib.error

SPEC = importlib.util.spec_from_file_location(
    "jellyfin_maintenance", Path(__file__).with_name("jellyfin-maintenance.py"))
maintenance = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(maintenance)


def tasks():
    return [{"Id": f"{index:032x}", "Key": key, "Name": key,
             "State": "Running", "Triggers": [{"Type": "IntervalTrigger",
                                                 "IntervalTicks": 864_000_000_000}]}
            for index, key in enumerate(maintenance.SCHEDULE, 1)]


class MaintenanceTests(unittest.TestCase):
    def test_daily_weekly_ticks_and_runtime(self):
        original = tasks()
        original[0]["Triggers"][0]["MaxRuntimeTicks"] = 123456
        changes = {key: desired for key, _, _, desired in maintenance.plan(original)}
        self.assertEqual(changes["RefreshLibrary"], [{
            "Type": "DailyTrigger", "TimeOfDayTicks": 72_000_000_000,
            "MaxRuntimeTicks": 123456}])
        self.assertEqual(changes["RefreshPeople"], [{
            "Type": "WeeklyTrigger", "TimeOfDayTicks": 177_000_000_000,
            "DayOfWeek": "Sunday"}])
        self.assertEqual(changes["TmdbRefreshUpcomingEpisodes"][0]["TimeOfDayTicks"],
                         189_000_000_000)
        self.assertNotIn("MaxRuntimeTicks", changes["PluginUpdates"][0])

    def test_required_missing_and_bad_late_id_make_no_changes(self):
        for invalid in ([t for t in tasks() if t["Key"] != "PluginUpdates"], tasks()):
            if len(invalid) == len(maintenance.SCHEDULE):
                invalid[-1]["Id"] = "../bad"
            api = Mock()
            with tempfile.TemporaryDirectory() as directory:
                with self.assertRaises(maintenance.ConfigurationError):
                    maintenance.apply(api, invalid, Path(directory))
                self.assertEqual(list(Path(directory).iterdir()), [])
            api.request.assert_not_called()

    def test_startup_disabled_optional_and_unknown(self):
        original = tasks()
        startup = {"Type": "StartupTrigger", "MaxRuntimeTicks": 100}
        for task in original:
            if task["Key"] in {"DeleteTranscodeFiles", "PluginUpdates"}:
                task["Triggers"] = [copy.deepcopy(startup)]
            if task["Key"] in {"DownloadLyrics", "RefreshLibrary"}:
                task["Triggers"] = []
        original.append({"Key": "UnknownPlugin", "Id": "not-our-id", "Triggers": []})
        changes = {key: desired for key, _, _, desired in maintenance.plan(original)}
        self.assertEqual(changes["DeleteTranscodeFiles"][1], startup)
        self.assertEqual([t["Type"] for t in changes["PluginUpdates"]], ["DailyTrigger"])
        self.assertNotIn("DownloadLyrics", changes)
        self.assertNotIn("UnknownPlugin", changes)
        self.assertIn("RefreshLibrary", changes)

    def test_apply_readback_idempotence_backup_and_running_tasks(self):
        original = tasks()
        current = copy.deepcopy(original)
        posts = []

        def request(method="GET", task_id=None, triggers=None):
            if method == "POST":
                posts.append(task_id)
                next(t for t in current if t["Id"] == task_id)["Triggers"] = copy.deepcopy(triggers)
            else:
                return copy.deepcopy(current)

        api = Mock()
        api.request.side_effect = request
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            self.assertEqual(maintenance.apply(api, original, state), len(original))
            backup = state / "original-triggers.json"
            saved = backup.read_bytes()
            self.assertEqual(len(json.loads(saved)), len(original))
            self.assertEqual(backup.stat().st_mode & 0o777, 0o600)
            self.assertEqual(maintenance.apply(api, current, state), 0)
            current[0]["Triggers"] = original[0]["Triggers"]
            self.assertEqual(maintenance.apply(api, current, state), 1)
            self.assertEqual(backup.read_bytes(), saved)
        self.assertEqual(len(posts), len(original) + 1)
        self.assertTrue(all(t["State"] == "Running" for t in current))

    def test_failed_readback_is_not_success(self):
        api = Mock()
        api.request.side_effect = [None, tasks()]
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(maintenance.ConfigurationError, "partial changes may remain"):
                maintenance.apply(api, tasks(), Path(directory))
            self.assertTrue((Path(directory) / "original-triggers.json").exists())
        self.assertEqual(api.request.call_count, 2)

    def test_authorization_header_and_post_payload(self):
        response = Mock()
        response.__enter__ = Mock(return_value=io.BytesIO(b"[]"))
        response.__exit__ = Mock(return_value=False)
        with patch.object(maintenance.urllib.request, "urlopen", return_value=response) as open_url:
            api = maintenance.API("test-credential")
            self.assertEqual(api.request(), [])
            request = open_url.call_args.args[0]
            self.assertEqual(request.get_header("Authorization"),
                             'MediaBrowser Token="test-credential"')
            self.assertIsNone(request.get_header("X-emby-token"))
            payload = [{"Type": "DailyTrigger", "TimeOfDayTicks": 72_000_000_000}]
            api.request("POST", "1" * 32, payload)
            request = open_url.call_args.args[0]
            self.assertEqual(request.method, "POST")
            self.assertEqual(request.full_url, maintenance.BASE_URL + "/" + "1" * 32 + "/Triggers")
            self.assertEqual(json.loads(request.data), payload)

    def test_connect_tries_next_key_and_retries_unavailable(self):
        database = Mock()
        database.__enter__ = Mock(return_value=database)
        database.__exit__ = Mock(return_value=False)
        database.execute.return_value = [("expired",), ("valid",)]
        unauthorized = urllib.error.HTTPError(maintenance.BASE_URL, 401, "unauthorized", {}, None)
        unavailable = urllib.error.URLError("unavailable")
        with patch.object(maintenance.sqlite3, "connect", return_value=database) as connect, \
                patch.object(maintenance.API, "request", side_effect=[unavailable, unauthorized, []]), \
                patch.object(maintenance.time, "sleep"):
            api, result = maintenance.connect()
        self.assertEqual(api.token, "valid")
        self.assertEqual(result, [])
        connect.assert_called_once_with(maintenance.DATABASE, uri=True)
        self.assertIn("mode=ro", maintenance.DATABASE)


if __name__ == "__main__":
    unittest.main()
