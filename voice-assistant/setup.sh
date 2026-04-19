#!/bin/bash
# =============================================================================
# setup.sh – One-shot setup for nio Voice Assistant
# =============================================================================
# Usage:  bash setup.sh
#
# This script:
#   1. Locates Python 3.13 (/opt/homebrew/bin/python3.13) or falls back to
#      any Python ≥ 3.11 found in PATH
#   2. Creates a virtualenv at ./venv
#   3. Upgrades pip and installs all required packages
#   4. Creates a .env template if one does not already exist
#   5. Pre-downloads the Whisper base model via faster-whisper
#   6. Creates the reports/ directory
# =============================================================================

set -euo pipefail

COLOR_OK="\033[0;32m"
COLOR_WARN="\033[0;33m"
COLOR_ERR="\033[0;31m"
COLOR_BOLD="\033[1m"
NC="\033[0m"

ok()   { echo -e "${COLOR_OK}✅ $*${NC}"; }
warn() { echo -e "${COLOR_WARN}⚠️  $*${NC}"; }
err()  { echo -e "${COLOR_ERR}❌ $*${NC}"; exit 1; }
info() { echo -e "${COLOR_BOLD}➜  $*${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   nio 语音助手 – 环境安装 / Setup        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ---------------------------------------------------------------------------
# 1. Find Python
# ---------------------------------------------------------------------------
info "Locating Python interpreter …"

PYTHON=""
PREFERRED="/opt/homebrew/bin/python3.13"

if [[ -x "$PREFERRED" ]]; then
    PYTHON="$PREFERRED"
    ok "Found preferred Python: $PYTHON  ($("$PYTHON" --version))"
else
    warn "Python 3.13 not found at $PREFERRED, searching PATH …"
    for candidate in python3.13 python3.12 python3.11 python3; do
        if command -v "$candidate" &>/dev/null; then
            # Check version tuple is at least (3, 11)
            VER=$("$candidate" -c "import sys; print(sys.version_info >= (3,11))" 2>/dev/null || echo "False")
            if [[ "$VER" == "True" ]]; then
                PYTHON=$(command -v "$candidate")
                ok "Using $PYTHON  ($("$PYTHON" --version))"
                break
            fi
        fi
    done
fi

[[ -z "$PYTHON" ]] && err "No suitable Python (≥ 3.11) found. Install with: brew install python@3.13"

# ---------------------------------------------------------------------------
# 2. Create virtualenv
# ---------------------------------------------------------------------------
VENV_DIR="$SCRIPT_DIR/venv"

if [[ -d "$VENV_DIR" ]]; then
    warn "Virtualenv already exists at $VENV_DIR — skipping creation."
else
    info "Creating virtualenv at $VENV_DIR …"
    "$PYTHON" -m venv "$VENV_DIR"
    ok "Virtualenv created."
fi

PIP="$VENV_DIR/bin/pip"
PYTHON_VENV="$VENV_DIR/bin/python"

# ---------------------------------------------------------------------------
# 3. Upgrade pip + setuptools
# ---------------------------------------------------------------------------
info "Upgrading pip and setuptools …"
"$PIP" install --quiet --upgrade pip setuptools wheel
ok "pip upgraded."

# ---------------------------------------------------------------------------
# 4. Install dependencies
# ---------------------------------------------------------------------------
info "Installing core framework …"
"$PIP" install --quiet \
    "fastapi>=0.111" \
    "uvicorn[standard]>=0.29"

info "Installing audio / VAD packages …"
"$PIP" install --quiet \
    "webrtcvad>=2.0.10" \
    "numpy>=1.26"

info "Installing STT (faster-whisper) …"
"$PIP" install --quiet \
    "faster-whisper>=1.0.2"

info "Installing TTS (edge-tts) …"
"$PIP" install --quiet \
    "edge-tts>=6.1.10"

info "Installing LLM clients …"
"$PIP" install --quiet \
    "openai>=1.30" \
    "litellm>=1.40"

info "Installing utilities …"
"$PIP" install --quiet \
    "python-dotenv>=1.0" \
    "aiohttp>=3.9" \
    "websockets>=12.0"

info "Installing PyTorch (CPU build) for Silero VAD …"
"$PIP" install --quiet \
    "torch>=2.3" \
    "torchaudio>=2.3" \
    --index-url https://download.pytorch.org/whl/cpu \
  || warn "PyTorch install failed – Silero VAD unavailable, webrtcvad will be used instead."

"$PIP" install --quiet "silero-vad>=5.1" || true

info "Attempting to install pipecat-ai (full pipeline) …"
"$PIP" install --quiet \
    "pipecat-ai[websocket,openai,silero,deepgram,edge-tts]>=0.0.47" \
  || warn "pipecat-ai not available – the server will use the built-in fallback pipeline."

info "Installing optional Deepgram SDK …"
"$PIP" install --quiet "deepgram-sdk>=3.2" || true

ok "All Python dependencies installed."

# ---------------------------------------------------------------------------
# 5. Create .env template
# ---------------------------------------------------------------------------
ENV_FILE="$SCRIPT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
    warn ".env already exists at $ENV_FILE — skipping template creation."
else
    info "Creating .env template …"
    cat > "$ENV_FILE" << 'ENVEOF'
# ============================================================
# nio Voice Assistant – Environment Configuration
# ============================================================

# --- LLM (litellm proxy running locally) ---
OPENAI_API_KEY=dummy-key
LLM_BASE_URL=http://localhost:7024/v1
LLM_MODEL=openai/gpt-4o
LLM_TEMPERATURE=0.7
LLM_MAX_TOKENS=2048

# --- STT ---
# Options: whisper | deepgram
STT_PROVIDER=whisper
WHISPER_MODEL=base
# Options: tiny | base | small | medium | large-v3
WHISPER_DEVICE=cpu
# Options: cpu | cuda | mps
WHISPER_LANGUAGE=zh
# Set to empty string for auto-detect

# Deepgram (only required if STT_PROVIDER=deepgram)
DEEPGRAM_API_KEY=

# --- TTS (edge-tts, no API key required) ---
TTS_DEFAULT_VOICE=zh-CN-XiaoxiaoNeural
TTS_VOICE_ZH=zh-CN-XiaoxiaoNeural
TTS_VOICE_EN=en-US-AriaNeural
TTS_RATE=+0%
TTS_VOLUME=+0%
TTS_PITCH=+0Hz

# --- Server ---
SERVER_HOST=0.0.0.0
SERVER_PORT=8891
SERVER_LOG_LEVEL=info
CORS_ORIGINS=*

# --- Optional directories ---
# REPORTS_DIR=reports
# BOOKS_DIR=/Users/you/Documents
ENVEOF
    ok ".env template created. Please review it and fill in your API keys."
fi

# ---------------------------------------------------------------------------
# 6. Pre-download Whisper model
# ---------------------------------------------------------------------------
WHISPER_MODEL_NAME="${WHISPER_MODEL:-base}"
info "Pre-downloading Whisper model '${WHISPER_MODEL_NAME}' …"

"$PYTHON_VENV" - <<PYEOF
import sys
try:
    from faster_whisper import WhisperModel
    print(f"  Downloading / verifying Whisper model: ${WHISPER_MODEL_NAME}")
    m = WhisperModel("${WHISPER_MODEL_NAME}", device="cpu", compute_type="int8")
    print("  Model loaded successfully.")
except Exception as e:
    print(f"  Warning: could not pre-load Whisper model: {e}", file=sys.stderr)
PYEOF

# ---------------------------------------------------------------------------
# 7. Create necessary directories
# ---------------------------------------------------------------------------
mkdir -p "$SCRIPT_DIR/reports"
mkdir -p "$SCRIPT_DIR/frontend"
ok "reports/ and frontend/ directories ready."

# ---------------------------------------------------------------------------
# 8. Ensure scripts are executable
# ---------------------------------------------------------------------------
chmod +x "$SCRIPT_DIR/run.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/setup.sh"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        安装完成！Setup complete! 🎉      ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Next steps / 下一步："
echo ""
echo "  1. Edit .env and configure API keys / LLM proxy URL"
echo "     编辑 .env，填写 API Key 和代理地址"
echo ""
echo "  2. Ensure litellm proxy is running on port 7024"
echo "     确保 litellm 代理在 7024 端口运行"
echo "     例：litellm --model gpt-4o --port 7024"
echo ""
echo "  3. Start the server:"
echo "     bash run.sh"
echo ""
echo "  4. Open in browser:"
echo "     http://localhost:8891"
echo ""
