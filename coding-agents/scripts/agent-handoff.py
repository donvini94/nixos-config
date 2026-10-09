#!/usr/bin/env python3
"""Explicit, conflict-checked Pi/OMP session and SQLite-memory handoff over SSH."""
from __future__ import annotations

import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
from typing import Any, Iterator

CONFIG = Path(__file__).resolve().parents[1] / "handoff.json"
STATE = Path.home() / ".local/state/agent-handoff"


def run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[Any]:
    return subprocess.run(args, check=True, timeout=600, **kwargs)


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def save_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    atomic_write(path, (json.dumps(data, indent=2) + "\n").encode())


def atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".handoff-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
        os.chmod(name, 0o600)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def identity(config: dict[str, Any]) -> str:
    matches = [name for name, host in config["hosts"].items() if host["home"] == str(Path.home())]
    if len(matches) != 1:
        raise ValueError("This HOME must identify exactly one host in handoff.json")
    return matches[0]


def translate(path: str, source: str, target: str, config: dict[str, Any]) -> str:
    for mapping in sorted(config["paths"], key=lambda item: len(item[source]), reverse=True):
        root = mapping[source]
        if path == root or path.startswith(root + "/"):
            return mapping[target] + path[len(root):]
    raise ValueError(f"No {source}-to-{target} mapping for {path}; add an explicit mapping")


def agent_dir(client: str) -> Path:
    return Path.home() / f".{client}/agent"


def header(path: Path) -> dict[str, Any]:
    with path.open() as stream:
        for line in stream:
            entry = json.loads(line)
            if entry.get("type") == "session":
                return entry
    raise ValueError(f"Missing session header: {path}")


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def sqlite_snapshot(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(source.as_uri() + "?mode=ro", uri=True, timeout=30) as src:
        with sqlite3.connect(target) as dest:
            src.backup(dest)
            if dest.execute("PRAGMA integrity_check").fetchone() != ("ok",):
                raise ValueError(f"SQLite integrity check failed: {source}")
    target.chmod(0o600)


def sqlite_digest(path: Path) -> str:
    # Logical content, not WAL placement or SQLite page layout.
    with sqlite3.connect(path.as_uri() + "?mode=ro", uri=True, timeout=30) as db:
        result = hashlib.sha256()
        for statement in db.iterdump():
            result.update(statement.encode())
            result.update(b"\n")
        return result.hexdigest()


@contextlib.contextmanager
def exclusive(path: Path) -> Iterator[None]:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise ValueError(f"Active session or handoff owns {path}") from error
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def memory_files(client: str) -> list[Path]:
    root = agent_dir(client)
    if client == "pi":
        files = [root / name for name in ("AGENTS.md", "MEMORY.md") if (root / name).is_file()]
        if (root / "memory").exists():
            files.extend(path for path in (root / "memory").rglob("*") if path.is_file())
        return sorted(files)
    return sorted((root / "memories").rglob("*.db"))


def memory_fingerprints(client: str) -> dict[str, str]:
    root = agent_dir(client)
    return {str(path.relative_to(root)): sqlite_digest(path) if path.suffix == ".db" else digest(path)
            for path in memory_files(client)}


def ensure_memory_idle(client: str) -> None:
    if client == "omp":
        # Never replace databases that a running OMP process may have open.
        result = run(["ps", "-u", str(os.getuid()), "-o", "args="], capture_output=True, text=True)
        if any(re.search(r"(?:^|/)omp(?:\s|$)", line.strip()) for line in result.stdout.splitlines()):
            raise ValueError("Close all destination OMP processes before importing OMP memory; use --session-only otherwise")


def safe_extract(archive: Path, destination: Path) -> None:
    with tarfile.open(archive) as bundle:
        for item in bundle.getmembers():
            relative = Path(item.name)
            if relative.is_absolute() or ".." in relative.parts or not (item.isfile() or item.isdir()):
                raise ValueError(f"Unsafe handoff archive member: {item.name}")
        bundle.extractall(destination)


def endpoint(peer: str, config: dict[str, Any], args: list[str]) -> list[str]:
    command = [str(Path(config["hosts"][peer]["home"]) / ".local/bin/agent-handoff"), *args]
    return ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", config["hosts"][peer]["ssh"], shlex.join(command)]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=CONFIG)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("push", "pull"):
        command = sub.add_parser(name)
        command.add_argument("client", choices=("pi", "omp"))
        command.add_argument("session", help="Unique session ID or ID prefix")
        command.add_argument("--peer", help="Defaults to the other configured host")
        command.add_argument("--session-only", action="store_true", help="Do not transfer memory")
    for name in ("export", "import"):
        command = sub.add_parser(name)
        command.add_argument("archive", type=Path)
        if name == "export":
            command.add_argument("client", choices=("pi", "omp"))
            command.add_argument("session")
            command.add_argument("--target", required=True)
            command.add_argument("--session-only", action="store_true")
        else:
            command.add_argument("--initial", action="store_true", help="Initial authoritative memory cutover; existing sessions still protected")
    args = parser.parse_args()
    config = load_json(args.config)
    local = identity(config)
    STATE.mkdir(parents=True, exist_ok=True)
    with exclusive(STATE / "handoff.lock"):
        dispatch(args, local, config)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, sqlite3.Error, subprocess.SubprocessError) as error:
        print(f"agent-handoff: {error}", file=sys.stderr)
        sys.exit(1)
