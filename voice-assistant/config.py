"""
config.py - Central configuration for nio voice assistant services.

All values are loaded from environment variables (sourced from .env).
Sensitive keys are never hard-coded; this module only provides typed
defaults and validation helpers.
"""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Load .env from the project root (same directory as this file)
# ---------------------------------------------------------------------------
_ROOT = Path(__file__).parent
load_dotenv(_ROOT / ".env")

# ---------------------------------------------------------------------------
# API Keys
# ---------------------------------------------------------------------------
OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "dummy-key")
DEEPGRAM_API_KEY: str = os.getenv("DEEPGRAM_API_KEY", "")

# ---------------------------------------------------------------------------
# LLM – routed through a local litellm proxy
# ---------------------------------------------------------------------------
LLM_BASE_URL: str = os.getenv("LLM_BASE_URL", "http://localhost:7024/v1")
LLM_MODEL: str = os.getenv("LLM_MODEL", "openai/gpt-4o")
LLM_TEMPERATURE: float = float(os.getenv("LLM_TEMPERATURE", "0.7"))
LLM_MAX_TOKENS: int = int(os.getenv("LLM_MAX_TOKENS", "2048"))

# ---------------------------------------------------------------------------
# Voice / TTS – edge-tts (no API key required)
# ---------------------------------------------------------------------------
TTS_VOICE_ZH: str = os.getenv("TTS_VOICE_ZH", "zh-CN-XiaoxiaoNeural")
TTS_VOICE_EN: str = os.getenv("TTS_VOICE_EN", "en-US-AriaNeural")
TTS_DEFAULT_VOICE: str = os.getenv("TTS_DEFAULT_VOICE", TTS_VOICE_ZH)
TTS_RATE: str = os.getenv("TTS_RATE", "+0%")
TTS_VOLUME: str = os.getenv("TTS_VOLUME", "+0%")
TTS_PITCH: str = os.getenv("TTS_PITCH", "+0Hz")

# ---------------------------------------------------------------------------
# STT – prefer Deepgram when key present, otherwise local Whisper
# ---------------------------------------------------------------------------
STT_PROVIDER: str = os.getenv(
    "STT_PROVIDER",
    "deepgram" if DEEPGRAM_API_KEY else "whisper",
)

# Deepgram settings
DEEPGRAM_MODEL: str = os.getenv("DEEPGRAM_MODEL", "nova-2")
DEEPGRAM_LANGUAGE: str = os.getenv("DEEPGRAM_LANGUAGE", "zh-CN")

# Whisper (faster-whisper) settings
WHISPER_MODEL: str = os.getenv("WHISPER_MODEL", "base")   # tiny|base|small|medium|large-v3
WHISPER_DEVICE: str = os.getenv("WHISPER_DEVICE", "cpu")  # cpu|cuda|mps
WHISPER_COMPUTE_TYPE: str = os.getenv("WHISPER_COMPUTE_TYPE", "int8")
WHISPER_LANGUAGE: str = os.getenv("WHISPER_LANGUAGE", "zh")  # "" = auto-detect

# ---------------------------------------------------------------------------
# VAD
# ---------------------------------------------------------------------------
VAD_CONFIDENCE_THRESHOLD: float = float(os.getenv("VAD_CONFIDENCE_THRESHOLD", "0.7"))
VAD_START_SECS: float = float(os.getenv("VAD_START_SECS", "0.2"))
VAD_STOP_SECS: float = float(os.getenv("VAD_STOP_SECS", "0.8"))

# ---------------------------------------------------------------------------
# Audio pipeline
# ---------------------------------------------------------------------------
AUDIO_SAMPLE_RATE: int = int(os.getenv("AUDIO_SAMPLE_RATE", "16000"))
AUDIO_CHANNELS: int = int(os.getenv("AUDIO_CHANNELS", "1"))
AUDIO_SAMPLE_WIDTH: int = int(os.getenv("AUDIO_SAMPLE_WIDTH", "2"))  # bytes (16-bit PCM)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
SERVER_HOST: str = os.getenv("SERVER_HOST", "0.0.0.0")
SERVER_PORT: int = int(os.getenv("SERVER_PORT", "8891"))
SERVER_LOG_LEVEL: str = os.getenv("SERVER_LOG_LEVEL", "info")
CORS_ORIGINS: list[str] = os.getenv("CORS_ORIGINS", "*").split(",")

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPORTS_DIR: Path = _ROOT / os.getenv("REPORTS_DIR", "reports")
BOOKS_DIR: Path = Path(os.getenv("BOOKS_DIR", str(Path.home() / "Documents")))
FRONTEND_DIR: Path = _ROOT / "frontend"

# Ensure writable directories exist at import time
REPORTS_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# System prompt (Chinese)
# ---------------------------------------------------------------------------
SYSTEM_PROMPT: str = """你是 nio 语音助手，一个智能、友好且高效的中文语音助理。

## 你的核心能力
- 💬 自然流畅地进行中英双语对话
- 🖥️ 控制 Mac 电脑：打开应用、执行命令
- 🌐 搜索网页获取最新信息
- 🌤️ 查询实时天气
- 📚 读取本地文档和书籍内容
- 📝 生成和保存报告文件

## 行为准则
1. **简洁优先**：语音回答应简短、清晰，避免长篇大论。关键信息先说。
2. **中文为主**：除非用户用英文提问，否则一律使用中文回答。
3. **主动确认**：执行破坏性操作（删除文件、卸载软件等）前须询问用户确认。
4. **工具优先**：能用工具完成的任务优先调用工具，不要凭空臆测。
5. **诚实透明**：不确定时如实告知，不编造信息。
6. **自然语气**：像真人助手一样说话，避免机器感强的表述。

## 语音交互注意事项
- 回答要适合朗读，避免使用 Markdown 格式符号（如 ##、**、- 等）
- 数字和单位要读出来（例如：三十度、两公里）
- 情绪词汇自然融入语句，不要单独输出表情符号
"""
