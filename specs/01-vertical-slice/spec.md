# Spec 01 — Vertical Slice (spec.md)

Estado: implementado 2026-09-27 | Rama: feature/00-boot (sigue) / tag `v0.1-slice`

## Contenido

- 1 mapa 64x64 (río x>22 inválido, esquinas pendiente>30° inválidas).
- Cámara RTS (OrbitControls: pan/zoom/rotar).
- 5 edificios: Centro (inicial), Leñador, Cantera, Casa, Almacén. Fantasma verde/rojo.
- 6 colonos con estados idle→toTree/toRock→chop/mine→return→entrega (+5 madera / +4 piedra).
- 12 árboles + 6 rocas. Victoria: 50 madera + 30 piedra.
- HUD: recursos, paleta con costes, mensajes, banner victoria, reinicio.

## AC

- AC-1.1: rechazos agua/borde/colisión verificados en `lib/economy.test.ts` (4 tests).
- AC-1.2: ciclo talar→transportar→almacenar visible con entrega en Centro.
- AC-1.3: `typecheck + lint + test (5 passed) + build static` verdes.
- Pendiente medir: FPS con 50 colonos, soak 15 min, playtester ciego (Fase 01 completa).
