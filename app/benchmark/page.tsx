"use client";

import { useEffect, useState } from "react";
import WorldCanvas from "@/components/WorldCanvas";

export default function BenchmarkPage() {
  const [fps, setFps] = useState(0);
  const [frames, setFrames] = useState(0);

  useEffect(() => {
    let raf = 0;
    let last = performance.now();
    let count = 0;
    const loop = (t: number) => {
      count += 1;
      if (t - last >= 1000) {
        setFps(Math.round((count * 1000) / (t - last)));
        setFrames((f) => f + count);
        count = 0;
        last = t;
      }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, []);

  return (
    <div className="flex min-h-screen flex-col bg-black text-white">
      <header className="flex items-center justify-between px-6 py-4">
        <h1 className="text-lg font-semibold">Benchmark 00 — escena vacía</h1>
        <div className="text-sm">
          FPS: <strong>{fps}</strong> · frames: {frames} · Target HIGH ≥120 / LOW ≥60
        </div>
      </header>
      <main className="mx-6 mb-6 min-h-[70vh] flex-1 overflow-hidden rounded-xl border border-white/10">
        <WorldCanvas />
      </main>
      <p className="px-6 pb-6 text-xs text-zinc-400">
        Registra 3 corridas en benchmarks/00.md con draw/tris/VRAM. Desviación &lt;5%.
      </p>
    </div>
  );
}
