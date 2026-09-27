// Audio procedural WebAudio sin assets.

export type SoundName = 'build'|'coin'|'hit'|'alarm'|'win'|'click';

let ctx: AudioContext | null = null;
let ambientGain: GainNode | null = null;
const lastPlay: Partial<Record<SoundName, number>> = {};

// Ganancia baja para el ambiente.
const AMBIENT_GAIN = 0.025;

// Lee mute persistido (default false).
export function isMuted(): boolean {
  try {
    if (typeof window === "undefined") return false;
    return window.localStorage.getItem("es-muted") === "1";
  } catch {
    return false;
  }
}

// Persiste mute y detiene/reanuda ambiente.
export function setMuted(m: boolean): void {
  try {
    if (typeof window !== "undefined") window.localStorage.setItem("es-muted", m ? "1" : "0");
  } catch {
    // sin almacenamiento: sigue en memoria
  }
  if (ctx && ambientGain) {
    const t = ctx.currentTime;
    ambientGain.gain.setTargetAtTime(m ? 0 : AMBIENT_GAIN, t, 0.05);
    if (!m && ctx.state === "suspended") void ctx.resume();
  }
}

// Crea AudioContext + ambiente (ruido filtrado en loop). Seguro si se repite.
// Solo llamar desde un gesto de usuario.
export function ensureAudio(): void {
  if (typeof window === "undefined") return;
  if (ctx) {
    if (ctx.state === "suspended" && !isMuted()) void ctx.resume();
    return;
  }
  try {
    const AC =
      window.AudioContext ??
      (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!AC) return;
    ctx = new AC();
    // Ruido blanco en loop -> filtro paso-bajo -> ganancia baja.
    const len = 2 * ctx.sampleRate;
    const buf = ctx.createBuffer(1, len, ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
    const src = ctx.createBufferSource();
    src.buffer = buf;
    src.loop = true;
    const filt = ctx.createBiquadFilter();
    filt.type = "lowpass";
    filt.frequency.value = 400;
    ambientGain = ctx.createGain();
    ambientGain.gain.value = isMuted() ? 0 : AMBIENT_GAIN;
    src.connect(filt);
    filt.connect(ambientGain);
    ambientGain.connect(ctx.destination);
    src.start();
  } catch {
    ctx = null;
    ambientGain = null;
  }
}

// Tono corto con envolvente.
function tone(f0: number, f1: number, dur: number, type: OscillatorType, vol: number, delay = 0): void {
  if (!ctx) return;
  const t = ctx.currentTime + delay;
  const o = ctx.createOscillator();
  const g = ctx.createGain();
  o.type = type;
  o.frequency.setValueAtTime(Math.max(1, f0), t);
  if (f1 !== f0) o.frequency.exponentialRampToValueAtTime(Math.max(1, f1), t + dur);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + 0.01);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g);
  g.connect(ctx.destination);
  o.start(t);
  o.stop(t + dur + 0.05);
}

// Osciladores cortos por sonido; throttle 150ms en coin/hit; nada si muted/sin ctx.
export function playSound(name: SoundName): void {
  if (isMuted()) return;
  if (!ctx) return;
  if (ctx.state === "suspended") void ctx.resume();
  const now = Date.now();
  if ((name === "coin" || name === "hit") && now - (lastPlay[name] ?? 0) < 150) return;
  lastPlay[name] = now;
  switch (name) {
    case "build":
      tone(200, 400, 0.2, "triangle", 0.15);
      break;
    case "coin":
      tone(988, 988, 0.07, "square", 0.08);
      tone(1319, 1319, 0.12, "square", 0.08, 0.07);
      break;
    case "hit":
      tone(150, 60, 0.15, "sawtooth", 0.2);
      break;
    case "alarm":
      tone(600, 600, 0.12, "sawtooth", 0.12);
      tone(450, 450, 0.12, "sawtooth", 0.12, 0.14);
      break;
    case "win":
      tone(523, 523, 0.15, "triangle", 0.12, 0);
      tone(659, 659, 0.15, "triangle", 0.12, 0.12);
      tone(784, 784, 0.15, "triangle", 0.12, 0.24);
      tone(1046, 1046, 0.25, "triangle", 0.12, 0.36);
      break;
    case "click":
      tone(800, 600, 0.05, "square", 0.06);
      break;
  }
}
