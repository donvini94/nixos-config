#!/usr/bin/env bash

if [[ "${1:-}" == "summarize" ]]; then
  echo "Cloud summaries are disabled in this local-only Tapeback installation." >&2
  exit 1
fi

umask 077

export TAPEBACK_STT_BACKEND=local
export TAPEBACK_STT_MODEL=large-v3
export TAPEBACK_LANGUAGE=de
export TAPEBACK_DEVICE=cuda
export TAPEBACK_COMPUTE_TYPE=float16
export TAPEBACK_HOTWORDS=""
export TAPEBACK_DIARIZE=true
export TAPEBACK_SUMMARIZE=false
export TAPEBACK_LIVE=false
export HF_HUB_OFFLINE=1
export HF_HUB_DISABLE_TELEMETRY=1
export PYANNOTE_METRICS_ENABLED=0
export OTEL_SDK_DISABLED=true

exec tapeback "$@"
