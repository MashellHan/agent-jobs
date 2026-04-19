#!/bin/bash
# =============================================================================
# run.sh – Start the nio Voice Assistant server
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
if [[ ! -d "$SCRIPT_DIR/venv" ]]; then
    echo "❌ virtualenv not found. Please run setup first:"
    echo "   bash setup.sh"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/server.py" ]]; then
    echo "❌ server.py not found in $SCRIPT_DIR"
    exit 1
fi

# ---------------------------------------------------------------------------
# Load environment variables from .env (if present)
# ---------------------------------------------------------------------------
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | grep -v '^$' | xargs)
fi

# Resolve port (prefer SERVER_PORT from .env, then default 8891)
PORT="${SERVER_PORT:-8891}"
HOST="${SERVER_HOST:-0.0.0.0}"
LOG_LEVEL="${SERVER_LOG_LEVEL:-info}"

# ---------------------------------------------------------------------------
# Activate virtualenv
# ---------------------------------------------------------------------------
# shellcheck source=/dev/null
source "$SCRIPT_DIR/venv/bin/activate"

export PYTHONPATH="$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║      🎙️  nio 语音助手 启动中 …           ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  访问地址 / URL:    http://localhost:${PORT}"
echo "  WebSocket:         ws://localhost:${PORT}/ws"
echo "  健康检查 / Health: http://localhost:${PORT}/health"
echo ""
echo "  按 Ctrl+C 停止服务 / Press Ctrl+C to stop"
echo ""

# ---------------------------------------------------------------------------
# Start server
# ---------------------------------------------------------------------------
exec python "$SCRIPT_DIR/server.py"
