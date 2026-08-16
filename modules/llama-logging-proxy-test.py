#!/usr/bin/env python3
"""Regression tests for the AI ingress proxy; standard library only.

The proxy reads its configuration at import time, so the fake upstream is bound
before the module is loaded. Langfuse is never imported: exporters are injected
through the module's own seams (``LangfuseExporter(client_factory)`` and the
``LANGFUSE_EXPORTER`` global).
"""

import contextlib
import http.server
import importlib.util
import io
import json
import os
import shutil
import tempfile
import threading
import unittest
import urllib.request
from pathlib import Path

UPSTREAM_PAYLOAD = {
    "id": "chatcmpl-test",
    "model": "priced-model",
    "choices": [{"index": 0, "message": {"role": "assistant", "content": "pong"}}],
    "usage": {
        "prompt_tokens": 1000,
        "completion_tokens": 500,
        "total_tokens": 1500,
        "cost": 0.25,
    },
}
UPSTREAM_BODY = json.dumps(UPSTREAM_PAYLOAD).encode()
PRICE_MAP = {"priced-model": {"input": 0.4, "output": 1.6}}


class Upstream(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", "0")))
        self.send_response(201)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(UPSTREAM_BODY)))
        self.end_headers()
        self.wfile.write(UPSTREAM_BODY)

    def log_message(self, _format, *_args):
        return


def serve(handler):
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def load_proxy(backend_url, log_path):
    os.environ.update(
        {
            "LLAMA_BACKEND": backend_url,
            "LLAMA_REQUEST_LOG": log_path,
            "LLAMA_PRICE_MAP": json.dumps(PRICE_MAP),
            "LLAMA_ENVIRONMENT": "dracula",
        }
    )
    for name in ("LLAMA_ALLOWED_MODELS", "LANGFUSE_BASE_URL"):
        os.environ.pop(name, None)
    path = Path(__file__).with_name("llama-logging-proxy.py")
    spec = importlib.util.spec_from_file_location("llama_logging_proxy", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


STATE_DIR = tempfile.mkdtemp(prefix="ai-ingress-test-")
UPSTREAM = serve(Upstream)
UPSTREAM_URL = "http://127.0.0.1:%d" % UPSTREAM.server_address[1]
proxy = load_proxy(UPSTREAM_URL, os.path.join(STATE_DIR, "requests.jsonl"))
INGRESS = serve(proxy.Proxy)
INGRESS_URL = "http://127.0.0.1:%d" % INGRESS.server_address[1]


def tearDownModule():
    UPSTREAM.shutdown()
    INGRESS.shutdown()
    shutil.rmtree(STATE_DIR, ignore_errors=True)


def post(url, headers=None):
    request = urllib.request.Request(
        url,
        data=json.dumps({"model": "priced-model", "messages": []}).encode(),
        headers={"Content-Type": "application/json", **(headers or {})},
        method="POST",
    )
    with contextlib.closing(urllib.request.urlopen(request)) as response:
        return response.status, response.read()


class StubClient:
    """Stands in for langfuse.Langfuse without importing or reaching the SDK."""

    def __init__(self):
        self.observations = []
        self.end_times = []
        self.flushes = 0

    def start_observation(self, **fields):
        self.observations.append(fields)
        return self

    def end(self, end_time=None):
        self.end_times.append(end_time)
        return self

    def flush(self):
        self.flushes += 1


class RecordingExporter:
    def __init__(self):
        self.observations = []

    def submit(self, observation):
        self.observations.append(observation)

    def report(self, message):
        raise AssertionError(f"unexpected exporter report: {message}")


class ExplodingExporter:
    def submit(self, _observation):
        raise RuntimeError("langfuse is on fire")

    def report(self, message):
        self.message = message


class UsageExtractionTest(unittest.TestCase):
    def test_json_response(self):
        body = json.dumps({"usage": {"prompt_tokens": 7, "completion_tokens": 3}})
        self.assertEqual(
            proxy.extract_usage(body.encode()),
            {"prompt_tokens": 7, "completion_tokens": 3},
        )

    def test_sse_usage_event(self):
        body = (
            b'data: {"choices":[{"delta":{"content":"hi"}}]}\n\n'
            b'data: {"usage":{"prompt_tokens":11,"completion_tokens":4}}\n\n'
            b"data: [DONE]\n\n"
        )
        self.assertEqual(
            proxy.extract_usage(body),
            {"prompt_tokens": 11, "completion_tokens": 4},
        )

    def test_sse_timings_fallback(self):
        body = (
            b'data: {"choices":[{"delta":{"content":"hi"}}]}\n\n'
            b'data: {"timings":{"prompt_n":9,"predicted_n":6}}\n\n'
            b"data: [DONE]\n\n"
        )
        self.assertEqual(
            proxy.extract_usage(body),
            {"prompt_tokens": 9, "completion_tokens": 6, "total_tokens": 15},
        )

    def test_sse_output_is_reassembled(self):
        body = (
            b'data: {"choices":[{"delta":{"content":"po"}}]}\n\n'
            b'data: {"choices":[{"delta":{"content":"ng"}}]}\n\n'
            b"data: [DONE]\n\n"
        )
        self.assertEqual(proxy.extract_output(body), "pong")


class CostTest(unittest.TestCase):
    def test_provider_cost_wins(self):
        cost = proxy.compute_cost(
            "priced-model",
            {"prompt_tokens": 1000, "completion_tokens": 500, "cost": 0.25},
            PRICE_MAP,
        )
        self.assertEqual(cost["actual_usd"], 0.25)
        self.assertEqual(cost["source"], "provider")
        # The estimate is still computed; it must never overwrite billing.
        self.assertEqual(cost["estimated_usd"], (1000 * 0.4 + 500 * 1.6) / 1_000_000)

    def test_total_cost_alias(self):
        cost = proxy.compute_cost("unpriced", {"total_cost": 0.5}, PRICE_MAP)
        self.assertEqual(cost, {
            "actual_usd": 0.5,
            "estimated_usd": None,
            "source": "provider",
        })

    def test_non_numeric_provider_cost_is_ignored(self):
        cost = proxy.compute_cost("unpriced", {"cost": "0.25"}, PRICE_MAP)
        self.assertIsNone(cost["actual_usd"])
        self.assertEqual(cost["source"], "unavailable")

    def test_registry_estimate(self):
        cost = proxy.compute_cost(
            "priced-model",
            {"prompt_tokens": 1000, "completion_tokens": 500},
            PRICE_MAP,
        )
        self.assertIsNone(cost["actual_usd"])
        self.assertEqual(cost["estimated_usd"], (1000 * 0.4 + 500 * 1.6) / 1_000_000)
        self.assertEqual(cost["source"], "registry-estimate")

    def test_unavailable(self):
        cost = proxy.compute_cost(
            "unpriced", {"prompt_tokens": 1000, "completion_tokens": 500}, PRICE_MAP
        )
        self.assertEqual(cost, {
            "actual_usd": None,
            "estimated_usd": None,
            "source": "unavailable",
        })

    def test_missing_usage(self):
        self.assertEqual(proxy.compute_cost("priced-model", None, PRICE_MAP)["source"],
                         "unavailable")


class CallerTest(unittest.TestCase):
    def test_header_wins(self):
        self.assertEqual(proxy.resolve_caller({"X-AI-Caller": "n8n"}), "n8n")

    def test_missing_header(self):
        self.assertEqual(proxy.resolve_caller({}), "unattributed")


class MetricsTest(unittest.TestCase):
    def test_actual_and_estimated_are_separate_series(self):
        metrics = proxy.Metrics()
        metrics.begin()
        metrics.finish(
            "n8n",
            "priced-model",
            200,
            {"prompt_tokens": 1000, "completion_tokens": 500},
            {"actual_usd": 0.25, "estimated_usd": 0.0012, "source": "provider"},
            120.0,
            30.0,
        )
        rendered = metrics.render()
        labels = '{caller="n8n",model="priced-model"}'
        self.assertIn(f"ai_ingress_cost_usd_total{labels} 0.25", rendered)
        self.assertIn(f"ai_ingress_estimated_cost_usd_total{labels} 0.0012", rendered)
        self.assertIn(f"ai_ingress_prompt_tokens_total{labels} 1000", rendered)


class ObservationTest(unittest.TestCase):
    def build(self):
        return proxy.build_observation(
            endpoint="/v1/chat/completions",
            caller="n8n",
            model="priced-model",
            request_json={"model": "priced-model", "messages": [{"role": "user"}]},
            output="pong",
            usage={"prompt_tokens": 1000, "completion_tokens": 500},
            cost={
                "actual_usd": None,
                "estimated_usd": 0.0012,
                "source": "registry-estimate",
            },
            status=200,
            latency_ms=120.0,
            ttft_ms=30.0,
        )

    def test_payload_fields(self):
        observation = self.build()
        self.assertEqual(observation["as_type"], "generation")
        self.assertEqual(observation["model"], "priced-model")
        self.assertEqual(observation["input"], [{"role": "user"}])
        self.assertEqual(observation["output"], "pong")
        self.assertEqual(
            observation["usage_details"], {"input": 1000, "output": 500, "total": 1500}
        )
        self.assertEqual(observation["cost_details"], {"total": 0.0012})
        self.assertEqual(
            observation["metadata"],
            {
                "source": "ai-ingress",
                "caller": "n8n",
                "environment": "dracula",
                "host": proxy.HOSTNAME,
                "status": 200,
                "latency_ms": 120.0,
                "ttft_ms": 30.0,
                "cost_source": "registry-estimate",
            },
        )

    def test_exporter_hands_payload_to_the_sdk(self):
        client = StubClient()
        exporter = proxy.LangfuseExporter(lambda: client)
        exporter.submit(self.build())
        exporter.queue.join()
        self.assertEqual(len(client.observations), 1)
        self.assertEqual(client.observations[0], self.build())
        # The span must close at the measured latency, not at zero duration:
        # Langfuse computes its own latency from the span, not from metadata.
        self.assertEqual(len(client.end_times), 1)
        self.assertIsNotNone(client.end_times[0])
        self.assertEqual(client.flushes, 1)

    def test_client_failure_disables_export_permanently(self):
        attempts = []

        def factory():
            attempts.append(1)
            raise RuntimeError("no credentials")

        exporter = proxy.LangfuseExporter(factory)
        with contextlib.redirect_stderr(io.StringIO()):
            exporter.submit(self.build())
            exporter.queue.join()
            exporter.submit(self.build())
            exporter.queue.join()
        self.assertEqual(len(attempts), 1)

    def test_report_is_rate_limited(self):
        exporter = proxy.LangfuseExporter(StubClient)
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            exporter.report("first")
            exporter.report("second")
        self.assertEqual(stderr.getvalue(), "first\n")


class ProxyRequestTest(unittest.TestCase):
    def setUp(self):
        self.addCleanup(setattr, proxy, "LANGFUSE_EXPORTER", proxy.LANGFUSE_EXPORTER)

    def test_observation_emitted_once_with_cost(self):
        exporter = RecordingExporter()
        proxy.LANGFUSE_EXPORTER = exporter
        status, _ = post(f"{INGRESS_URL}/v1/chat/completions", {"X-AI-Caller": "n8n"})
        self.assertEqual(status, 201)
        self.assertEqual(len(exporter.observations), 1)
        observation = exporter.observations[0]
        self.assertEqual(observation["metadata"]["caller"], "n8n")
        self.assertEqual(observation["metadata"]["environment"], "dracula")
        self.assertEqual(observation["metadata"]["cost_source"], "provider")
        self.assertEqual(observation["cost_details"], {"total": 0.25})
        self.assertEqual(observation["output"], "pong")

    def test_non_generation_endpoint_is_not_traced(self):
        exporter = RecordingExporter()
        proxy.LANGFUSE_EXPORTER = exporter
        post(f"{INGRESS_URL}/v1/embeddings")
        self.assertEqual(exporter.observations, [])

    def test_logged_record_carries_cost(self):
        proxy.LANGFUSE_EXPORTER = None
        post(f"{INGRESS_URL}/v1/chat/completions", {"X-AI-Caller": "cli"})
        with open(proxy.LOG_PATH, encoding="utf-8") as handle:
            record = json.loads(handle.readlines()[-1])
        self.assertEqual(record["caller"], "cli")
        self.assertEqual(
            record["cost"],
            {
                "actual_usd": 0.25,
                "estimated_usd": (1000 * 0.4 + 500 * 1.6) / 1_000_000,
                "source": "provider",
            },
        )

    def test_failing_exporter_leaves_the_response_untouched(self):
        exporter = ExplodingExporter()
        proxy.LANGFUSE_EXPORTER = exporter
        direct_status, direct_body = post(f"{UPSTREAM_URL}/v1/chat/completions")
        status, body = post(f"{INGRESS_URL}/v1/chat/completions")
        self.assertEqual((status, body), (direct_status, direct_body))
        self.assertIn("langfuse", exporter.message)


if __name__ == "__main__":
    unittest.main()
