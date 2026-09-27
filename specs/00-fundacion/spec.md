# Spec 00 — Fundación (spec.md)

Fase: 00-fundacion | Stack: Next.js + Three.js / R3F + Rapier (primario council) | Estado: draft

## Objetivo

Dejar repo + motor + pipeline + benchmark que hagan posible calidad S6 sin reescribir.
Proyecto greenfield: repo remoto vacío, carpeta local vacía (verificado 2026-09-27).

## Alcance (in)

- Init proyecto web estático desplegable en Vercel desde `main`.
- Escena benchmark vacía + script FPS/draw/tris/VRAM con CSV.
- Pipeline `Blender -> .glb -> Draco + KTX2` documentado.
- CI: lint + typecheck + test + build + Preview.
- Decision Log motor firmado.

## Fuera de alcance (out)

- Gameplay, edificios, colonos (Fase 01).
- Texturas 2048, GI, volumétricos, post completo (Fase 04).
- Multiplayer online (v2).

## User Stories

- US-0.1 Como lead técnico quiero proyecto Next.js static export + TS + R3F boot
  para no bloquear Vercel.
- US-0.2 Como artista quiero pipeline de importación `.glb` PBR documentado
  para no retrabajar assets.
- US-0.3 Como QA quiero `benchmark` vacía + script FPS/draw/tris/VRAM
  para tener baseline objetiva.
- US-0.4 Como diseñador quiero `constitution.md` que declare calidad S6
  innegociable pero incremental.

## Criterios de aceptación (medibles)

- AC-0.1: escena vacía `>=120 FPS @1080p HIGH, >=60 FPS @720p LOW`, draw <=20, tris <10k, VRAM <300 MB.
- AC-0.2: import `.glb` 2k PBR <5 s, sin errores, 4 mapas enlazados (albedo/normal/rough/AO).
- AC-0.3: CI `lint + typecheck + test + build` <10 min, 100% verde + Preview URL comenta en PR.
- AC-0.4: `constitution.md v0.0.1` versionado + Decision Log motor firmado.
- AC-0.5: `vercel login` + `link` vía navegador, sin tokens en chat; solo `main` dispara Production.

## Métricas gráficas Fase 00

| Métrica | Target |
|---|---|
| FPS vacía HIGH 1080p / LOW 720p | >=120 / >=60 |
| Draw calls | <=20 |
| Tris | <10k |
| VRAM | <300 MB |
| Texturas | solo checker 512 + grid |
| Sombras | OFF, validar ON/OFF sin crash |

## Riesgos

- Repo con `ñ` (`Espa-aSettlers`) rompe Git/Vercel/Win → renombrar a `espana-settlers`.
- `gh` CLI no instalada (verificado) → instalar o usar dashboard + `vercel link`.
- Assets pesados tumban Hobby (100 GB/mes) → R2/CDN externo para `.glb/.ktx2/.wasm`.
- `TYPESAFE_API_KEY` ausente → Jev en modo manual hasta exportar key.

## Definition of Done

- [ ] Repo clona y `npm run dev` abre canvas sin errores.
- [ ] Benchmark reproducible 3 corridas desviación <5% en `benchmarks/00.md`.
- [ ] Doc `docs/art-pipeline.md` con captura importación correcta.
- [ ] Tag `v0.0-fundacion`.
