"use client";

import { useEffect, useRef } from "react";
import { BUILDINGS } from "@/lib/economy";
import { useGame } from "@/store/game";

const SIZE = 140;
const HALF = 32;
const SPAN = 64;

function toPx(v: number): number {
  return ((v + HALF) / SPAN) * SIZE;
}

export default function Minimap() {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const draw = () => {
      const canvas = ref.current;
      if (!canvas) return;
      const ctx = canvas.getContext("2d");
      if (!ctx) return;
      const { buildings, settlers } = useGame.getState();

      // Fondo verde oscuro
      ctx.fillStyle = "#14301e";
      ctx.fillRect(0, 0, SIZE, SIZE);

      // Río azul (x > 22)
      const riverX = toPx(22);
      ctx.fillStyle = "#1d4e89";
      ctx.fillRect(riverX, 0, SIZE - riverX, SIZE);

      // Edificios como cuadrados de su color
      for (const b of buildings) {
        ctx.fillStyle = BUILDINGS[b.type].color;
        const px = toPx(b.x);
        const py = toPx(b.z);
        ctx.fillRect(px - 2.5, py - 2.5, 5, 5);
      }

      // Colonos como puntos amarillos
      ctx.fillStyle = "#ffe66d";
      for (const s of settlers) {
        const px = toPx(s.x);
        const py = toPx(s.z);
        ctx.beginPath();
        ctx.arc(px, py, 1.5, 0, Math.PI * 2);
        ctx.fill();
      }

      // Borde blanco
      ctx.strokeStyle = "#ffffff";
      ctx.lineWidth = 2;
      ctx.strokeRect(1, 1, SIZE - 2, SIZE - 2);
    };

    draw();
    const id = window.setInterval(draw, 500);
    return () => window.clearInterval(id);
  }, []);

  return (
    <canvas
      ref={ref}
      width={SIZE}
      height={SIZE}
      className="rounded-md border border-white/20"
      title="Minimapa"
    />
  );
}
