"""
server.py – FastAPI + Pipecat voice pipeline server for nio voice assistant.

Architecture
------------
WebSocket (/ws)
  └── Raw PCM audio in  (16 kHz, 16-bit, mono)
        └── Pipecat Pipeline
              ├── WebsocketServerTransport  (audio I/O frames)
              ├── SileroVADAnalyzer         (voice activity detection)
              ├── STT service               (Deepgram or Whisper)
              ├── OpenAILLMService          (litellm proxy, with tool calls)
              ├── Tool executor processor   (calls tools.py)
              └── EdgeTTSService            (synthesis)
  └── Audio bytes + text JSON out

If pipecat imports fail, the server falls back to a simpler manual pipeline
(webrtcvad → faster-whisper → openai client → edge-tts).
"""

from __future__ import annotations

import asyncio
import json
import logging
import sys
import traceback
from pathlib import Path
from typing import Any

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

import config
import tools as tool_module

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("nio.server")

# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(title="nio Voice Assistant", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve static frontend if directory exists
_frontend_dir = config.FRONTEND_DIR
if _frontend_dir.exists():
    app.mount("/static", StaticFiles(directory=str(_frontend_dir)), name="static")


@app.get("/", response_class=HTMLResponse)
async def index():
    index_file = _frontend_dir / "index.html"
    if index_file.exists():
        return HTMLResponse(content=index_file.read_text(encoding="utf-8"))
    return HTMLResponse(content=_DEFAULT_INDEX_HTML)


@app.get("/health")
async def health():
    return JSONResponse({"status": "ok", "version": "1.0.0"})


# ---------------------------------------------------------------------------
# Try importing pipecat (PRIMARY pipeline)
# ---------------------------------------------------------------------------
_PIPECAT_AVAILABLE = False
try:
    from pipecat.pipeline.pipeline import Pipeline
    from pipecat.pipeline.runner import PipelineRunner
    from pipecat.pipeline.task import PipelineParams, PipelineTask
    from pipecat.processors.aggregators.openai_llm_context import (
        OpenAILLMContext,
        OpenAILLMContextAggregator,
    )
    from pipecat.processors.frame_processor import FrameProcessor
    from pipecat.frames.frames import (
        Frame,
        LLMMessagesFrame,
        TextFrame,
        AudioRawFrame,
        TranscriptionFrame,
        FunctionCallResultFrame,
        EndFrame,
    )
    from pipecat.services.openai import OpenAILLMService
    from pipecat.transports.network.websocket_server import (
        WebsocketServerParams,
        WebsocketServerTransport,
    )

    # VAD – try both known import paths
    try:
        from pipecat.audio.vad.silero import SileroVADAnalyzer
    except ImportError:
        from pipecat.vad.silero import SileroVADAnalyzer  # type: ignore[no-redef]

    # STT
    if config.STT_PROVIDER == "deepgram" and config.DEEPGRAM_API_KEY:
        from pipecat.services.deepgram import DeepgramSTTService as _STTService  # type: ignore
        _STT_KWARGS = {
            "api_key": config.DEEPGRAM_API_KEY,
            "model": config.DEEPGRAM_MODEL,
            "language": config.DEEPGRAM_LANGUAGE,
        }
    else:
        # Use OpenAI-compatible Whisper endpoint or local whisper wrapper
        # Pipecat may ship a WhisperSTTService; fall back to a simple frame processor
        try:
            from pipecat.services.whisper import WhisperSTTService as _STTService  # type: ignore
            _STT_KWARGS = {"model": config.WHISPER_MODEL}
        except ImportError:
            _STTService = None  # type: ignore
            _STT_KWARGS = {}

    # TTS
    try:
        from pipecat.services.edge_tts import EdgeTTSService  # type: ignore
        _TTS_AVAILABLE = True
    except ImportError:
        _TTS_AVAILABLE = False

    _PIPECAT_AVAILABLE = True
    logger.info("✅ pipecat imports successful")

except ImportError as _pipecat_err:
    logger.warning(f"⚠️  pipecat not available ({_pipecat_err}), using fallback pipeline")
    _PIPECAT_AVAILABLE = False


# ===========================================================================
# PRIMARY PIPELINE  (pipecat)
# ===========================================================================

if _PIPECAT_AVAILABLE:

    # -----------------------------------------------------------------------
    # Tool-call processor
    # -----------------------------------------------------------------------
    class ToolCallProcessor(FrameProcessor):  # type: ignore[misc]
        """
        Intercepts LLM function-call frames, executes the corresponding
        tool from tools.py, and feeds the result back into the context.
        """

        def __init__(self, context: OpenAILLMContext, **kwargs):
            super().__init__(**kwargs)
            self._context = context

        async def process_frame(self, frame: Frame, direction):
            await super().process_frame(frame, direction)

            # Detect function call result request frames
            if hasattr(frame, "function_name") and hasattr(frame, "arguments"):
                fn_name: str = frame.function_name  # type: ignore[attr-defined]
                try:
                    args = (
                        json.loads(frame.arguments)  # type: ignore[attr-defined]
                        if isinstance(frame.arguments, str)  # type: ignore[attr-defined]
                        else frame.arguments  # type: ignore[attr-defined]
                    )
                except json.JSONDecodeError:
                    args = {}

                logger.info(f"🔧 Tool call: {fn_name}({args})")
                result = await tool_module.dispatch_tool(fn_name, args)
                logger.info(f"🔧 Tool result: {result[:120]}…")

                # Inject result back into LLM context
                self._context.add_message(
                    {"role": "tool", "content": result, "tool_call_id": getattr(frame, "tool_call_id", "0")}
                )

                result_frame = FunctionCallResultFrame(
                    function_name=fn_name,
                    tool_call_id=getattr(frame, "tool_call_id", "0"),
                    arguments=frame.arguments,  # type: ignore[attr-defined]
                    result=result,
                )
                await self.push_frame(result_frame, direction)
            else:
                await self.push_frame(frame, direction)

    # -----------------------------------------------------------------------
    # Build and run the pipecat pipeline for a single WebSocket connection
    # -----------------------------------------------------------------------

    async def _run_pipecat_pipeline(websocket: WebSocket):
        """
        Build a full Pipecat pipeline attached to *websocket* and run it
        until the connection is closed or an error occurs.
        """
        # -- Transport -------------------------------------------------------
        transport = WebsocketServerTransport(
            websocket=websocket,
            params=WebsocketServerParams(
                audio_out_enabled=True,
                add_wav_header=False,
                vad_enabled=True,
                vad_analyzer=SileroVADAnalyzer(),
                vad_audio_passthrough=True,
                session_timeout=None,
            ),
        )

        # -- LLM context & service -------------------------------------------
        context = OpenAILLMContext(
            messages=[{"role": "system", "content": config.SYSTEM_PROMPT}],
            tools=tool_module.TOOLS_SCHEMA,
        )
        context_aggregator = transport.create_input_transport_processor()  # type: ignore[attr-defined]

        llm = OpenAILLMService(
            api_key=config.OPENAI_API_KEY,
            base_url=config.LLM_BASE_URL,
            model=config.LLM_MODEL,
        )

        # -- STT -------------------------------------------------------------
        if _STTService is not None:
            stt = _STTService(**_STT_KWARGS)
        else:
            stt = _make_fallback_stt_processor()

        # -- Tool call processor ---------------------------------------------
        tool_processor = ToolCallProcessor(context=context)

        # -- TTS -------------------------------------------------------------
        if _TTS_AVAILABLE:
            tts = EdgeTTSService(voice=config.TTS_DEFAULT_VOICE)
        else:
            tts = _make_fallback_tts_processor()

        # -- Aggregators -----------------------------------------------------
        llm_context_aggregator = OpenAILLMContextAggregator(context)

        # -- Pipeline --------------------------------------------------------
        pipeline = Pipeline(
            [
                transport.input(),           # audio frames in
                stt,                         # audio → TranscriptionFrame
                llm_context_aggregator.user(),
                llm,                         # TranscriptionFrame → LLM
                tool_processor,              # handle tool calls
                tts,                         # text → AudioRawFrame
                transport.output(),          # send audio + text
                llm_context_aggregator.assistant(),
            ]
        )

        runner = PipelineRunner()
        task = PipelineTask(
            pipeline,
            params=PipelineParams(allow_interruptions=True),
        )

        logger.info("🚀 Pipecat pipeline started")
        try:
            await runner.run(task)
        except Exception as exc:
            logger.error(f"Pipeline error: {exc}")
            raise

    def _make_fallback_stt_processor():
        """Minimal STT no-op processor when Whisper/Deepgram pipecat service unavailable."""
        class PassthroughSTT(FrameProcessor):  # type: ignore[misc]
            async def process_frame(self, frame, direction):
                await super().process_frame(frame, direction)
                await self.push_frame(frame, direction)
        return PassthroughSTT()

    def _make_fallback_tts_processor():
        """Minimal TTS no-op processor when EdgeTTS pipecat service unavailable."""
        class PassthroughTTS(FrameProcessor):  # type: ignore[misc]
            async def process_frame(self, frame, direction):
                await super().process_frame(frame, direction)
                await self.push_frame(frame, direction)
        return PassthroughTTS()

    # -----------------------------------------------------------------------
    # WebSocket endpoint (pipecat path)
    # -----------------------------------------------------------------------

    @app.websocket("/ws")
    async def websocket_endpoint_pipecat(websocket: WebSocket):
        await websocket.accept()
        client = websocket.client
        logger.info(f"🔌 Client connected: {client}")
        try:
            await _run_pipecat_pipeline(websocket)
        except WebSocketDisconnect:
            logger.info(f"🔌 Client disconnected: {client}")
        except Exception as exc:
            logger.error(f"Pipeline exception: {exc}\n{traceback.format_exc()}")
            try:
                await websocket.close(code=1011)
            except Exception:
                pass


# ===========================================================================
# FALLBACK PIPELINE  (webrtcvad + faster-whisper + openai + edge-tts)
# ===========================================================================

else:

    import io
    import struct
    import wave

    # Try importing fallback STT / TTS
    try:
        import webrtcvad  # type: ignore
        _WEBRTCVAD_OK = True
    except ImportError:
        _WEBRTCVAD_OK = False
        logger.warning("webrtcvad not available – VAD disabled in fallback mode")

    try:
        from faster_whisper import WhisperModel  # type: ignore
        _whisper_model: "WhisperModel | None" = None  # lazy-loaded
        _WHISPER_OK = True
    except ImportError:
        _WHISPER_OK = False
        logger.warning("faster-whisper not available in fallback mode")

    try:
        import edge_tts  # type: ignore
        _EDGETTS_OK = True
    except ImportError:
        _EDGETTS_OK = False
        logger.warning("edge-tts not available in fallback mode")

    from openai import AsyncOpenAI

    _openai_client = AsyncOpenAI(
        api_key=config.OPENAI_API_KEY,
        base_url=config.LLM_BASE_URL,
    )

    # -----------------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------------

    def _get_whisper() -> "WhisperModel":
        global _whisper_model
        if _whisper_model is None:
            logger.info(f"Loading Whisper model '{config.WHISPER_MODEL}' …")
            _whisper_model = WhisperModel(
                config.WHISPER_MODEL,
                device=config.WHISPER_DEVICE,
                compute_type=config.WHISPER_COMPUTE_TYPE,
            )
            logger.info("Whisper model loaded.")
        return _whisper_model

    def _pcm_to_wav_bytes(pcm: bytes, sample_rate: int = 16000) -> bytes:
        buf = io.BytesIO()
        with wave.open(buf, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(pcm)
        return buf.getvalue()

    async def _synthesize(text: str) -> bytes:
        """Synthesize *text* to PCM bytes via edge-tts."""
        if not _EDGETTS_OK:
            return b""
        communicate = edge_tts.Communicate(
            text,
            voice=config.TTS_DEFAULT_VOICE,
            rate=config.TTS_RATE,
            volume=config.TTS_VOLUME,
            pitch=config.TTS_PITCH,
        )
        mp3_buf = io.BytesIO()
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                mp3_buf.write(chunk["data"])

        # Convert MP3 → raw PCM via ffmpeg (if available) or return mp3
        mp3_bytes = mp3_buf.getvalue()
        if not mp3_bytes:
            return b""
        try:
            proc = await asyncio.create_subprocess_exec(
                "ffmpeg", "-i", "pipe:0",
                "-f", "s16le", "-ar", str(config.AUDIO_SAMPLE_RATE),
                "-ac", "1", "pipe:1",
                "-loglevel", "quiet",
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            pcm_bytes, _ = await proc.communicate(input=mp3_bytes)
            return pcm_bytes
        except FileNotFoundError:
            # ffmpeg not available; return mp3 bytes directly
            return mp3_bytes

    class _ConversationSession:
        """Holds per-connection state: history, VAD buffer, etc."""

        def __init__(self):
            self.history: list[dict] = [
                {"role": "system", "content": config.SYSTEM_PROMPT}
            ]
            self.audio_buffer = bytearray()
            self.speaking = False
            self.silence_frames = 0
            self.vad = webrtcvad.Vad(2) if _WEBRTCVAD_OK else None

        def feed_audio(self, chunk: bytes) -> bytes | None:
            """
            Buffer audio; return accumulated speech PCM when utterance ends.
            Uses webrtcvad if available, otherwise uses a simple energy threshold.
            Returns None while still capturing, returns bytes when speech ends.
            """
            # webrtcvad expects 10 / 20 / 30 ms frames at 8/16/32kHz
            frame_ms = 30
            frame_bytes = int(config.AUDIO_SAMPLE_RATE * frame_ms / 1000) * 2  # 16-bit

            self.audio_buffer.extend(chunk)

            while len(self.audio_buffer) >= frame_bytes:
                frame = bytes(self.audio_buffer[:frame_bytes])
                self.audio_buffer = self.audio_buffer[frame_bytes:]

                if self.vad:
                    try:
                        is_speech = self.vad.is_speech(frame, config.AUDIO_SAMPLE_RATE)
                    except Exception:
                        is_speech = False
                else:
                    # Energy-based fallback
                    samples = struct.unpack(f"{len(frame)//2}h", frame)
                    rms = (sum(s * s for s in samples) / len(samples)) ** 0.5
                    is_speech = rms > 500

                if is_speech:
                    self.speaking = True
                    self.silence_frames = 0
                    if not hasattr(self, "_speech_buf"):
                        self._speech_buf = bytearray()
                    self._speech_buf.extend(frame)
                else:
                    if self.speaking:
                        self.silence_frames += 1
                        if hasattr(self, "_speech_buf"):
                            self._speech_buf.extend(frame)
                        # ~0.8s of silence → end of utterance
                        if self.silence_frames > int(1000 / frame_ms * config.VAD_STOP_SECS):
                            speech = bytes(getattr(self, "_speech_buf", b""))
                            self._speech_buf = bytearray()
                            self.speaking = False
                            self.silence_frames = 0
                            if len(speech) > frame_bytes * 3:
                                return speech
            return None

    async def _process_utterance(
        session: _ConversationSession,
        pcm: bytes,
        websocket: WebSocket,
    ) -> None:
        """STT → LLM (with tools) → TTS → send back."""
        # -- STT ------------------------------------------------------------
        if _WHISPER_OK:
            wav_bytes = _pcm_to_wav_bytes(pcm)
            wav_buf = io.BytesIO(wav_bytes)
            model = _get_whisper()
            segments, info = model.transcribe(
                wav_buf,
                language=config.WHISPER_LANGUAGE or None,
                beam_size=5,
            )
            transcript = " ".join(s.text for s in segments).strip()
        else:
            # No STT available
            await websocket.send_json({"type": "error", "text": "STT not available"})
            return

        if not transcript:
            return

        logger.info(f"📝 Transcript: {transcript}")
        await websocket.send_json({"type": "transcript", "text": transcript})

        # -- LLM (with tool loop) ------------------------------------------
        session.history.append({"role": "user", "content": transcript})

        max_tool_rounds = 5
        for _ in range(max_tool_rounds):
            response = await _openai_client.chat.completions.create(
                model=config.LLM_MODEL,
                messages=session.history,
                tools=tool_module.TOOLS_SCHEMA,
                tool_choice="auto",
                temperature=config.LLM_TEMPERATURE,
                max_tokens=config.LLM_MAX_TOKENS,
            )
            msg = response.choices[0].message

            if msg.tool_calls:
                # Execute tool calls
                session.history.append(msg.model_dump(exclude_none=True))
                for tc in msg.tool_calls:
                    fn_name = tc.function.name
                    try:
                        args = json.loads(tc.function.arguments)
                    except json.JSONDecodeError:
                        args = {}
                    logger.info(f"🔧 Tool: {fn_name}({args})")
                    result = await tool_module.dispatch_tool(fn_name, args)
                    logger.info(f"🔧 Result: {result[:100]}")
                    session.history.append({
                        "role": "tool",
                        "tool_call_id": tc.id,
                        "content": result,
                    })
                # Continue loop to get final answer
                continue

            # Normal text response
            reply_text = msg.content or ""
            session.history.append({"role": "assistant", "content": reply_text})
            logger.info(f"🤖 Reply: {reply_text[:120]}")

            await websocket.send_json({"type": "assistant", "text": reply_text})

            # -- TTS --------------------------------------------------------
            if reply_text and _EDGETTS_OK:
                audio_bytes = await _synthesize(reply_text)
                if audio_bytes:
                    # Send audio in chunks to avoid large frames
                    chunk_size = 32768
                    for i in range(0, len(audio_bytes), chunk_size):
                        await websocket.send_bytes(audio_bytes[i: i + chunk_size])
                    # Signal end of audio
                    await websocket.send_json({"type": "audio_end"})
            break

    # -----------------------------------------------------------------------
    # WebSocket endpoint (fallback path)
    # -----------------------------------------------------------------------

    @app.websocket("/ws")
    async def websocket_endpoint_fallback(websocket: WebSocket):
        await websocket.accept()
        client = websocket.client
        logger.info(f"🔌 [fallback] Client connected: {client}")
        session = _ConversationSession()

        # Optionally pre-load Whisper
        if _WHISPER_OK:
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(None, _get_whisper)

        try:
            while True:
                try:
                    data = await asyncio.wait_for(websocket.receive(), timeout=120.0)
                except asyncio.TimeoutError:
                    await websocket.send_json({"type": "ping"})
                    continue

                if data["type"] == "websocket.disconnect":
                    break

                if data.get("bytes"):
                    raw_pcm = data["bytes"]
                    completed_utterance = session.feed_audio(raw_pcm)
                    if completed_utterance:
                        asyncio.create_task(
                            _process_utterance(session, completed_utterance, websocket)
                        )

                elif data.get("text"):
                    # Control messages (JSON)
                    try:
                        msg = json.loads(data["text"])
                    except json.JSONDecodeError:
                        continue
                    if msg.get("type") == "ping":
                        await websocket.send_json({"type": "pong"})
                    elif msg.get("type") == "reset":
                        session = _ConversationSession()
                        await websocket.send_json({"type": "reset_ok"})

        except WebSocketDisconnect:
            logger.info(f"🔌 Client disconnected: {client}")
        except Exception as exc:
            logger.error(f"WebSocket error: {exc}\n{traceback.format_exc()}")
            try:
                await websocket.close(code=1011)
            except Exception:
                pass


# ---------------------------------------------------------------------------
# Default frontend HTML (served when frontend/ directory is empty)
# ---------------------------------------------------------------------------

_DEFAULT_INDEX_HTML = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>nio 语音助手</title>
<style>
  :root { --bg: #0f0f13; --fg: #e8e8f0; --accent: #6c8eff; --panel: #1a1a24; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--fg); font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
         display: flex; flex-direction: column; align-items: center; min-height: 100vh; padding: 2rem; }
  h1 { font-size: 2rem; margin-bottom: 0.25rem; }
  .subtitle { opacity: 0.5; margin-bottom: 2rem; font-size: 0.9rem; }
  #chat { width: 100%; max-width: 640px; flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 0.75rem;
          margin-bottom: 1rem; max-height: 55vh; padding: 1rem; background: var(--panel); border-radius: 12px; }
  .msg { padding: 0.6rem 1rem; border-radius: 10px; max-width: 85%; font-size: 0.95rem; line-height: 1.5; }
  .msg.user { background: var(--accent); align-self: flex-end; }
  .msg.assistant { background: #2a2a38; align-self: flex-start; }
  .msg.system { background: transparent; color: #888; font-size: 0.8rem; align-self: center; font-style: italic; }
  #controls { display: flex; gap: 1rem; align-items: center; }
  #recordBtn { width: 72px; height: 72px; border-radius: 50%; border: none; cursor: pointer;
               font-size: 2rem; transition: all 0.2s; background: var(--accent); color: white; }
  #recordBtn.recording { background: #ff4f6a; animation: pulse 1s infinite; }
  @keyframes pulse { 0%,100%{box-shadow:0 0 0 0 rgba(255,79,106,.6)} 50%{box-shadow:0 0 0 14px rgba(255,79,106,0)} }
  #status { font-size: 0.85rem; opacity: 0.6; }
  .waveform { width: 100%; max-width: 640px; height: 48px; background: var(--panel); border-radius: 8px;
              margin-bottom: 1rem; display: flex; align-items: center; justify-content: center; gap: 3px; }
  .bar { width: 4px; background: var(--accent); border-radius: 2px; transition: height 0.05s; }
</style>
</head>
<body>
<h1>🎙️ nio 语音助手</h1>
<p class="subtitle">按住麦克风按钮说话，松开发送</p>

<div class="waveform" id="waveform">
  <!-- bars injected by JS -->
</div>

<div id="chat"><div class="msg system">连接中…</div></div>

<div id="controls">
  <button id="recordBtn" title="按住说话">🎙️</button>
  <span id="status">未连接</span>
</div>

<script>
(async () => {
  // -- WebSocket --
  const proto = location.protocol === 'https:' ? 'wss' : 'ws';
  const wsUrl = `${proto}://${location.host}/ws`;
  let ws, mediaRecorder, audioCtx, analyser, source;
  let chunks = [];
  let animFrame;
  const chat = document.getElementById('chat');
  const btn = document.getElementById('recordBtn');
  const statusEl = document.getElementById('status');
  const waveform = document.getElementById('waveform');

  // Draw waveform bars
  const N = 32;
  for (let i = 0; i < N; i++) {
    const b = document.createElement('div');
    b.className = 'bar';
    b.style.height = '4px';
    waveform.appendChild(b);
  }
  const bars = waveform.querySelectorAll('.bar');

  function addMessage(role, text) {
    const div = document.createElement('div');
    div.className = `msg ${role}`;
    div.textContent = text;
    chat.appendChild(div);
    chat.scrollTop = chat.scrollHeight;
  }

  function connect() {
    ws = new WebSocket(wsUrl);
    ws.binaryType = 'arraybuffer';

    ws.onopen = () => { statusEl.textContent = '已连接'; addMessage('system', '已连接到 nio 语音助手'); };
    ws.onclose = () => { statusEl.textContent = '已断开，3秒后重连…'; setTimeout(connect, 3000); };
    ws.onerror = (e) => console.error('ws error', e);

    ws.onmessage = async (evt) => {
      if (evt.data instanceof ArrayBuffer) {
        // Audio bytes – play via Web Audio
        playAudio(evt.data);
      } else {
        let msg;
        try { msg = JSON.parse(evt.data); } catch { return; }
        if (msg.type === 'transcript') addMessage('user', msg.text);
        else if (msg.type === 'assistant') addMessage('assistant', msg.text);
        else if (msg.type === 'error') addMessage('system', '⚠ ' + msg.text);
        else if (msg.type === 'ping') ws.send(JSON.stringify({type:'pong'}));
      }
    };
  }

  let audioQueue = [];
  let isPlaying = false;
  const AC = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 16000 });

  async function playAudio(arrayBuf) {
    audioQueue.push(arrayBuf);
    if (!isPlaying) drainQueue();
  }

  async function drainQueue() {
    if (!audioQueue.length) { isPlaying = false; return; }
    isPlaying = true;
    const buf = audioQueue.shift();
    try {
      const decoded = await AC.decodeAudioData(buf.slice(0));
      const src = AC.createBufferSource();
      src.buffer = decoded;
      src.connect(AC.destination);
      src.onended = drainQueue;
      src.start();
    } catch { drainQueue(); }
  }

  // -- Microphone --
  async function startRecording() {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: { sampleRate: 16000, channelCount: 1 } });
    audioCtx = new AudioContext({ sampleRate: 16000 });
    analyser = audioCtx.createAnalyser();
    analyser.fftSize = 128;
    source = audioCtx.createMediaStreamSource(stream);
    source.connect(analyser);

    mediaRecorder = new MediaRecorder(stream, { mimeType: 'audio/webm;codecs=opus' });
    chunks = [];
    mediaRecorder.ondataavailable = e => { if (e.data.size > 0 && ws?.readyState === WebSocket.OPEN) {
      e.data.arrayBuffer().then(buf => ws.send(buf));
    }};
    mediaRecorder.start(100); // 100ms slices

    // Waveform animation
    const data = new Uint8Array(analyser.frequencyBinCount);
    function draw() {
      analyser.getByteFrequencyData(data);
      bars.forEach((b, i) => {
        const v = data[Math.floor(i * data.length / N)] / 255;
        b.style.height = `${4 + v * 40}px`;
      });
      animFrame = requestAnimationFrame(draw);
    }
    draw();
  }

  function stopRecording() {
    if (mediaRecorder && mediaRecorder.state !== 'inactive') mediaRecorder.stop();
    if (animFrame) cancelAnimationFrame(animFrame);
    bars.forEach(b => b.style.height = '4px');
    if (audioCtx) { audioCtx.close(); audioCtx = null; }
  }

  btn.addEventListener('mousedown', async () => {
    btn.classList.add('recording');
    btn.textContent = '🔴';
    await startRecording();
  });
  btn.addEventListener('mouseup', () => {
    btn.classList.remove('recording');
    btn.textContent = '🎙️';
    stopRecording();
  });
  // Touch support
  btn.addEventListener('touchstart', async (e) => { e.preventDefault(); btn.dispatchEvent(new MouseEvent('mousedown')); });
  btn.addEventListener('touchend', (e) => { e.preventDefault(); btn.dispatchEvent(new MouseEvent('mouseup')); });

  connect();
})();
</script>
</body>
</html>
"""

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    logger.info(f"🎙️  nio Voice Assistant starting on {config.SERVER_HOST}:{config.SERVER_PORT}")
    logger.info(f"   LLM: {config.LLM_BASE_URL} / {config.LLM_MODEL}")
    logger.info(f"   STT: {config.STT_PROVIDER}  TTS: {config.TTS_DEFAULT_VOICE}")
    logger.info(f"   Pipeline: {'pipecat' if _PIPECAT_AVAILABLE else 'fallback (webrtcvad+whisper+edge-tts)'}")

    uvicorn.run(
        "server:app",
        host=config.SERVER_HOST,
        port=config.SERVER_PORT,
        log_level=config.SERVER_LOG_LEVEL,
        reload=False,
    )


if __name__ == "__main__":
    main()
