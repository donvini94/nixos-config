"""Authenticated model discovery with a private, last-known-good metadata cache."""

import hashlib
import json
import logging
import math
import os
import tempfile
import threading
import time
import urllib.request
from pathlib import Path


def validate(document):
    if not isinstance(document, dict) or not isinstance(document.get("data"), list):
        raise ValueError("model catalog must contain a data array")
    json.dumps(document, allow_nan=False)
    seen = set()
    for model in document["data"]:
        if (
            not isinstance(model, dict)
            or not isinstance(model.get("id"), str)
            or not model["id"]
        ):
            raise ValueError("model catalog contains an invalid model ID")
        if model["id"] in seen:
            raise ValueError("model catalog contains duplicate model IDs")
        seen.add(model["id"])
    return document


def finite_number(value):
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
        and value >= 0
    )


def prices(document):
    # Requesty reports USD/token; the ingress estimates in USD/million tokens.
    return {
        model["id"]: {
            "input": model["input_price"] * 1_000_000,
            "output": model["output_price"] * 1_000_000,
        }
        for model in document["data"]
        if finite_number(model.get("input_price"))
        and finite_number(model.get("output_price"))
    }


def atomic_json(path, document):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(document, handle, allow_nan=False)
            handle.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


class ModelCatalog:
    def __init__(self, url, token, cache_path, refresh_seconds=300):
        if not token:
            raise ValueError("model discovery requires an upstream credential")
        self.url = url
        self.token = token
        self.cache_path = Path(cache_path)
        self.source = {
            "url": url,
            "credential": hashlib.sha256(token.encode()).hexdigest(),
        }
        self.refresh_seconds = refresh_seconds
        self.lock = threading.Lock()
        self.next_refresh = 0
        self.document = None
        self.price_map = {}
        try:
            cached = json.loads(self.cache_path.read_text())
            if cached.get("source") != self.source:
                raise ValueError("catalog cache belongs to a different upstream")
            self.document = validate(cached["document"])
            self.price_map = prices(self.document)
        except FileNotFoundError:
            pass
        except (OSError, ValueError, KeyError, AttributeError):
            logging.warning(
                "Ignoring invalid or differently scoped model catalog cache"
            )

    def get(self):
        with self.lock:
            if time.monotonic() >= self.next_refresh:
                self.next_refresh = time.monotonic() + self.refresh_seconds
                try:
                    request = urllib.request.Request(
                        self.url, headers={"Authorization": f"Bearer {self.token}"}
                    )
                    with urllib.request.urlopen(request, timeout=15) as response:
                        document = validate(json.load(response))
                    # Persist before publishing so an invalid or failed refresh cannot destroy the cache.
                    atomic_json(
                        self.cache_path, {"source": self.source, "document": document}
                    )
                    self.document = document
                    self.price_map = prices(document)
                except (OSError, ValueError):
                    # Do not log upstream payloads, headers or credential-bearing exception text.
                    logging.warning(
                        "Model catalog refresh failed; retaining last-known-good metadata"
                    )
            if self.document is None:
                raise RuntimeError(
                    "Model catalog unavailable and no valid cache exists"
                )
            return self.document
