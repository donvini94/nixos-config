#!/usr/bin/env bash
set -euo pipefail

script=$(realpath "$(dirname "$0")/../tapeback-local.sh")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf '#!/bin/sh\ntouch "$TEST_OUTPUT"\nprintf "%%s\\n" "$TAPEBACK_STT_BACKEND" "$TAPEBACK_STT_MODEL" "$TAPEBACK_LANGUAGE" "$TAPEBACK_COMPUTE_TYPE" "$TAPEBACK_SUMMARIZE" "$TAPEBACK_DIARIZE" "$HF_HUB_OFFLINE" "$PYANNOTE_METRICS_ENABLED" "$*"\n' > "$tmp/tapeback"
chmod +x "$tmp/tapeback"
export PATH="$tmp:$PATH"
export TEST_OUTPUT="$tmp/private"
export TAPEBACK_STT_BACKEND=openai TAPEBACK_SUMMARIZE=true HF_HUB_OFFLINE=0

actual=$(bash "$script" process recording.wav)
expected=$(printf '%s\n' local large-v3 de float16 false true 1 0 'process recording.wav')
[[ "$actual" == "$expected" ]]
[[ "$(stat -c %a "$TEST_OUTPUT")" == 600 ]]
if bash "$script" summarize recording.md > "$tmp/output" 2>&1; then
  echo "Cloud summarization was not rejected" >&2
  exit 1
fi
grep -q 'Cloud summaries are disabled' "$tmp/output"
