# Spec 03 — IA rival, niebla, sonido (spec.md)

Estado: en implementación | Rama: `feature/03-rival`

## Rival IA (abstracta pero auditable)

- Base en (16,-20): centro IA (HP 300) + construcciones cada 35s de lista fija
  (granja→aserradero→casa→torre→molino→panadería→casa→torre…), sin trampas de recursos.
- Raiders: 1 cada 45s (cap 3 + 1 por cada 2 min, máx 8), HP 40, dps 5 a edificios/reclutas.
- Tier 2 = 6 edificios IA. Si IA llega a 10 edificios antes de victoria02 → derrota por presión
  (mensaje; la partida sigue en sandbox pero cuenta como derrota).

## Combate propio

- Torre: coste 20/15, HP 250, rango 14, dps 10 auto al raider más cercano. Da visión 16.
- Recluta: botón entrenar (15 comida, requiere vivienda libre), HP 50, dps 8; busca enemigo
  más cercano (raider > edificios IA) y ataca cuerpo a cuerpo.
- Edificios propios con HP (centro 500, resto 150-250); destruidos desaparecen (sin refund).
- Derrota: centro a 0. Victoria03: destruir centro IA.

## Niebla

- Grid 32x32 (celda 2m): 0 inexplorado (opaco), 1 explorado (traslúcido), 2 visible.
- Visión: edificios 12, colonos/reclutas 8, torres 16. Recalcula cada 0.5s.
- Enemigos solo se renderizan si su celda es visible (anti-trampa).

## Sonido (procedural WebAudio, sin assets)

- `lib/audio.ts`: `playSound('build'|'coin'|'hit'|'alarm'|'win'|'click')`, ambiente con ruido
  filtrado en loop, `setMuted/muted`, `ensureAudio()` en primer gesto. Botón mute en HUD.

## AC

- AC-3.1: IA alcanza 6 edificios actuando cada 35s (log en consola por build).
- AC-3.2: celda inexplorada opaca; torre revela a 16m (tests `lib/fog.test.ts`).
- AC-3.3: torre mata raider (40HP) en ~4s; recluta dps 8 ± juego.
- AC-3.4: sonidos en construir/entrega/alarma/victoria + mute persistente.
