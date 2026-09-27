# Spec 04 — Pulido visual nivel S6 (spec.md)

Estado: en implementación | Rama: `feature/04-pulido`

## Pilares (web, coste 0)

- Día/noche: ciclo ~4 min (sol orbitando, fondo día/atardecer/noche, faroles nocturnos).
- Agua animada: doble plano traslúcido a la deriva + pulso de opacidad.
- Atmósfera: humo en edificios productivos (`Sparkles` drei), luciérnagas de noche.
- Post: `EffectComposer` (Bloom sutil + Viñeta) solo en Alto/Medio.
- Presets: Alto (dpr 1.75, sombras, post) / Medio (dpr 1.25, sombras, sin bloom) /
  Bajo (dpr 1, sin sombras ni post). Botones en HUD, se conserva en reset.

## AC

- AC-4.1: ciclo completo sin caídas; noche legible (faroles).
- AC-4.2: presets cambian dpr/sombras/post sin crash ni reload.
- AC-4.3: `lint + typecheck + test + build` verdes + CI.
- Métricas en `benchmarks/04.md` (FPS HIGH/LOW, draw calls, tris aprox).
- Comparativa ciega vs S6 y trailer: fuera de alcance automático (requiere humanos).
