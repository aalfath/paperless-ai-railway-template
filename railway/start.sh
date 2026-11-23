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

# Small Railway plans: OCR (off by default) would start one thread per host CPU (up to 8).
export OCR_THREADS="${OCR_THREADS:-2}"
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
