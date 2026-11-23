#!/bin/sh
# Start wrapper for Railway.
# 1. Listens on Railway's PORT.
# 2. Creates the admin account from ADMIN_USERNAME / ADMIN_PASSWORD on the first boot, so the
#    setup wizard is never open to strangers (upstream opens it to the first visitor).
# 3. Runs Paperless-AI and exits non-zero if it stops on its own, so Railway's ON_FAILURE
#    restart policy brings it back.
set -eu
cd /app
export PAPERLESS_AI_PORT="${PORT:-${PAPERLESS_AI_PORT:-3000}}"

# One OpenAI-compatible LLM connection from the template variables (LLM_API_KEY, LLM_BASE_URL,
# LLM_MODEL). Upstream reads them as its "custom" provider. Environment values lock the matching
# settings in the web interface; leave LLM_API_KEY empty to configure the AI in the wizard instead.
if [ -n "${LLM_API_KEY:-}" ]; then
  export AI_PROVIDER="${AI_PROVIDER:-custom}"
  export CUSTOM_API_KEY="${CUSTOM_API_KEY:-$LLM_API_KEY}"
  export CUSTOM_BASE_URL="${CUSTOM_BASE_URL:-${LLM_BASE_URL:-https://api.openai.com/v1}}"
  export CUSTOM_MODEL="${CUSTOM_MODEL:-${LLM_MODEL:-gpt-5-mini}}"
fi

# Small Railway plans: OCR would start one thread per host CPU (up to 8).
export OCR_THREADS="${OCR_THREADS:-2}"

# Memory guard. The core app needs about 100 MB, but the two on-device ONNX features need more:
# OCR (PaddleOCR) about 600 MB and local embeddings for "Ask your archive" about 550 MB. Under a
# 0.5 GB limit (Railway Free/Trial) they would be OOM-killed on the first document, so below
# SMALL_PLAN_LIMIT_MB the start script locks OCR off and bootstrap.mjs switches local embeddings
# to keyword search. Raise the service's memory to 1 GB or more and redeploy to use them.
limit_bytes=""
if [ -r /sys/fs/cgroup/memory.max ]; then
  limit_bytes=$(cat /sys/fs/cgroup/memory.max)
elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
  limit_bytes=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
fi
case "$limit_bytes" in ''|max|*[!0-9]*) limit_mb=0 ;; *) limit_mb=$((limit_bytes / 1048576)) ;; esac
if [ "$limit_mb" -gt 0 ] && [ "$limit_mb" -lt "${SMALL_PLAN_LIMIT_MB:-900}" ]; then
  export PAPERLESS_AI_SMALL_PLAN=1
  if [ -z "${OCR_ENABLED:-}" ]; then
    export OCR_ENABLED=false
  fi
  echo "[railway] memory limit ${limit_mb} MB: OCR and local embeddings are off (they need about 1 GB). Raise the service memory and redeploy to use them." >&2
fi
mkdir -p "$PAPERLESS_AI_DATA_DIR"

node /railway/bootstrap.mjs

node dist/server/index.js &
child=$!
stopping=0
trap 'stopping=1; kill -TERM "$child" 2>/dev/null || true' TERM INT
status=0
while kill -0 "$child" 2>/dev/null; do
  set +e
  wait "$child"
  status=$?
  set -e
done
if [ "$stopping" = 1 ]; then
  exit "$status"
fi
echo "Paperless-AI stopped unexpectedly (exit $status)" >&2
[ "$status" -eq 0 ] && status=1
exit "$status"
