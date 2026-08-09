"""Loopback reverse proxy that records complete OpenAI requests and responses as JSONL."""

import json
import os
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BACKEND = os.environ["LLAMA_BACKEND"]
LOG_PATH = os.environ["LLAMA_REQUEST_LOG"]
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


def append_log(record):
    line = json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n"
    with open(LOG_PATH, "a", encoding="utf-8") as handle:
        handle.write(line)


class Proxy(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, _format, *_args):
        return

    def _proxy(self):
        started = time.monotonic()
        length = int(self.headers.get("Content-Length", "0"))
        request_body = self.rfile.read(length)
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in HOP_HEADERS
        }
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
            request_json = None
            response_json = None
            try:
                request_json = json.loads(request_body) if request_body else None
            except json.JSONDecodeError:
                pass
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
                    "caller": self.headers.get("X-AI-Caller", "unattributed"),
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
                }
            )
            self.close_connection = True

    do_GET = _proxy
    do_POST = _proxy


if __name__ == "__main__":
    os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
    server = ThreadingHTTPServer(
        (os.environ["LLAMA_PROXY_HOST"], int(os.environ["LLAMA_PROXY_PORT"])), Proxy
    )
    server.serve_forever()
