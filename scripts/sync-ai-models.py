"""Refresh declared clients from the private ingress; never read provider credentials."""

import argparse
import fcntl
import json
import logging
import os
import urllib.request
from pathlib import Path

import yaml

from catalog import atomic_json, finite_number, validate


def client_model(model):
    result = {
        "id": model["id"],
        "name": model["id"],
        "input": ["text", "image"]
        if model.get("supports_vision") is True
        else ["text"],
        "reasoning": model.get("supports_reasoning") is True,
    }
    for source, target in (
        ("context_window", "contextWindow"),
        ("max_output_tokens", "maxTokens"),
    ):
        value = model.get(source)
        if isinstance(value, int) and not isinstance(value, bool) and value > 0:
            result[target] = value
    costs = {}
    for source, target in (
        ("input_price", "input"),
        ("output_price", "output"),
        ("cached_price", "cacheRead"),
        ("caching_price", "cacheWrite"),
    ):
        value = model.get(source)
        if finite_number(value):
            costs[target] = value * 1_000_000
    if costs:
        result["cost"] = costs
    return result


def read_client(path):
    # JSON is also valid YAML; OMP's existing YAML is accepted during migration.
    if not path.exists():
        return {}
    document = yaml.safe_load(path.read_text())
    if not isinstance(document, dict) or not isinstance(
        document.get("providers", {}), dict
    ):
        raise ValueError(
            "client model configuration must be an object with a providers map"
        )
    return document


def overlay(existing, declared):
    result = dict(existing)
    for key, value in declared.items():
        result[key] = (
            overlay(result[key], value)
            if isinstance(value, dict) and isinstance(result.get(key), dict)
            else value
        )
    return result


def refresh(config, state, capture=False):
    state.mkdir(parents=True, exist_ok=True)
    with (state / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if capture:
            # Home Manager removes its old store symlink before writeBoundary.
            for name, client in config["clients"].items():
                path = Path(client["path"])
                if path.is_symlink() and path.resolve().is_relative_to(
                    Path("/nix/store")
                ):
                    atomic_json(state / f"{name}-migration.json", read_client(path))
            return
        catalog = None
        try:
            request = urllib.request.Request(
                config["endpoint"].rstrip("/") + "/models",
                headers={"X-AI-Caller": "catalog-sync"},
            )
            with urllib.request.urlopen(request, timeout=20) as response:
                catalog = validate(json.load(response))
            atomic_json(
                state / "catalog.json",
                {"endpoint": config["endpoint"], "document": catalog},
            )
        except (OSError, ValueError):
            logging.warning(
                "Private model catalog unavailable; retaining cached client models"
            )
            try:
                cached = json.loads((state / "catalog.json").read_text())
                if cached.get("endpoint") == config["endpoint"]:
                    catalog = validate(cached["document"])
            except FileNotFoundError:
                pass
        pending = []
        for name, client in config["clients"].items():
            path = Path(client["path"])
            backup = state / f"{name}-migration.json"
            existing = read_client(path if path.exists() else backup)
            providers = existing.setdefault("providers", {})
            for provider, declared in client["defaults"]["providers"].items():
                current = providers.get(provider, {})
                if not isinstance(current, dict):
                    raise ValueError("client provider must be an object")
                # Declared endpoints/transport stay authoritative, additional providers and options survive.
                merged = overlay(current, declared)
                if provider == config["provider"]:
                    previous = current.get("models", [])
                    if not isinstance(previous, list) or not all(
                        isinstance(m, dict) and isinstance(m.get("id"), str)
                        for m in previous
                    ):
                        raise ValueError("client models must be objects with IDs")
                    merged["models"] = (
                        previous
                        if current.get("baseUrl") == declared.get("baseUrl")
                        else []
                    )
                    if catalog is not None:
                        previous_by_id = {m["id"]: m for m in previous}
                        metadata = {
                            "id",
                            "name",
                            "input",
                            "reasoning",
                            "contextWindow",
                            "maxTokens",
                            "cost",
                        }
                        merged["models"] = []
                        for model in catalog["data"]:
                            options = {
                                k: v
                                for k, v in previous_by_id.get(model["id"], {}).items()
                                if k not in metadata
                            }
                            merged["models"].append(
                                overlay(
                                    {**options, **client_model(model)},
                                    client.get("modelDefaults", {}),
                                )
                            )
                providers[provider] = merged
            pending.append((path, existing, backup))
        # Parse every target before changing any; malformed native state must remain untouched.
        for path, document, backup in pending:
            atomic_json(path, document)
            backup.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    os.umask(0o077)
    config = json.loads(args.config.read_text())
    try:
        refresh(config, Path(config["stateDirectory"]), args.capture)
    except (OSError, ValueError, yaml.YAMLError):
        logging.error(
            "Model refresh failed; inspect client configuration and private ingress connectivity"
        )
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()
