"""Startup model discovery and Hermes activation tests; no real credentials or services."""

import http.server
import importlib.util
import json
import os
import urllib.request
import urllib.error
from unittest.mock import patch
import sys
import tempfile
import threading
import unittest
from pathlib import Path

import yaml

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
sys.argv = sys.argv[:1]
sys.path.insert(0, str(ROOT / "ai-ingress"))
from catalog import ModelCatalog, atomic_json, prices, validate  # noqa: E402


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


sync = load("sync_models", ROOT / "scripts/sync-ai-models.py")
state = load("hermes_state", ROOT / "scripts/hermes-state.py")
MODEL = {
    "id": "vendor/new-model",
    "input_price": 0.000002,
    "output_price": 0.000005,
    "cached_price": 0.000001,
    "context_window": 200000,
    "max_output_tokens": 30000,
    "supports_reasoning": True,
    "supports_vision": True,
}


class Upstream(http.server.BaseHTTPRequestHandler):
    response = {"data": [MODEL]}
    status = 200
    authorization = None

    def do_GET(self):
        type(self).authorization = self.headers.get("Authorization")
        self.send_response(type(self).status)
        self.end_headers()
        self.wfile.write(json.dumps(type(self).response).encode())

    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", "0")))
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps({"model": MODEL["id"], "choices": []}).encode())

    def log_message(self, *_args):
        pass


class ModelsTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        Upstream.response, Upstream.status = {"data": [MODEL]}, 200
        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Upstream)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.endpoint = f"http://127.0.0.1:{self.server.server_port}/v1"
        self.config = {
            "endpoint": self.endpoint,
            "provider": "alucard-requesty",
            "clients": {
                "pi": {
                    "path": str(self.root / "models.json"),
                    "defaults": {
                        "providers": {
                            "alucard-requesty": {
                                "baseUrl": self.endpoint,
                                "api": "openai-completions",
                                "models": [],
                            }
                        }
                    },
                }
            },
        }

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.directory.cleanup()

    def test_authenticated_catalog_units_and_private_cache(self):
        catalog = ModelCatalog(
            self.endpoint + "/models", "test-secret", self.root / "cache", 0
        )
        self.assertEqual(catalog.get()["data"], [MODEL])
        self.assertEqual(Upstream.authorization, "Bearer test-secret")
        self.assertEqual(catalog.price_map[MODEL["id"]], {"input": 2, "output": 5})
        self.assertNotIn("test-secret", (self.root / "cache").read_text())
        self.assertEqual((self.root / "cache").stat().st_mode & 0o777, 0o600)
        before = (self.root / "cache").read_bytes()
        Upstream.response = {"data": [{"bad": "payload"}]}
        self.assertEqual(catalog.get()["data"], [MODEL])
        self.assertEqual((self.root / "cache").read_bytes(), before)
        Upstream.status = 503
        restarted = ModelCatalog(
            self.endpoint + "/models", "test-secret", self.root / "cache", 0
        )
        self.assertEqual(restarted.get()["data"], [MODEL])

    def test_credential_change_does_not_reuse_another_catalog(self):
        catalog = ModelCatalog(
            self.endpoint + "/models", "first-key", self.root / "cache", 0
        )
        catalog.get()
        Upstream.status = 503
        replacement = ModelCatalog(
            self.endpoint + "/models", "different-key", self.root / "cache", 0
        )
        with self.assertRaises(RuntimeError):
            replacement.get()

    def test_ingress_models_route_and_runtime_prices(self):
        (self.root / "credential").write_text("test-secret")
        environment = {
            "LLAMA_BACKEND": self.endpoint.removesuffix("/v1"),
            "LLAMA_REQUEST_LOG": str(self.root / "requests.jsonl"),
            "LLAMA_MODEL_CATALOG_CACHE": str(self.root / "cache"),
            "LLAMA_UPSTREAM_BEARER_CREDENTIAL": "credential",
            "CREDENTIALS_DIRECTORY": str(self.root),
        }
        with patch.dict(os.environ, environment):
            proxy = load("startup_proxy", ROOT / "ai-ingress/proxy.py")
        ingress = http.server.ThreadingHTTPServer(("127.0.0.1", 0), proxy.Proxy)
        threading.Thread(target=ingress.serve_forever, daemon=True).start()
        try:
            with urllib.request.urlopen(
                f"http://127.0.0.1:{ingress.server_port}/v1/models"
            ) as response:
                document = json.load(response)
            self.assertEqual(document, {"data": [MODEL]})
            self.assertNotIn("source", document)
            self.assertEqual(Upstream.authorization, "Bearer test-secret")
            cost = proxy.compute_cost(
                MODEL["id"], {"prompt_tokens": 1000000, "completion_tokens": 1000000}
            )
            self.assertEqual(cost["estimated_usd"], 7)
            url = f"http://127.0.0.1:{ingress.server_port}/v1/chat/completions"
            for model in ("not-approved", None, {"invalid": "type"}):
                request = urllib.request.Request(
                    url, data=json.dumps({"model": model, "messages": []}).encode()
                )
                with self.assertRaises(urllib.error.HTTPError) as rejected:
                    urllib.request.urlopen(request)
                self.assertEqual(rejected.exception.code, 403)
            request = urllib.request.Request(
                url, data=json.dumps({"model": MODEL["id"], "messages": []}).encode()
            )
            with urllib.request.urlopen(request) as response:
                self.assertEqual(response.status, 200)
            Upstream.status = 503
            proxy.CATALOG = ModelCatalog(
                self.endpoint + "/models", "test-secret", self.root / "missing-cache", 0
            )
            with self.assertRaises(urllib.error.HTTPError) as unavailable:
                urllib.request.urlopen(request)
            self.assertEqual(unavailable.exception.code, 503)
        finally:
            ingress.shutdown()
            ingress.server_close()

    def test_no_cache_failure_and_empty_approved_catalog(self):
        Upstream.status = 503
        catalog = ModelCatalog(
            self.endpoint + "/models", "test-secret", self.root / "cache", 0
        )
        with self.assertRaises(RuntimeError):
            catalog.get()
        Upstream.status, Upstream.response = 200, {"data": []}
        self.assertEqual(catalog.get()["data"], [])

    def test_invalid_ids_and_unknown_prices(self):
        for data in ([{"id": True}], [{"id": "x"}, {"id": "x"}]):
            with self.assertRaises(ValueError):
                validate({"data": data})
        self.assertEqual(
            prices({"data": [{"id": "x", "input_price": True, "output_price": 1}]}), {}
        )
        converted = sync.client_model(MODEL)
        self.assertEqual(converted["contextWindow"], 200000)
        self.assertEqual(converted["maxTokens"], 30000)
        self.assertEqual(converted["input"], ["text", "image"])
        self.assertEqual(converted["cost"]["cacheRead"], 1)
        self.assertEqual(
            set(converted["cost"]), {"input", "output", "cacheRead", "cacheWrite"}
        )
        self.assertEqual(converted["cost"]["cacheWrite"], 0)
        self.assertNotIn("cost", sync.client_model({"id": "x"}))

    def test_clients_preserve_other_providers_and_use_offline_cache(self):
        path = self.root / "models.json"
        atomic_json(
            path,
            {
                "providers": {
                    "personal": {"models": [{"id": "mine"}]},
                    "alucard-requesty": {"headers": {"custom": "retained"}},
                },
                "extra": True,
            },
        )
        sync.refresh(self.config, self.root / "state")
        result = json.loads(path.read_text())
        self.assertEqual(result["providers"]["personal"]["models"], [{"id": "mine"}])
        self.assertEqual(
            result["providers"]["alucard-requesty"]["headers"], {"custom": "retained"}
        )
        self.assertTrue(result["extra"])
        self.assertEqual(
            result["providers"]["alucard-requesty"]["models"][0]["id"], MODEL["id"]
        )
        Upstream.status = 503
        sync.refresh(self.config, self.root / "state")
        self.assertEqual(json.loads(path.read_text()), result)

    def test_invalid_client_prevents_all_client_writes(self):
        first, second = self.root / "models.json", self.root / "omp.yml"
        first.write_text('{"providers":{}}')
        second.write_text("not a mapping")
        self.config["clients"]["omp"] = {
            "path": str(second),
            "defaults": {"providers": {}},
        }
        with self.assertRaises(ValueError):
            sync.refresh(self.config, self.root / "state")
        self.assertEqual(first.read_text(), '{"providers":{}}')
        self.assertEqual(second.read_text(), "not a mapping")

    def test_empty_catalog_removes_retired_models(self):
        sync.refresh(self.config, self.root / "state")
        Upstream.response = {"data": []}
        sync.refresh(self.config, self.root / "state")
        result = json.loads((self.root / "models.json").read_text())
        self.assertEqual(result["providers"]["alucard-requesty"]["models"], [])
        self.assertEqual(set(self.config["clients"]), {"pi"})
        self.assertFalse((self.root / "omp.yml").exists())


class HermesTest(unittest.TestCase):
    def test_activation_preserves_ui_state_and_rotates_only_managed_env(self):
        with tempfile.TemporaryDirectory() as temporary:
            home, policy, scratch = (
                Path(temporary) / name for name in ("home", "policy", "scratch")
            )
            home.mkdir()
            policy.mkdir()
            (home / "config.yaml").write_text(
                "model:\n  default: user-choice\nmcp_servers:\n  personal:\n    url: http://localhost/mcp\n"
            )
            values = {
                "API_SERVER_KEY": "old",
                "REMOVED_PIN": "gone",
                "MCP_KEY": "ui secret 'quoted'\\value\nmore",
            }
            (home / ".env").write_text(state.render_env(values))
            (home / ".nix-env-keys.json").write_text(
                json.dumps(["API_SERVER_KEY", "REMOVED_PIN"])
            )
            for _ in range(2):
                state.capture(home, scratch)
                # Upstream regenerates its env and deep-merges a fixed working directory.
                (home / ".env").write_text("API_SERVER_KEY=new\nHERMES_MANAGED=false\n")
                state.restore(
                    home, scratch, {"model": {"default": "initial-choice"}}, policy
                )
                self.assertEqual(
                    state.environment(home / ".env"),
                    {
                        "API_SERVER_KEY": "new",
                        "HERMES_MANAGED": "false",
                        "MCP_KEY": values["MCP_KEY"],
                    },
                )
                self.assertNotIn("MCP_KEY", state.environment(policy / ".env"))
                config = yaml.safe_load((home / "config.yaml").read_text())
                self.assertEqual(config["model"]["default"], "user-choice")
                self.assertIn("personal", config["mcp_servers"])
                self.assertEqual((home / ".managed").read_text(), "false\n")
                self.assertFalse(scratch.exists())

    def test_invalid_configuration_refuses_capture(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            (home / "config.yaml").write_text("invalid")
            with self.assertRaises(ValueError):
                state.capture(home, home / "scratch")
            self.assertEqual((home / "config.yaml").read_text(), "invalid")


if __name__ == "__main__":
    unittest.main()
