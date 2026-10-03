"""Preserve UI-owned Hermes state around upstream Nix activation."""

import argparse
import json
import os
import shutil
import tempfile
from pathlib import Path

import yaml
from dotenv import dotenv_values


def atomic_write(path, text, mode=0o600):
    owner = path.stat() if path.exists() else path.parent.stat()
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(text)
        os.chmod(temporary, mode)
        os.chown(temporary, owner.st_uid, owner.st_gid)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def merge_defaults(defaults, existing):
    result = dict(defaults)
    for key, value in existing.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge_defaults(result[key], value)
        else:
            result[key] = value
    return result


def environment(path):
    return {
        key: value
        for key, value in dotenv_values(path, interpolate=False).items()
        if value is not None
    }


def render_env(values):
    # Quoting preserves spaces, multiline credentials, dollar signs and literal backslashes.
    return "".join(
        f"{key}='" + value.replace("\\", "\\\\").replace("'", "\\'") + "'\n"
        for key, value in values.items()
    )


def capture(home, scratch):
    if (home / "config.yaml").exists():
        config = yaml.safe_load((home / "config.yaml").read_text())
        if not isinstance(config, dict):
            raise ValueError("Refusing activation over invalid Hermes configuration")
    scratch.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(scratch, 0o700)
    previous = home / ".nix-env-keys.json"
    marker = home / ".managed"
    snapshot = {
        "legacy": marker.exists() and marker.read_text().strip() in ("nixos", "true"),
        "env": environment(home / ".env"),
        "managed": json.loads(previous.read_text()) if previous.exists() else [],
    }
    atomic_write(scratch / "snapshot.json", json.dumps(snapshot))


def restore(home, scratch, defaults, policy):
    snapshot = json.loads((scratch / "snapshot.json").read_text())
    declared = environment(home / ".env")
    retained = {
        key: value
        for key, value in snapshot["env"].items()
        if key not in snapshot["managed"]
    }
    atomic_write(home / ".env", render_env({**retained, **declared}), 0o640)
    atomic_write(home / ".nix-env-keys.json", json.dumps(list(declared)), 0o640)
    existing = yaml.safe_load((home / "config.yaml").read_text())
    # Drop the old deployment's matching default-model context override once, so discovery
    # can supply it. Preserve unrelated per-model overrides and any changed model preference.
    selected = existing.get("model", {})
    if (
        snapshot.get("legacy")
        and isinstance(selected, dict)
        and selected.get("default") == defaults["model"]["default"]
    ):
        name = defaults["model"]["provider"].removeprefix("custom:")
        models = existing.get("providers", {}).get(name, {}).get("models", {})
        entry = models.get(selected["default"], {})
        if selected.get("context_length") == entry.get("context_length"):
            selected.pop("context_length", None)
            entry.pop("context_length", None)
            if not entry:
                models.pop(selected["default"], None)
    atomic_write(
        home / "config.yaml",
        yaml.safe_dump(merge_defaults(defaults, existing), sort_keys=False),
        0o660,
    )
    # Package updates still belong to Nix; the application's coarse configuration lock does not.
    atomic_write(home / ".managed", "false\n", 0o644)
    # The managed scope is distinct from writable user configuration. Neither the UI nor its
    # normal save helpers can change policy or SOPS-owned credentials through it.
    atomic_write(policy / ".env", render_env(declared), 0o640)
    shutil.rmtree(scratch)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["capture", "restore"])
    parser.add_argument("home", type=Path)
    parser.add_argument("scratch", type=Path)
    parser.add_argument("--defaults", type=Path)
    parser.add_argument("--policy", type=Path)
    args = parser.parse_args()
    os.umask(0o077)
    if args.action == "capture":
        capture(args.home, args.scratch)
    else:
        restore(
            args.home, args.scratch, json.loads(args.defaults.read_text()), args.policy
        )


if __name__ == "__main__":
    main()
