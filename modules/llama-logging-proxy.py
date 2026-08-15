"""Loopback reverse proxy that records complete OpenAI requests and responses as JSONL."""

import hmac
import json
import os
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BACKEND = os.environ["LLAMA_BACKEND"]
BACKEND_HEALTH_PATH = os.environ.get("LLAMA_BACKEND_HEALTH_PATH", "/health")
LOG_PATH = os.environ["LLAMA_REQUEST_LOG"]


def load_allowed_models():
    raw = os.environ.get("LLAMA_ALLOWED_MODELS")
    if not raw:
        return frozenset()
    values = json.loads(raw)
    if not isinstance(values, list) or not all(
        isinstance(value, str) and value for value in values
    ):
        raise RuntimeError("LLAMA_ALLOWED_MODELS must be a JSON array of model IDs")
    return frozenset(values)


ALLOWED_MODELS = load_allowed_models()
HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
    "host",
    "content-length",
}


def load_credential(environment_name):
    credential_name = os.environ.get(environment_name)
    credential_directory = os.environ.get("CREDENTIALS_DIRECTORY")
    if not credential_name or not credential_directory:
        return None
    with open(
        os.path.join(credential_directory, credential_name), encoding="utf-8"
    ) as handle:
        value = handle.read().rstrip("\n")
    if not value:
        raise RuntimeError(f"configured credential {credential_name!r} is empty")
    return value


def load_bearer_caller():
    credential_name = os.environ.get("LLAMA_BEARER_TOKEN_CREDENTIAL")
    caller = os.environ.get("LLAMA_BEARER_CALLER", "wirken")
    if not credential_name:
        return None, None
    return load_credential("LLAMA_BEARER_TOKEN_CREDENTIAL"), caller


BEARER_TOKEN, BEARER_CALLER = load_bearer_caller()
UPSTREAM_BEARER_TOKEN = load_credential("LLAMA_UPSTREAM_BEARER_CREDENTIAL")


def upstream_headers(headers):
    forwarded = {
        key: value for key, value in headers.items() if key.lower() not in HOP_HEADERS
    }
    if UPSTREAM_BEARER_TOKEN:
        forwarded["Authorization"] = f"Bearer {UPSTREAM_BEARER_TOKEN}"
    return forwarded


class Metrics:
    """Small in-process Prometheus collector for the stable AI ingress."""

    def __init__(self):
        self.lock = threading.Lock()
        self.in_flight = 0
        self.requests = {}
        self.prompt_tokens = {}
        self.completion_tokens = {}
        self.cost_usd = {}
        self.latency = {}
        self.ttft = {}

    def begin(self):
        with self.lock:
            self.in_flight += 1

    def finish(self, caller, model, status, usage, latency_ms, ttft_ms):
        labels = (caller, model or "unknown")
        request_labels = labels + (str(status),)
        with self.lock:
            self.in_flight -= 1
            self.requests[request_labels] = self.requests.get(request_labels, 0) + 1
            self.latency[labels] = self._add_sample(
                self.latency, labels, latency_ms / 1000
            )
            if ttft_ms is not None:
                self.ttft[labels] = self._add_sample(self.ttft, labels, ttft_ms / 1000)
            if isinstance(usage, dict):
                self._add_tokens(self.prompt_tokens, labels, usage.get("prompt_tokens"))
                self._add_tokens(
                    self.completion_tokens, labels, usage.get("completion_tokens")
                )
                self._add_tokens(self.cost_usd, labels, usage.get("cost"))

    @staticmethod
    def _add_sample(target, labels, value):
        count, total = target.get(labels, (0, 0.0))
        return count + 1, total + value

    @staticmethod
    def _add_tokens(target, labels, value):
        if isinstance(value, (int, float)):
            target[labels] = target.get(labels, 0) + value

    @staticmethod
    def _labels(names, values):
        def escape(value):
            return (
                str(value)
                .replace("\\", "\\\\")
                .replace("\n", "\\n")
                .replace('"', '\\"')
            )

        return (
            "{"
            + ",".join(
                f'{name}="{escape(value)}"' for name, value in zip(names, values)
            )
            + "}"
        )

    def render(self):
        lines = [
            "# HELP ai_ingress_in_flight_requests Current requests through the AI ingress.",
            "# TYPE ai_ingress_in_flight_requests gauge",
        ]
        with self.lock:
            lines.append(f"ai_ingress_in_flight_requests {self.in_flight}")
            lines.extend(
                self._render_counter(
                    "ai_ingress_requests", self.requests, ("caller", "model", "status")
                )
            )
            lines.extend(
                self._render_counter(
                    "ai_ingress_prompt_tokens", self.prompt_tokens, ("caller", "model")
                )
            )
            lines.extend(
                self._render_counter(
                    "ai_ingress_completion_tokens",
                    self.completion_tokens,
                    ("caller", "model"),
                )
            )
            lines.extend(
                self._render_counter(
                    "ai_ingress_cost_usd", self.cost_usd, ("caller", "model")
                )
            )
            lines.extend(
                self._render_summary("ai_ingress_latency_seconds", self.latency)
            )
            lines.extend(self._render_summary("ai_ingress_ttft_seconds", self.ttft))
        return "\n".join(lines) + "\n"

    def _render_counter(self, name, values, label_names):
        lines = [f"# TYPE {name}_total counter"]
        lines.extend(
            f"{name}_total{self._labels(label_names, labels)} {value}"
            for labels, value in sorted(values.items())
        )
        return lines

    def _render_summary(self, name, values):
        lines = [f"# TYPE {name} summary"]
        for labels, (count, total) in sorted(values.items()):
            rendered = self._labels(("caller", "model"), labels)
            lines.append(f"{name}_count{rendered} {count}")
            lines.append(f"{name}_sum{rendered} {total}")
        return lines


METRICS = Metrics()


def resolve_caller(headers):
    explicit = headers.get("X-AI-Caller")
    if explicit:
        return explicit
    authorization = headers.get("Authorization", "")
    prefix = "Bearer "
    if (
        BEARER_TOKEN
        and authorization.startswith(prefix)
        and hmac.compare_digest(authorization[len(prefix) :], BEARER_TOKEN)
    ):
        return BEARER_CALLER
    return "unattributed"


def append_log(record):
    line = json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n"
    with open(LOG_PATH, "a", encoding="utf-8") as handle:
        handle.write(line)


class Proxy(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, _format, *_args):
        return

    def _proxy(self):
        if self.path == "/metrics" and self.command == "GET":
            return self._metrics()
        if self.path == "/health" and self.command == "GET":
            return self._health()
        if self.path == "/v1/models" and self.command == "GET" and ALLOWED_MODELS:
            return self._models()

        started = time.monotonic()
        METRICS.begin()
        length = int(self.headers.get("Content-Length", "0"))
        request_body = self.rfile.read(length)
        try:
            request_json = json.loads(request_body) if request_body else None
        except json.JSONDecodeError:
            request_json = None
        model = request_json.get("model") if isinstance(request_json, dict) else None
        if ALLOWED_MODELS and model and model not in ALLOWED_MODELS:
            return self._reject_model(started, request_json, model)
        headers = upstream_headers(self.headers)
        request = urllib.request.Request(
            BACKEND + self.path,
            data=request_body if length else None,
            headers=headers,
            method=self.command,
        )
        response_body = bytearray()
        ttft_ms = None
        status = 502
        response_headers = {}
        response_started = False
        is_event_stream = False
        stream_completed = None
        client_disconnected = False
        proxy_error = None
        try:
            try:
                upstream = urllib.request.urlopen(request, timeout=3600)
            except urllib.error.HTTPError as error:
                upstream = error
            status = upstream.status
            response_headers = dict(upstream.headers.items())
            self.send_response(status)
            for key, value in upstream.headers.items():
                if key.lower() not in HOP_HEADERS:
                    self.send_header(key, value)
            self.send_header("Connection", "close")
            self.end_headers()
            response_started = True
            is_event_stream = upstream.headers.get_content_type() == "text/event-stream"
            stream_completed = False if is_event_stream else None
            read_chunk = (
                upstream.readline if is_event_stream else lambda: upstream.read(65536)
            )
            while chunk := read_chunk():
                if ttft_ms is None:
                    ttft_ms = round((time.monotonic() - started) * 1000, 3)
                response_body.extend(chunk)
                if is_event_stream and chunk.strip() == b"data: [DONE]":
                    stream_completed = True
                try:
                    self.wfile.write(chunk)
                    self.wfile.flush()
                except OSError as error:
                    client_disconnected = True
                    proxy_error = str(error)
                    upstream.close()
                    break
        except (OSError, urllib.error.URLError) as error:
            proxy_error = str(error)
            if not response_started and not self.wfile.closed:
                payload = json.dumps({"error": {"message": str(error)}}).encode()
                self.send_response(502)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(payload)
                response_body = bytearray(payload)
                response_headers = {"Content-Type": "application/json"}
        finally:
            elapsed_ms = round((time.monotonic() - started) * 1000, 3)
            response_json = None
            try:
                response_json = json.loads(response_body) if response_body else None
            except json.JSONDecodeError:
                pass
            usage = (
                response_json.get("usage") if isinstance(response_json, dict) else None
            )
            if usage is None and response_body.startswith(b"data:"):
                for line in response_body.splitlines():
                    if not line.startswith(b"data: ") or line == b"data: [DONE]":
                        continue
                    try:
                        event = json.loads(line[6:])
                    except json.JSONDecodeError:
                        continue
                    usage = event.get("usage") or usage
                    timings = event.get("timings")
                    if usage is None and isinstance(timings, dict):
                        usage = {
                            "prompt_tokens": timings.get("prompt_n"),
                            "completion_tokens": timings.get("predicted_n"),
                            "total_tokens": (
                                timings.get("prompt_n", 0)
                                + timings.get("predicted_n", 0)
                            ),
                        }
            append_log(
                {
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "caller": resolve_caller(self.headers),
                    "eval_run": self.headers.get("X-AI-Eval-Run"),
                    "method": self.command,
                    "endpoint": self.path,
                    "model": request_json.get("model")
                    if isinstance(request_json, dict)
                    else None,
                    "status": status,
                    "latency_ms": elapsed_ms,
                    "ttft_ms": ttft_ms,
                    "usage": usage,
                    "stream_completed": stream_completed,
                    "client_disconnected": client_disconnected,
                    "proxy_error": proxy_error,
                    "request": request_json
                    if request_json is not None
                    else request_body.decode("utf-8", "replace"),
                    "response": response_json
                    if response_json is not None
                    else response_body.decode("utf-8", "replace"),
                    "response_content_type": response_headers.get("Content-Type"),
                    "upstream": {
                        key.lower(): value
                        for key, value in response_headers.items()
                        if key.lower().startswith("x-requesty-")
                    },
                }
            )
            METRICS.finish(
                resolve_caller(self.headers),
                request_json.get("model") if isinstance(request_json, dict) else None,
                status,
                usage,
                elapsed_ms,
                ttft_ms,
            )
            self.close_connection = True

    def _reject_model(self, started, request_json, model):
        status = 403
        response_json = {
            "error": {
                "message": f"model {model!r} is not registered on this ingress",
                "type": "model_not_allowed",
            }
        }
        payload = json.dumps(response_json, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(payload)
        elapsed_ms = round((time.monotonic() - started) * 1000, 3)
        caller = resolve_caller(self.headers)
        append_log(
            {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "caller": caller,
                "eval_run": self.headers.get("X-AI-Eval-Run"),
                "method": self.command,
                "endpoint": self.path,
                "model": model,
                "status": status,
                "latency_ms": elapsed_ms,
                "ttft_ms": None,
                "usage": None,
                "stream_completed": None,
                "client_disconnected": False,
                "proxy_error": "model_not_allowed",
                "request": request_json,
                "response": response_json,
                "response_content_type": "application/json",
                "upstream": {},
            }
        )
        METRICS.finish(caller, model, status, None, elapsed_ms, None)
        self.close_connection = True

    def _models(self):
        request = urllib.request.Request(
            BACKEND + "/v1/models",
            headers=upstream_headers(self.headers),
            method="GET",
        )
        try:
            try:
                upstream = urllib.request.urlopen(request, timeout=30)
            except urllib.error.HTTPError as error:
                upstream = error
            status = upstream.status
            response_headers = dict(upstream.headers.items())
            payload = upstream.read()
            if 200 <= status < 300:
                document = json.loads(payload)
                if isinstance(document, dict) and isinstance(
                    document.get("data"), list
                ):
                    document["data"] = [
                        entry
                        for entry in document["data"]
                        if isinstance(entry, dict) and entry.get("id") in ALLOWED_MODELS
                    ]
                    payload = json.dumps(document, separators=(",", ":")).encode()
        except (OSError, urllib.error.URLError, json.JSONDecodeError) as error:
            status = 502
            response_headers = {"Content-Type": "application/json"}
            payload = json.dumps({"error": {"message": str(error)}}).encode()
        self.send_response(status)
        self.send_header(
            "Content-Type", response_headers.get("Content-Type", "application/json")
        )
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(payload)
        self.close_connection = True

    def _metrics(self):
        payload = METRICS.render().encode()
        try:
            with urllib.request.urlopen(BACKEND + "/metrics", timeout=5) as upstream:
                payload += upstream.read()
        except (OSError, urllib.error.URLError):
            pass
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(payload)
        self.close_connection = True

    def _health(self):
        request = urllib.request.Request(
            BACKEND + BACKEND_HEALTH_PATH,
            headers=upstream_headers({}),
            method="GET",
        )
        try:
            with urllib.request.urlopen(request, timeout=10) as upstream:
                healthy = 200 <= upstream.status < 300
        except (OSError, urllib.error.URLError):
            healthy = False
        payload = json.dumps({"status": "ok" if healthy else "unavailable"}).encode()
        self.send_response(200 if healthy else 503)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(payload)
        self.close_connection = True

    do_GET = _proxy
    do_POST = _proxy


if __name__ == "__main__":
    os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
    server = ThreadingHTTPServer(
        (os.environ["LLAMA_PROXY_HOST"], int(os.environ["LLAMA_PROXY_PORT"])), Proxy
    )
    server.serve_forever()
