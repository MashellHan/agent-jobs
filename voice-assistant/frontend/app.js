/* ═══════════════════════════════════════════════════════════════
   nio Voice Assistant – app.js
   WebSocket streaming voice client with PCM audio capture,
   canvas visualizer, and full state management.
   ═══════════════════════════════════════════════════════════════ */
(function () {
  'use strict';

  /* ─── Constants ──────────────────────────────────────────────── */
  const SAMPLE_RATE       = 16000;
  const CHUNK_INTERVAL_MS = 100;          // send a PCM frame every 100 ms
  const CHUNK_SAMPLES     = SAMPLE_RATE * CHUNK_INTERVAL_MS / 1000; // 1600 samples
  const WS_PORT           = 8891;

  /* ─── State ──────────────────────────────────────────────────── */
  const state = {
    ws:              null,
    reconnectTimer:  null,
    reconnectDelay:  1000,
    maxDelay:        30000,

    audioCtx:        null,   // AudioContext (created on first user gesture)
    micStream:       null,   // MediaStream
    micSource:       null,   // MediaStreamAudioSourceNode
    scriptProcessor: null,   // ScriptProcessorNode (fallback) or null
    workletNode:     null,   // AudioWorkletNode (preferred) or null
    analyser:        null,   // AnalyserNode for visualizer

    // Playback
    playbackQueue:   [],     // Array of AudioBuffer
    isPlayingBack:   false,
    playbackSource:  null,   // Currently playing AudioBufferSourceNode

    // App state machine
    appState: 'idle',        // idle | connecting | listening | thinking | speaking

    // Accumulated PCM input buffer for worklet fallback
    pcmBuffer:       new Float32Array(CHUNK_SAMPLES),
    pcmBufferPos:    0,

    // Visualizer animation
    animFrame:       null,
    vizBars:         new Float32Array(20).fill(0),
  };

  /* ─── DOM refs ───────────────────────────────────────────────── */
  const micBtn         = document.getElementById('mic-btn');
  const chatArea       = document.getElementById('chat-area');
  const statusPill     = document.getElementById('status-pill');
  const statusText     = document.getElementById('status-text');
  const connectionChip = document.getElementById('connection-chip');
  const connectionLabel= document.getElementById('connection-label');
  const toast          = document.getElementById('toast');
  const hintText       = document.getElementById('hint-text');
  const canvas         = document.getElementById('visualizer');
  const ctx2d          = canvas.getContext('2d');
  const iconMic        = document.getElementById('icon-mic');
  const iconStop       = document.getElementById('icon-stop');
  const iconSpeaker    = document.getElementById('icon-speaker');

  /* ═══════════════════════════════════════════════════════════════
     WebSocket
  ═══════════════════════════════════════════════════════════════ */
  function connect() {
    if (state.ws &&
        (state.ws.readyState === WebSocket.OPEN ||
         state.ws.readyState === WebSocket.CONNECTING)) return;

    const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
    const url   = `${proto}//${location.hostname}:${WS_PORT}/ws`;

    setAppState('connecting');
    setConnectionState('connecting');

    try {
      state.ws = new WebSocket(url);
    } catch (e) {
      scheduleReconnect();
      return;
    }

    state.ws.binaryType = 'arraybuffer';

    state.ws.onopen = () => {
      state.reconnectDelay = 1000;
      setConnectionState('connected');
      setAppState('idle');
      clearTimeout(state.reconnectTimer);
      state.reconnectTimer = null;
    };

    state.ws.onclose = () => {
      setConnectionState('disconnected');
      stopCapture();
      if (state.appState !== 'idle') setAppState('idle');
      scheduleReconnect();
    };

    state.ws.onerror = () => {
      setConnectionState('disconnected');
    };

    state.ws.onmessage = handleServerMessage;
  }

  function scheduleReconnect() {
    if (state.reconnectTimer) return;
    state.reconnectTimer = setTimeout(() => {
      state.reconnectTimer = null;
      connect();
    }, state.reconnectDelay);
    // Exponential backoff
    state.reconnectDelay = Math.min(state.reconnectDelay * 2, state.maxDelay);
  }

  /* ─── Server message handler ─────────────────────────────────── */
  function handleServerMessage(event) {
    // Binary frames → PCM audio to play back
    if (event.data instanceof ArrayBuffer) {
      enqueuePCMPlayback(event.data);
      return;
    }

    let msg;
    try { msg = JSON.parse(event.data); } catch { return; }

    switch (msg.type) {
      case 'transcript':
        // User speech recognized
        if (msg.text) addMessage('user', msg.text);
        setAppState('thinking');
        break;

      case 'assistant':
        // Assistant text response
        if (msg.text) addMessage('assistant', msg.text);
        break;

      case 'audio':
        // Base64-encoded PCM or WAV chunk
        if (msg.data) {
          const binary = base64ToArrayBuffer(msg.data);
          enqueuePCMPlayback(binary, msg.encoding || 'pcm');
        }
        break;

      case 'audio_end':
        // Server finished sending audio; we'll transition to idle after queue drains
        state.playbackQueue._endPending = true;
        if (!state.isPlayingBack) {
          setAppState('idle');
        }
        break;

      case 'status':
        // Server-side status update (e.g., VAD detected silence)
        if (msg.state) handleServerState(msg.state);
        break;

      case 'vad_speech_start':
        // Server detected user started speaking → interrupt playback
        interruptPlayback();
        break;

      case 'error':
        showToast(msg.message || msg.text || '服务器错误');
        setAppState('idle');
        break;

      default:
        // Unknown message type – ignore
        break;
    }
  }

  function handleServerState(serverState) {
    // Map server state strings to local states
    const map = {
      listening: 'listening',
      thinking:  'thinking',
      speaking:  'speaking',
      idle:      'idle',
    };
    const mapped = map[serverState];
    if (mapped) setAppState(mapped);
  }

  /* ═══════════════════════════════════════════════════════════════
     AudioContext – created lazily on first user gesture (iOS)
  ═══════════════════════════════════════════════════════════════ */
  function ensureAudioContext() {
    if (state.audioCtx && state.audioCtx.state !== 'closed') {
      if (state.audioCtx.state === 'suspended') {
        state.audioCtx.resume().catch(() => {});
      }
      return state.audioCtx;
    }
    // Safari requires webkitAudioContext
    const AC = window.AudioContext || window.webkitAudioContext;
    state.audioCtx = new AC({ sampleRate: SAMPLE_RATE });
    return state.audioCtx;
  }

  /* ═══════════════════════════════════════════════════════════════
     Microphone capture
  ═══════════════════════════════════════════════════════════════ */
  async function startCapture() {
    if (!state.ws || state.ws.readyState !== WebSocket.OPEN) {
      showToast('未连接到服务器，请稍候');
      return false;
    }

    const audioCtx = ensureAudioContext();

    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          sampleRate:   SAMPLE_RATE,
          channelCount: 1,
          echoCancellation:    true,
          noiseSuppression:    true,
          autoGainControl:     true,
        },
        video: false,
      });
    } catch (err) {
      if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
        showToast('麦克风权限被拒绝，请在设置中允许访问麦克风');
      } else if (err.name === 'NotFoundError') {
        showToast('未找到麦克风设备');
      } else {
        showToast('无法访问麦克风: ' + (err.message || err.name));
      }
      return false;
    }

    state.micStream = stream;
    state.micSource = audioCtx.createMediaStreamSource(stream);

    // Analyser for visualizer
    state.analyser = audioCtx.createAnalyser();
    state.analyser.fftSize = 256;
    state.analyser.smoothingTimeConstant = 0.8;
    state.micSource.connect(state.analyser);

    // Try AudioWorklet first, fall back to ScriptProcessor
    const useWorklet = !!(audioCtx.audioWorklet);
    if (useWorklet) {
      await startWorkletCapture(audioCtx);
    } else {
      startScriptProcessorCapture(audioCtx);
    }

    return true;
  }

  // ── AudioWorklet path ──────────────────────────────────────────
  const WORKLET_CODE = `
class PCMCapture extends AudioWorkletProcessor {
  constructor() {
    super();
    this._buf = new Float32Array(${CHUNK_SAMPLES});
    this._pos = 0;
  }
  process(inputs) {
    const input = inputs[0];
    if (!input || !input[0]) return true;
    const channel = input[0];
    for (let i = 0; i < channel.length; i++) {
      this._buf[this._pos++] = channel[i];
      if (this._pos >= ${CHUNK_SAMPLES}) {
        this.port.postMessage(this._buf.slice(0));
        this._pos = 0;
      }
    }
    return true;
  }
}
registerProcessor('pcm-capture', PCMCapture);
`;

  async function startWorkletCapture(audioCtx) {
    try {
      const blob = new Blob([WORKLET_CODE], { type: 'application/javascript' });
      const url  = URL.createObjectURL(blob);
      await audioCtx.audioWorklet.addModule(url);
      URL.revokeObjectURL(url);

      state.workletNode = new AudioWorkletNode(audioCtx, 'pcm-capture');
      state.workletNode.port.onmessage = (e) => {
        sendPCMChunk(e.data);
      };
      state.micSource.connect(state.workletNode);
      state.workletNode.connect(audioCtx.destination); // needed on some browsers
    } catch (e) {
      // Worklet failed – fall back to ScriptProcessor
      console.warn('[nio] AudioWorklet failed, falling back to ScriptProcessor', e);
      startScriptProcessorCapture(audioCtx);
    }
  }

  // ── ScriptProcessor fallback (Safari ≤ 16) ────────────────────
  function startScriptProcessorCapture(audioCtx) {
    // bufferSize must be power-of-2; pick 4096 (≈ 256ms at 16kHz)
    const bufSize = 4096;
    state.scriptProcessor = audioCtx.createScriptProcessor(bufSize, 1, 1);
    state.scriptProcessor.onaudioprocess = (e) => {
      const inputData = e.inputBuffer.getChannelData(0);
      // Accumulate into our chunk buffer
      for (let i = 0; i < inputData.length; i++) {
        state.pcmBuffer[state.pcmBufferPos++] = inputData[i];
        if (state.pcmBufferPos >= CHUNK_SAMPLES) {
          sendPCMChunk(state.pcmBuffer);
          state.pcmBufferPos = 0;
        }
      }
    };
    state.micSource.connect(state.scriptProcessor);
    state.scriptProcessor.connect(audioCtx.destination);
  }

  // ── Convert Float32 → Int16 PCM and send ──────────────────────
  function sendPCMChunk(float32Array) {
    if (!state.ws || state.ws.readyState !== WebSocket.OPEN) return;

    const int16 = new Int16Array(float32Array.length);
    for (let i = 0; i < float32Array.length; i++) {
      const s = Math.max(-1, Math.min(1, float32Array[i]));
      int16[i] = s < 0 ? s * 0x8000 : s * 0x7FFF;
    }
    state.ws.send(int16.buffer);
  }

  function stopCapture() {
    if (state.workletNode) {
      try { state.workletNode.disconnect(); } catch {}
      state.workletNode = null;
    }
    if (state.scriptProcessor) {
      try { state.scriptProcessor.disconnect(); } catch {}
      state.scriptProcessor = null;
    }
    if (state.micSource) {
      try { state.micSource.disconnect(); } catch {}
      state.micSource = null;
    }
    if (state.micStream) {
      state.micStream.getTracks().forEach(t => t.stop());
      state.micStream = null;
    }
    if (state.analyser) {
      try { state.analyser.disconnect(); } catch {}
      state.analyser = null;
    }
    state.pcmBufferPos = 0;
  }

  /* ═══════════════════════════════════════════════════════════════
     Audio Playback  (raw PCM or WAV chunks from server)
  ═══════════════════════════════════════════════════════════════ */
  function enqueuePCMPlayback(arrayBuffer, encoding) {
    // encoding: 'pcm' (raw s16le 16kHz mono) | 'wav' | undefined (auto-detect)
    setAppState('speaking');

    const audioCtx = ensureAudioContext();

    if (encoding === 'wav' || isWAV(arrayBuffer)) {
      // Decode via Web Audio API
      audioCtx.decodeAudioData(
        arrayBuffer.slice(0),
        (audioBuffer) => {
          state.playbackQueue.push(audioBuffer);
          if (!state.isPlayingBack) playNextInQueue();
        },
        (err) => { console.warn('[nio] decodeAudioData error', err); }
      );
    } else {
      // Treat as raw 16-bit LE PCM @ 16kHz mono
      const int16 = new Int16Array(arrayBuffer);
      const float32 = new Float32Array(int16.length);
      for (let i = 0; i < int16.length; i++) {
        float32[i] = int16[i] / (int16[i] < 0 ? 0x8000 : 0x7FFF);
      }
      const audioBuffer = audioCtx.createBuffer(1, float32.length, SAMPLE_RATE);
      audioBuffer.copyToChannel(float32, 0);
      state.playbackQueue.push(audioBuffer);
      if (!state.isPlayingBack) playNextInQueue();
    }
  }

  function isWAV(arrayBuffer) {
    if (arrayBuffer.byteLength < 4) return false;
    const bytes = new Uint8Array(arrayBuffer, 0, 4);
    // RIFF header
    return bytes[0] === 0x52 && bytes[1] === 0x49 &&
           bytes[2] === 0x46 && bytes[3] === 0x46;
  }

  function playNextInQueue() {
    if (state.playbackQueue.length === 0) {
      state.isPlayingBack = false;
      state.playbackSource = null;
      if (state.playbackQueue._endPending) {
        state.playbackQueue._endPending = false;
        setAppState('idle');
      }
      return;
    }

    state.isPlayingBack = true;
    const audioBuffer = state.playbackQueue.shift();
    const audioCtx = ensureAudioContext();

    const source = audioCtx.createBufferSource();
    source.buffer = audioBuffer;
    source.connect(audioCtx.destination);
    state.playbackSource = source;

    source.onended = () => {
      if (state.playbackSource === source) {
        state.playbackSource = null;
      }
      playNextInQueue();
    };

    source.start(0);
  }

  function interruptPlayback() {
    // Stop currently playing source
    if (state.playbackSource) {
      try { state.playbackSource.stop(0); } catch {}
      state.playbackSource = null;
    }
    state.playbackQueue.length = 0;
    state.playbackQueue._endPending = false;
    state.isPlayingBack = false;
  }

  /* ─── Base64 helper ──────────────────────────────────────────── */
  function base64ToArrayBuffer(b64) {
    const binary = atob(b64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes.buffer;
  }

  /* ═══════════════════════════════════════════════════════════════
     Mic Button interaction
  ═══════════════════════════════════════════════════════════════ */
  let isMicActive = false;

  async function onMicPress() {
    if (state.appState === 'connecting') return;
    if (state.appState === 'thinking') return;

    if (state.appState === 'speaking') {
      // Interrupt assistant speech
      interruptPlayback();
      setAppState('idle');
      return;
    }

    if (state.appState === 'listening') {
      // Stop listening
      stopListening();
      return;
    }

    // Start listening
    isMicActive = true;
    const ok = await startCapture();
    if (ok) {
      setAppState('listening');
      // Notify server we're starting
      sendJSON({ type: 'start_listen' });
    } else {
      isMicActive = false;
    }
  }

  function stopListening() {
    if (!isMicActive) return;
    isMicActive = false;
    // Notify server we stopped
    sendJSON({ type: 'stop_listen' });
    stopCapture();
    setAppState('thinking');
  }

  function sendJSON(obj) {
    if (state.ws && state.ws.readyState === WebSocket.OPEN) {
      state.ws.send(JSON.stringify(obj));
    }
  }

  /* ─── Button events (click + touch for iOS) ──────────────────── */
  micBtn.addEventListener('click', (e) => {
    e.preventDefault();
    onMicPress();
  });

  micBtn.addEventListener('touchstart', (e) => {
    e.preventDefault(); // Prevent double-fire with click
    onMicPress();
  }, { passive: false });

  micBtn.addEventListener('touchend', (e) => {
    e.preventDefault();
  }, { passive: false });

  /* ═══════════════════════════════════════════════════════════════
     App state machine
  ═══════════════════════════════════════════════════════════════ */
  const STATE_CONFIG = {
    idle: {
      pill:  'idle',
      label: '待机中',
      hint:  '点击麦克风开始说话',
      icon:  'mic',
      btnClass: '',
      btnDisabled: false,
      btnAriaPressed: false,
    },
    connecting: {
      pill:  'connecting',
      label: '连接中...',
      hint:  '正在连接服务器',
      icon:  'mic',
      btnClass: 'disabled',
      btnDisabled: true,
      btnAriaPressed: false,
    },
    listening: {
      pill:  'listening',
      label: '聆听中...',
      hint:  '再次点击停止录音',
      icon:  'stop',
      btnClass: 'listening',
      btnDisabled: false,
      btnAriaPressed: true,
    },
    thinking: {
      pill:  'thinking',
      label: '思考中...',
      hint:  '请稍候...',
      icon:  'mic',
      btnClass: 'thinking',
      btnDisabled: true,
      btnAriaPressed: false,
    },
    speaking: {
      pill:  'speaking',
      label: '说话中...',
      hint:  '点击打断',
      icon:  'speaker',
      btnClass: 'speaking',
      btnDisabled: false,
      btnAriaPressed: false,
    },
  };

  function setAppState(newState) {
    if (state.appState === newState) return;
    state.appState = newState;

    const cfg = STATE_CONFIG[newState] || STATE_CONFIG.idle;

    statusPill.className    = cfg.pill;
    statusText.textContent  = cfg.label;
    hintText.textContent    = cfg.hint;
    micBtn.className        = cfg.btnClass;
    micBtn.disabled         = cfg.btnDisabled;
    micBtn.setAttribute('aria-pressed', String(cfg.btnAriaPressed));

    // Switch icon
    iconMic.style.display     = cfg.icon === 'mic'     ? '' : 'none';
    iconStop.style.display    = cfg.icon === 'stop'    ? '' : 'none';
    iconSpeaker.style.display = cfg.icon === 'speaker' ? '' : 'none';
  }

  function setConnectionState(cs) {
    connectionChip.className = cs;
    const labels = { connected: '已连接', connecting: '连接中', disconnected: '已断开' };
    connectionLabel.textContent = labels[cs] || cs;
  }

  /* ═══════════════════════════════════════════════════════════════
     Chat bubbles
  ═══════════════════════════════════════════════════════════════ */
  function addMessage(role, text) {
    if (!text || !text.trim()) return;

    const wrap   = document.createElement('div');
    wrap.className = `bubble-wrap ${role}`;

    const label  = document.createElement('div');
    label.className = 'bubble-label';
    label.textContent = role === 'user' ? '你' : 'nio';

    const bubble = document.createElement('div');
    bubble.className = 'bubble';
    bubble.textContent = text;

    if (role === 'user') {
      wrap.appendChild(bubble);
      wrap.appendChild(label);
    } else {
      wrap.appendChild(label);
      wrap.appendChild(bubble);
    }

    chatArea.appendChild(wrap);
    requestAnimationFrame(() => {
      chatArea.scrollTo({ top: chatArea.scrollHeight, behavior: 'smooth' });
    });
  }

  /* ═══════════════════════════════════════════════════════════════
     Canvas Visualizer
  ═══════════════════════════════════════════════════════════════ */
  const NUM_BARS  = 20;
  const BAR_GAP   = 3;

  function drawVisualizer() {
    state.animFrame = requestAnimationFrame(drawVisualizer);

    const w = canvas.width;
    const h = canvas.height;
    ctx2d.clearRect(0, 0, w, h);

    const isActive = (state.appState === 'listening' || state.appState === 'speaking');

    let levels = new Float32Array(NUM_BARS);

    if (isActive && state.analyser) {
      // Use real mic data when listening
      const freq = new Uint8Array(state.analyser.frequencyBinCount);
      state.analyser.getByteFrequencyData(freq);
      const step = Math.floor(freq.length / NUM_BARS);
      for (let i = 0; i < NUM_BARS; i++) {
        let sum = 0;
        for (let j = 0; j < step; j++) sum += freq[i * step + j];
        levels[i] = (sum / step) / 255;
      }
    } else if (state.appState === 'speaking' || state.appState === 'thinking') {
      // Animated idle wave when speaking (playback) or thinking
      const t = Date.now() / 400;
      for (let i = 0; i < NUM_BARS; i++) {
        levels[i] = (Math.sin(t + i * 0.6) * 0.5 + 0.5) * 0.6 + 0.1;
      }
    }

    // Smooth bars
    for (let i = 0; i < NUM_BARS; i++) {
      state.vizBars[i] += (levels[i] - state.vizBars[i]) * 0.3;
    }

    const barW = (w - BAR_GAP * (NUM_BARS - 1)) / NUM_BARS;
    const centerY = h / 2;

    for (let i = 0; i < NUM_BARS; i++) {
      const level = state.vizBars[i];
      const barH  = Math.max(4, level * (h - 8));
      const x     = i * (barW + BAR_GAP);
      const y     = centerY - barH / 2;

      // Color based on state
      let color;
      if (state.appState === 'listening') {
        color = `rgba(0, 200, 83, ${0.4 + level * 0.6})`;
      } else if (state.appState === 'thinking') {
        color = `rgba(255, 160, 0, ${0.4 + level * 0.6})`;
      } else if (state.appState === 'speaking') {
        color = `rgba(33, 150, 243, ${0.4 + level * 0.6})`;
      } else {
        color = `rgba(108, 99, 255, 0.2)`;
      }

      ctx2d.fillStyle = color;
      ctx2d.beginPath();
      ctx2d.roundRect
        ? ctx2d.roundRect(x, y, barW, barH, barW / 2)
        : ctx2d.rect(x, y, barW, barH);
      ctx2d.fill();
    }
  }

  /* ═══════════════════════════════════════════════════════════════
     Toast
  ═══════════════════════════════════════════════════════════════ */
  let toastTimer = null;
  function showToast(msg, duration = 4000) {
    toast.textContent = msg;
    toast.classList.add('show');
    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(() => {
      toast.classList.remove('show');
    }, duration);
  }

  /* ═══════════════════════════════════════════════════════════════
     Canvas resize
  ═══════════════════════════════════════════════════════════════ */
  function resizeCanvas() {
    const wrap = canvas.parentElement;
    canvas.width = wrap.clientWidth || 280;
    canvas.height = 60;
  }

  window.addEventListener('resize', resizeCanvas);
  resizeCanvas();

  /* ═══════════════════════════════════════════════════════════════
     Page visibility – suspend/resume audio context
  ═══════════════════════════════════════════════════════════════ */
  document.addEventListener('visibilitychange', () => {
    if (!state.audioCtx) return;
    if (document.hidden) {
      state.audioCtx.suspend().catch(() => {});
    } else {
      state.audioCtx.resume().catch(() => {});
    }
  });

  /* ═══════════════════════════════════════════════════════════════
     Init
  ═══════════════════════════════════════════════════════════════ */
  // Warm-up: request mic permission silently so iOS shows prompt early
  if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
    navigator.mediaDevices.getUserMedia({ audio: true, video: false })
      .then(stream => stream.getTracks().forEach(t => t.stop()))
      .catch(() => { /* User can grant later */ });
  }

  drawVisualizer();
  setAppState('idle');
  connect();

})();
