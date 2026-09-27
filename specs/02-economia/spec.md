# Spec 02 — Economía con cadenas (spec.md)

Estado: en implementación | Rama: `feature/02-economia` | Base: `main@d18f38a`

## Cadenas (diseño council)

- Madera: `1 tronco (tala) -> 2 tablones / 15s` (Aserradero, 1 worker)
- Pan: `1 trigo / 20s` (Granja) -> `1 harina / 12s` (Molino) -> `1 pan + 5 comida / 15s` (Panadería)
- Alternativa: Pescador `3 comida / 18s`, debe colocarse junto al río (x≥12)
- Bloque de piedra: descartado Fase 02 (cantera sigue dando piedra directa)

## Reglas

- Workers: cada receta consume colonos por orden de construcción; sin workers, edificio inactivo + alerta.
- Caps: base 200 por recurso, +100 por almacén. Vivienda: 6 + 4 por casa, máx visual 60.
- Crecimiento: +1 colono / 60s si comida≥10 (cuesta 10) y hay vivienda.
- Demoler: devuelve 50%, el Centro no se toca. Pausa individual por edificio.
- Alertas: almacén lleno, sin trabajadores, producción bloqueada (sin inputs).
- Victorias: slice (50/30) se mantiene; Fase 02 = 20 tablones + 15 pan acumulados.

## AC medibles

- AC-2.1: throughput aserradero ±10% en test headless 5 min (`lib/economy.test.ts`).
- AC-2.2: cadena pan encadenada 10/10 en test; sin molino la granja... (trigo se acumula, molino bloqueado visible).
- AC-2.3: demoler devuelve 50% en <2s.
- AC-2.4: `lint + typecheck + test + build` verdes + CI en push.
- Pendiente medir: 200 colonos/20 edificios estables (stretch; visual cap 60 con instancing en Fase 04).
