#!/usr/bin/env python3
"""Serve Confucius4-R2T2 streaming transcription on a local WebSocket."""

from __future__ import annotations

import argparse
import asyncio
import json
import signal
import time
from http import HTTPStatus
from typing import Any, Literal

import numpy as np
from pydantic import BaseModel, ConfigDict, Field, ValidationError
from r2t2 import R2T2ASRModel
from websockets.asyncio.server import ServerConnection, serve
from websockets.exceptions import ConnectionClosed
from websockets.http11 import Request, Response

END_OF_STREAM = "YOUDAO_ONETIME_ASR_STREAM_EOS"
ENDPOINT = "/asr_stream_api_v1"
SAMPLE_RATE = 16_000
FIRST_CHUNK_SECONDS = 0.32
CHUNK_SECONDS = 0.16
FINAL_PAD_SAMPLES = SAMPLE_RATE // 2
MAX_MODEL_LENGTH = 8_192


class StreamHeader(BaseModel):
    """Fields the local capture client sends before the first audio frame."""

    model_config = ConfigDict(extra="forbid")

    channels: Literal[1]
    sample_rate: Literal[16_000]
    request_id: str = Field(min_length=1, max_length=128)
    # Omitted means auto-detect. A forced language stops the model from
    # translating: on accented or short speech it otherwise answers in English.
    language: str | None = None


def log(event: str, **fields: Any) -> None:
    print(json.dumps({"event": event, **fields}, ensure_ascii=False), flush=True)


def response(
    request_id: str, text: str, *, reset: bool, elapsed_ms: float = 0.0
) -> str:
    return json.dumps(
        {
            "status": "success",
            "request_id": request_id,
            "msg": {
                "text": text,
                "reset": reset,
                "asr_cost_ms": round(elapsed_ms, 1),
            },
        },
        ensure_ascii=False,
    )


def process_request(connection: ServerConnection, request: Request) -> Response | None:
    if request.path == "/health":
        return connection.respond(HTTPStatus.OK, "ready\n")
    return None


async def send_error(
    connection: ServerConnection, request_id: str, message: str
) -> None:
    await connection.send(
        json.dumps(
            {"status": "error", "request_id": request_id, "msg": message},
            ensure_ascii=False,
        )
    )


class TranscriptionServer:
    def __init__(self, model: R2T2ASRModel) -> None:
        self._model = model
        self._session_lock = asyncio.Lock()

    async def handle(self, connection: ServerConnection) -> None:
        if connection.request.path != ENDPOINT:
            await connection.close(code=1008, reason="unknown endpoint")
            return
        if self._session_lock.locked():
            await send_error(connection, "", "another transcription session is active")
            await connection.close(code=1013, reason="server busy")
            return

        async with self._session_lock:
            await self._transcribe(connection)

    async def _transcribe(self, connection: ServerConnection) -> None:
        request_id = ""
        try:
            raw_header = await connection.recv()
            if not isinstance(raw_header, str):
                await send_error(
                    connection, request_id, "JSON stream header is required"
                )
                return
            try:
                header = StreamHeader.model_validate_json(raw_header)
            except ValidationError as error:
                await send_error(
                    connection, request_id, f"invalid stream header: {error}"
                )
                return

            request_id = header.request_id
            try:
                state = self._model.init_streaming_state(
                    language=header.language,
                    unfixed_chunk_num=0,
                    unfixed_token_num=1,
                    chunk_size_sec=FIRST_CHUNK_SECONDS,
                )
            except ValueError as error:
                await send_error(connection, request_id, str(error))
                return
            sent_text = ""
            first_chunk = True
            await connection.send(
                json.dumps(
                    {
                        "status": "connected",
                        "request_id": request_id,
                        "msg": "",
                    }
                )
            )
            log("stream_started", request_id=request_id, language=header.language)

            async for message in connection:
                if isinstance(message, str):
                    if message != END_OF_STREAM:
                        continue
                    log(
                        "stream_flushing",
                        request_id=request_id,
                        chunks=state.chunk_id,
                        audio_samples=int(state.audio_accum.size),
                        buffered_samples=int(state.buffer.size),
                    )
                    # The finalizer skips inference on an empty buffer, and without a
                    # trailing silence the decoder leaves the last word unfixed.
                    state.buffer = np.concatenate(
                        [state.buffer, np.zeros(FINAL_PAD_SAMPLES, dtype=np.float32)]
                    )
                    final_text = self._model.finish_streaming_transcribe_no_reset(
                        state, max_new_tokens=128
                    ).split("|", 1)[0]
                    delta = (
                        final_text[len(sent_text) :]
                        if len(final_text) > len(sent_text)
                        else ""
                    )
                    await connection.send(response(request_id, delta, reset=True))
                    log(
                        "stream_finished",
                        request_id=request_id,
                        characters=len(final_text),
                    )
                    await connection.close()
                    return

                started = time.monotonic()
                _, fixed_text = self._model.streaming_transcribe_no_reset(
                    np.frombuffer(message, dtype="<i2"),
                    state,
                    max_new_tokens=32,
                )
                if first_chunk and state.audio_accum.size > 0:
                    first_chunk = False
                    state.chunk_size_sec = CHUNK_SECONDS
                    state.chunk_size_samples = int(CHUNK_SECONDS * SAMPLE_RATE)

                fixed_text = fixed_text.split("|", 1)[0]
                if len(fixed_text) <= len(sent_text):
                    continue
                delta = fixed_text[len(sent_text) :]
                sent_text = fixed_text
                await connection.send(
                    response(
                        request_id,
                        delta,
                        reset=False,
                        elapsed_ms=(time.monotonic() - started) * 1_000,
                    )
                )
        except ConnectionClosed:
            log("stream_disconnected", request_id=request_id)
        except Exception as error:
            log("stream_failed", request_id=request_id, error=str(error))
            if connection.state.name == "OPEN":
                await send_error(connection, request_id, str(error))
            raise


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8272)
    parser.add_argument("--gpu-memory-utilization", type=float, default=0.4)
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    log(
        "model_loading",
        model=args.model,
        gpu_memory_utilization=args.gpu_memory_utilization,
    )
    model = R2T2ASRModel.LLM(
        model=args.model,
        gpu_memory_utilization=args.gpu_memory_utilization,
        max_model_len=MAX_MODEL_LENGTH,
        max_new_tokens=4,
    )
    server = TranscriptionServer(model)
    async with serve(
        server.handle,
        args.host,
        args.port,
        ping_interval=None,
        max_size=64 * 1024,
        process_request=process_request,
    ):
        log("server_ready", host=args.host, port=args.port)
        stopped = asyncio.Event()
        loop = asyncio.get_running_loop()
        loop.add_signal_handler(signal.SIGINT, stopped.set)
        loop.add_signal_handler(signal.SIGTERM, stopped.set)
        await stopped.wait()


if __name__ == "__main__":
    asyncio.run(main())
