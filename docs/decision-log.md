# Decision Log

## 2026-09-27 — Motor primario: Next.js + R3F (council técnico)

- Elegido: Next.js static export + Three.js/R3F + Rapier-compat + zustand.
- Motivo: único coste 0 + Vercel Hobby + techo WebGPU más alto.
- Descartado: Unreal (sin export web, requiere GPU server), Godot web (solo WebGL2, techo bajo),
  Unity WebGL (pesado 10-30MB, OOM iOS).
- Alternativo: Babylon.js 9 si se necesita Havok/NavMesh/Inspector día 1.
- Firma: pendiente boot + benchmark Fase 00.
