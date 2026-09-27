# Tasks 00 — Fundación (tasks.md)

Cada tarea <4h, con DoD. Orden estricto.

- [ ] T-0.1 Init repo + boot Next+R3F en `feature/00-boot`
  - `npx create-next-app@latest espana-settlers --ts --app`, `output:'export'`,
    `npm i -E three @react-three/fiber @react-three/drei @react-three/postprocessing zustand`,
    `.nvmrc` 22 LTS, `.gitignore`, Canvas boot + OrbitControls.
  - DoD: `npm run dev` abre canvas sin errores, `npm run build` verde.

- [ ] T-0.2 Constitution + plantillas spec/plan/tasks
  - Hecho: `.specify/memory/constitution.md v0.0.1`. Falta `docs/decision-log.md`.
  - DoD: constitution versionada + log firmado.

- [ ] T-0.3 Benchmark vacía + script bench
  - `app/benchmark/page.tsx` + `lib/bench.ts` log CSV FPS/ms/draw/tris/VRAM.
  - DoD: 3 corridas en `benchmarks/00.md` desviación <5%, cumple AC-0.1.

- [ ] T-0.4 Pipeline Blender export + `docs/art-pipeline.md`
  - glTF + Draco + KTX2 + atlas 1024, test `.glb` 2k PBR <5s.
  - DoD: doc con captura + checklist licencias CC0.

- [ ] T-0.5 CI + Vercel link
  - GitHub Actions lint/type/test/build, `vercel link` vía navegador,
    protección `main` (PR + checks), Preview comenta en PR.
  - DoD: PR draft verde + Preview URL responde.

- [ ] T-0.6 Skills/MCP ficha + instalación con aprobación
  - Mostrar ficha `vercel-react-best-practices` y `Playwright MCP`, esperar `aprueba`.
  - DoD: 1 instalación por vez, build+Preview verde tras cada una.

- [ ] T-0.7 Checkpoint `v0.0-fundacion`
  - `git tag -a v0.0-fundacion -m "checkpoint: boot + benchmark + pipeline"`, push tags.
  - DoD: tag + Release notes + trazabilidad US->AC->T->commit->test.

## Benchmark plantilla (`benchmarks/00.md`)

```
Fecha:
HIGH 1080p: FPS / draw / tris / VRAM:
LOW 720p: FPS / draw / tris / VRAM:
Desviación 3 corridas:
Preview URL:
Commit SHA:
Verdict: PASS/FAIL vs AC-0.1
```
