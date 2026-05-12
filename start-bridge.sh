#!/bin/sh
set -eu

export FORTIFY_DATA_DIR="${FORTIFY_DATA_DIR:-/fcli-data}"
export FCLI_MCP_MODULE="${FCLI_MCP_MODULE:-ssc}"
export MCP_PORT="${MCP_PORT:-8000}"
export MCP_BASE_URL="${MCP_BASE_URL:-http://fortify-mcp-bridge:8000}"

# If arguments are passed, run them directly.
# This lets us reuse the same container for login and diagnostics:
# docker compose run --rm fortify-mcp-bridge fcli.sh ssc session list
if [ "$#" -gt 0 ]; then
  exec "$@"
fi

exec supergateway \
  --stdio "/usr/local/bin/fcli.sh util mcp-server start --module=${FCLI_MCP_MODULE}" \
  --port "${MCP_PORT}" \
  --baseUrl "${MCP_BASE_URL}" \
  --ssePath /sse \
  --messagePath /message \
  --healthEndpoint /healthz \
  --logLevel info
