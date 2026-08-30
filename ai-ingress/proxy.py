"""Loopback reverse proxy that records complete OpenAI requests and responses as JSONL."""

import json
import logging
import os
import queue
import socket
import sys
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BACKEND = os.environ["LLAMA_BACKEND"]
BACKEND_HEALTH_PATH = os.environ.get("LLAMA_BACKEND_HEALTH_PATH", "/health")
LOG_PATH = os.environ["LLAMA_REQUEST_LOG"]
ENVIRONMENT = os.environ.get("LLAMA_ENVIRONMENT", "unknown")
HOSTNAME = socket.gethostname()
LANGFUSE_BASE_URL = os.environ.get("LANGFUSE_BASE_URL", "").strip()
# Only conversational endpoints map onto a Langfuse generation; embeddings,
# /v1/models and health probes would just be noise in the trace view.
LANGFUSE_ENDPOINTS = frozenset({"/v1/chat/completions", "/v1/responses"})
# A dead Langfuse must not turn every request into a journald line.
EXPORT_ERROR_INTERVAL_SECONDS = 300


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


def load_price_map():
    """List prices in USD per 1M tokens, used only for estimates, never for billing."""
    raw = os.environ.get("LLAMA_PRICE_MAP")
    if not raw:
        return {}
    values = json.loads(raw)
    if not isinstance(values, dict):
        raise RuntimeError("LLAMA_PRICE_MAP must be a JSON object keyed by model ID")
    return values


def number(value):
    """Coerce to a real number; JSON booleans and numeric strings are not usage data."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return value


ALLOWED_MODELS = load_allowed_models()
PRICE_MAP = load_price_map()
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
        self.estimated_cost_usd = {}
        self.latency = {}
        self.ttft = {}

    def begin(self):
        with self.lock:
            self.in_flight += 1

    def finish(self, caller, model, status, usage, cost, latency_ms, ttft_ms):
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
            if isinstance(cost, dict):
                # Billed and estimated spend stay in separate series: mixing them
                # would make the cost dashboard silently wrong for either host.
                self._add_tokens(self.cost_usd, labels, cost.get("actual_usd"))
                self._add_tokens(
                    self.estimated_cost_usd, labels, cost.get("estimated_usd")
                )

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
                self._render_counter(
                    "ai_ingress_estimated_cost_usd",
                    self.estimated_cost_usd,
                    ("caller", "model"),
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
    return headers.get("X-AI-Caller") or "unattributed"


def append_log(record):
    line = json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n"
    with open(LOG_PATH, "a", encoding="utf-8") as handle:
        handle.write(line)


def parse_json(body):
    try:
        return json.loads(body) if body else None
    except json.JSONDecodeError:
        return None


def iter_sse_events(body):
    for line in body.splitlines():
        if not line.startswith(b"data: ") or line == b"data: [DONE]":
            continue
        event = parse_json(line[6:])
        if isinstance(event, dict):
            yield event


def extract_usage(body, document=None):
    """Usage block of a buffered response, whether it is JSON or an SSE transcript."""
    if document is None:
        document = parse_json(body)
    usage = document.get("usage") if isinstance(document, dict) else None
    if usage is not None or not body.startswith(b"data:"):
        return usage
    for event in iter_sse_events(body):
        usage = event.get("usage") or usage
        timings = event.get("timings")
        # llama.cpp streams timings instead of an OpenAI usage block.
        if usage is None and isinstance(timings, dict):
            usage = {
                "prompt_tokens": timings.get("prompt_n"),
                "completion_tokens": timings.get("predicted_n"),
                "total_tokens": (
                    timings.get("prompt_n", 0) + timings.get("predicted_n", 0)
                ),
            }
    return usage


def extract_output(body, document=None):
    """Assistant text for the trace; streamed deltas are reassembled best-effort."""
    if document is None:
        document = parse_json(body)
    if isinstance(document, dict):
        choices = document.get("choices")
        if isinstance(choices, list) and choices and isinstance(choices[0], dict):
            message = choices[0].get("message")
            if isinstance(message, dict):
                return message.get("content")
        return document.get("output_text") or document.get("output")
    if not body.startswith(b"data:"):
        return None
    parts = []
    for event in iter_sse_events(body):
        for choice in event.get("choices") or []:
            delta = choice.get("delta") if isinstance(choice, dict) else None
            if isinstance(delta, dict) and isinstance(delta.get("content"), str):
                parts.append(delta["content"])
        # The Responses API streams typed events carrying a bare text delta.
        if isinstance(event.get("delta"), str):
            parts.append(event["delta"])
    return "".join(parts) or None


def compute_cost(model, usage, price_map=None):
    """Provider billing and list-price estimate; neither substitutes for the other."""
    prices = PRICE_MAP if price_map is None else price_map
    actual = None
    estimated = None
    if isinstance(usage, dict):
        actual = number(usage.get("cost"))
        if actual is None:
            actual = number(usage.get("total_cost"))
        price = prices.get(model) if isinstance(model, str) else None
        if isinstance(price, dict):
            # The Responses API names the same counts input_tokens/output_tokens.
            prompt = number(usage.get("prompt_tokens"))
            if prompt is None:
                prompt = number(usage.get("input_tokens"))
            completion = number(usage.get("completion_tokens"))
            if completion is None:
                completion = number(usage.get("output_tokens"))
            input_price = number(price.get("input"))
            output_price = number(price.get("output"))
            if all(
                value is not None
                for value in (prompt, completion, input_price, output_price)
            ):
                estimated = (
                    prompt * input_price + completion * output_price
                ) / 1_000_000
    if actual is not None:
        source = "provider"
    elif estimated is not None:
        source = "registry-estimate"
    else:
        source = "unavailable"
    return {"actual_usd": actual, "estimated_usd": estimated, "source": source}


def build_observation(
    endpoint,
    caller,
    model,
    request_json,
    output,
    usage,
    cost,
    status,
    latency_ms,
    ttft_ms,
):
    usage_details = {}
    if isinstance(usage, dict):
        prompt = number(usage.get("prompt_tokens"))
        if prompt is None:
            prompt = number(usage.get("input_tokens"))
        completion = number(usage.get("completion_tokens"))
        if completion is None:
            completion = number(usage.get("output_tokens"))
        total = number(usage.get("total_tokens"))
        if total is None and (prompt is not None or completion is not None):
            total = (prompt or 0) + (completion or 0)
        for key, value in (("input", prompt), ("output", completion), ("total", total)):
            if value is not None:
                usage_details[key] = value
    selected = cost.get("actual_usd")
    if selected is None:
        selected = cost.get("estimated_usd")
    request_input = request_json
    if isinstance(request_json, dict):
        request_input = request_json.get("messages") or request_json.get("input")
        if request_input is None:
            request_input = request_json
    return {
        "name": f"ai-ingress {endpoint}",
        "as_type": "generation",
        "model": model,
        "input": request_input,
        "output": output,
        "usage_details": usage_details or None,
        "cost_details": None if selected is None else {"total": selected},
        "metadata": {
            "source": "ai-ingress",
            "caller": caller,
            "environment": ENVIRONMENT,
            "host": HOSTNAME,
            "status": status,
            "latency_ms": latency_ms,
            "ttft_ms": ttft_ms,
            "cost_source": cost.get("source"),
        },
    }


def create_langfuse_client():
    """Construct the SDK lazily; the ingress must keep serving without langfuse."""
    public_key = load_credential("LANGFUSE_PUBLIC_KEY_CREDENTIAL")
    secret_key = load_credential("LANGFUSE_SECRET_KEY_CREDENTIAL")
    if not public_key or not secret_key:
        raise RuntimeError("langfuse credentials are not configured")
    from langfuse import Langfuse

    # The OTLP exporter logs a WARNING per retry per batch. With Langfuse down
    # and traffic flowing that is unbounded journald noise about a subsystem
    # that is explicitly best-effort; the give-up line at ERROR still lands,
    # and our own reporter is separately rate-limited.
    logging.getLogger("opentelemetry.exporter.otlp.proto.http.trace_exporter").setLevel(
        logging.ERROR
    )

    return Langfuse(
        public_key=public_key,
        secret_key=secret_key,
        base_url=LANGFUSE_BASE_URL,
        environment=ENVIRONMENT,
    )


class LangfuseExporter:
    """Ships generation observations to Langfuse off the request path.

    Every failure mode - absent SDK, bad credentials, dead server - is contained
    here: the queue is bounded so a stalled exporter drops traces instead of
    growing without limit, and stderr is rate limited so it cannot flood journald.
    """

    def __init__(self, client_factory):
        self.queue = queue.Queue(maxsize=1024)
        self._client_factory = client_factory
        self._client = None
        self._disabled = False
        self._worker = None
        self._lock = threading.Lock()
        self._last_report = None

    def submit(self, observation):
        if self._disabled:
            return
        with self._lock:
            if self._worker is None:
                self._worker = threading.Thread(
                    target=self._run, name="langfuse-export", daemon=True
                )
                self._worker.start()
        try:
            self.queue.put_nowait(observation)
        except queue.Full:
            self.report("langfuse export queue is full; dropping observation")

    def _run(self):
        while True:
            observation = self.queue.get()
            try:
                self._deliver(observation)
            except Exception as error:
                self.report(f"langfuse export failed: {error}")
            finally:
                self.queue.task_done()

    def _deliver(self, observation):
        if self._disabled:
            return
        if self._client is None:
            try:
                self._client = self._client_factory()
            except Exception as error:
                # A broken configuration will not fix itself mid-process.
                self._disabled = True
                self.report(f"langfuse export disabled: {error}")
                return
        # The span is created after the request already finished, so OTEL would
        # stamp start == end and Langfuse would render 0 ms. Close it at the
        # measured latency instead: the duration is then truthful, only shifted
        # later by the export lag (single-digit ms while the worker keeps up).
        started_ns = time.time_ns()
        span = self._client.start_observation(**observation)
        metadata = observation.get("metadata") or {}
        latency_ms = metadata.get("latency_ms")
        end_time = (
            started_ns + int(latency_ms * 1_000_000)
            if isinstance(latency_ms, (int, float))
            else None
        )
        span.end(end_time=end_time)
        # Flush once the burst is drained: keeps SDK batching under load while an
        # idle ingress still ships its last trace promptly.
        if self.queue.empty():
            self._client.flush()

    def report(self, message):
        now = time.monotonic()
        if (
            self._last_report is not None
            and now - self._last_report < EXPORT_ERROR_INTERVAL_SECONDS
        ):
            return
        self._last_report = now
        print(message, file=sys.stderr, flush=True)


LANGFUSE_EXPORTER = (
    LangfuseExporter(create_langfuse_client) if LANGFUSE_BASE_URL else None
)


def export_observation(**fields):
    """Tracing is strictly best-effort; it never delays or fails a proxied request."""
    exporter = LANGFUSE_EXPORTER
    if exporter is None:
        return
    try:
        exporter.submit(build_observation(**fields))
    except Exception as error:
        exporter.report(f"langfuse observation dropped: {error}")


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
            response_json = parse_json(response_body)
            usage = extract_usage(response_body, response_json)
            cost = compute_cost(model, usage)
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
                    "ttft_ms": ttft_ms,
                    "usage": usage,
                    "cost": cost,
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
            METRICS.finish(caller, model, status, usage, cost, elapsed_ms, ttft_ms)
            if self.path in LANGFUSE_ENDPOINTS and LANGFUSE_EXPORTER is not None:
                export_observation(
                    endpoint=self.path,
                    caller=caller,
                    model=model,
                    request_json=request_json,
                    output=extract_output(response_body, response_json),
                    usage=usage,
                    cost=cost,
                    status=status,
                    latency_ms=elapsed_ms,
                    ttft_ms=ttft_ms,
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
        cost = compute_cost(model, None)
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
                "cost": cost,
                "stream_completed": None,
                "client_disconnected": False,
                "proxy_error": "model_not_allowed",
                "request": request_json,
                "response": response_json,
                "response_content_type": "application/json",
                "upstream": {},
            }
        )
        METRICS.finish(caller, model, status, None, cost, elapsed_ms, None)
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
