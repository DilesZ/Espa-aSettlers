# Constitution — EspañaSettlers (secuela Settlers web)

Versión: v0.0.1 | Fecha: 2026-09-27 | Estado: propuesto para Fase 00

## Principios innegociables

1. **Calidad Settlers 6 obligatoria, incremental.** No se promete S6 1:1 día 1.
   Se llega por fases 00→04. Prohibido subir a texturas 2048 / GI / volumétricos
   antes de Fase 04. Cada fase debe mantener FPS de la anterior (regresión >10% = bloquea done).

2. **Web-first estático, coste 0.** `Next.js App Router output:'export'`, sin SSR del juego,
   sin servidor autoritativo en Vercel. Juego 100% cliente. Vercel = CDN + thin API.
   Multiplayer v1 = local + semilla/replay. Online v2 = P2P WebRTC o proveedor externo,
   nunca Function persistente.

3. **TypeScript estricto + sim determinista separada de render.**
   Sim tick 10-20 Hz en Web Worker, render 60 fps. Sin esto no hay RTS ni saves ni replays.

4. **Pipeline de assets obligatorio.** `glTF + Draco/Meshopt + KTX2/Basis + WebP`.
   Presupuestos: JS inicial <1.5 MB gzip, primera escena jugable <12 MB,
   60 fps desktop / 30 fps móvil gama media, pixelRatio clamp 1.5-2,
   `InstancedMesh + LOD + frustum culling + pooling + dispose` auditado.
   Licencias solo CC0/MIT/Apache (Quaternius, KayKit, Kenney). Prohibido NC/ND.

5. **Baseline WebGL2 + mejora progresiva WebGPU.** Nada solo-WebGPU.

6. **Test-first + evidencia.** `lint + typecheck + test + build + Playwright contra Preview URL`
   + benchmark FPS/draw/tris/VRAM antes de cada merge. Suite fases previas 100% verde.

7. **Jev + Council.** Todo juicio repetitivo (>3 ítems) pasa por `jev_*`
   (classify/rank/check/score/ask). Toda decisión arquitectónica pasa por council
   (técnico + diseño + DevOps en paralelo) con Decision Log.

8. **Git seguro.** `main` protegida (= producción Vercel). Trabajo en `feature/*`.
   Push auto solo a `feature/*` + PR draft auto. Merge a `main` solo con aprobación
   humana explícita (`/aprueba merge`). Conventional Commits. Checkpoint tag por fase.

## Hardware de referencia (medir siempre igual)

- HIGH: RTX 3060 / RX 6600, i5-12400, 16 GB, 1080p
- LOW: GTX 1050 / Vega 8, i3, 8 GB, 720p
- Herramientas: `three-devtools + Playwright + Lighthouse + RenderDoc (si aplica)`

## Repos y nombres

- Remoto declarado: https://github.com/DilesZ/Espa-aSettlers.git (vacío, con `ñ` problemática).
  Usar `espana-settlers` sin `ñ`/espacios para repo, carpetas y proyecto Vercel.
