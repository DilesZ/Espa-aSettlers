# Plan 00 — Fundación (plan.md)

Stack primario: `Next.js App Router output:'export' + TS + React Three Fiber + drei + postprocessing + Rapier-compat WASM + zustand + Tailwind HUD`
Alternativo documentado: Babylon.js 9 / Godot 4.7 solo si se renuncia a Vercel.

## Arquitectura

```
app/ (Next static) -> Canvas R3F (solo cliente, 'use client')
  WorldRenderer (interfaz hexagonal: Three <-> Babylon intercambiable)
  AssetLoader (glTF+Draco+KTX2, lazy por escena)
  SimWorker (tick 10-20 Hz, determinista, semilla) <-> Render 60 fps
  HUD DOM (menús) + canvas (mundo)
store/ zustand (recursos, selección)
benchmarks/ script FPS/draw/tris/VRAM -> CSV + MD
```

Decisiones inamovibles: static export, sim separada, baseline WebGL2 + WebGPU progresivo,
`InstancedMesh+LOD+culling+pooling`, `COOP/COEP` no necesarios con este stack.

## Infra Vercel + GitHub

1. `vercel login` (navegador) + `vercel link` → `.vercel/project.json`.
2. Dashboard Vercel > Add Git Repo `espana-settlers`, Production=`main`, framework Next/Vite.
3. Ramas `main (protegida) / feature/* / fix/* / chore/*`. Push auto solo `feature/*` + PR draft.
4. `vercel.json`: framework next, `application/wasm`, Brotli, sin headers COOP/COEP.
5. Assets pesados → R2/BunnyCDN, no al bundle. `next/image` solo UI.
6. Instalar `gh` CLI después (`winget install GitHub.cli`) para `gh pr create --draft`.

Toolchain verificado 2026-09-27: node v24.13.1, npm 11.8.0, git 2.53.0, Vercel 53.4.0, gh ausente.

## Testing

- `npm run lint && typecheck && test (vitest) && build` pre-push obligatorio.
- Playwright contra Preview URL real, no localhost. FPS>30 smoke.
- Benchmark 3 corridas, desviación <5%.

## Skills / MCP (puerta aprueba)

Proponer ficha antes de instalar, 1 por vez, verificar build+Preview:
Skills: `vercel-labs/agent-skills/vercel-react-best-practices`, `composition-patterns`,
`deploy-to-vercel`, `anthropics/skills/webapp-testing`, `frontend-design`.
MCP: `Vercel MCP`, `GitHub MCP`, `Playwright MCP`, `threejs-devtools-mcp`.
Crear skill propia `three-r3f-perf` tras boot si no existe oficial.

## Jev + Council en esta fase

- `jev_rank`: qué docs/ejemplos R3F abrir para boot.
- `jev_check`: `¿build verde? ¿Preview responde? ¿benchmark reproducible?`
- Council: Decision Log motor firmado en `docs/decision-log.md`.

## Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| `ñ` en repo/ruta | renombrar a `espana-settlers` |
| Bundle >1.5 MB gzip | tree-shake drei, lazy chunks, R2 externo |
| Shader stutter primer frame | warmup + loading por escena + shader cache |
| Hobby 100 GB agota | lazy per-escena, KTX2 4-8x menos VRAM |
