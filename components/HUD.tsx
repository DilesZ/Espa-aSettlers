"use client";

import { useState } from "react";
import { BUILDINGS, RECIPES, WIN_PAN, WIN_TABLON, canAfford, storageCap } from "@/lib/economy";
import type { BuildingType } from "@/lib/economy";
import { deriveAlerts, useGame } from "@/store/game";
import { ensureAudio, isMuted, setMuted } from "@/lib/audio";

const PALETA = [
  "lenador",
  "cantera",
  "casa",
  "almacen",
  "aserradero",
  "granja",
  "molino",
  "panaderia",
  "pescador",
  "torre",
] as unknown as BuildingType[];

export default function HUD() {
  const resources = useGame((s) => s.resources);
  const colonos = useGame((s) => s.colonos);
  const buildings = useGame((s) => s.buildings);
  const stats = useGame((s) => s.stats);
  const selected = useGame((s) => s.selected);
  const select = useGame((s) => s.select);
  const demolish = useGame((s) => s.demolish);
  const toggleDemolish = useGame((s) => s.toggleDemolish);
  const togglePause = useGame((s) => s.togglePause);
  const reset = useGame((s) => s.reset);
  const message = useGame((s) => s.message);
  const ghostError = useGame((s) => s.ghostError);
  const victory = useGame((s) => s.victory);
  const victory02 = useGame((s) => s.victory02);
  const victory03 = useGame((s) => (s as unknown as { victory03?: boolean } | undefined)?.victory03);
  const defeat = useGame((s) => (s as unknown as { defeat?: boolean } | undefined)?.defeat);
  const [muted, setMutedState] = useState<boolean>(() => isMuted());

  const almacenes = buildings.filter((b) => b.type === "almacen").length;
  const cap = storageCap(almacenes);
  const capFull = (Object.values(resources) as number[]).some((v) => v >= cap);
  const alerts = deriveAlerts(buildings, colonos, capFull);
  const productivos = buildings.filter((b) => RECIPES[b.type] != null);

  return (
    <div className="flex flex-col gap-2 text-xs text-zinc-200">
      {/* 1) Barra de recursos */}
      <div className="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-lg border border-white/10 bg-black/60 px-3 py-2">
        <span title="Madera">🪵 {Math.floor(resources.madera)}</span>
        <span title="Piedra">🪨 {Math.floor(resources.piedra)}</span>
        <span title="Comida">🍖 {Math.floor(resources.comida)}</span>
        <span title="Tablón">🪚 {Math.floor(resources.tablon)}</span>
        <span title="Trigo">🌾 {Math.floor(resources.trigo)}</span>
        <span title="Harina">🧺 {Math.floor(resources.harina)}</span>
        <span title="Pan">🍞 {Math.floor(resources.pan)}</span>
        <span title="Colonos">🧍 {colonos}</span>
        <span title="Edificios">🏠 {buildings.length}</span>
        <span title="Almacén" className="text-zinc-400">
          Cap {cap}
        </span>
        <button
          onClick={() => {
            ensureAudio();
            const nm = !muted;
            setMuted(nm);
            setMutedState(nm);
          }}
          className="ml-auto rounded bg-white/10 px-2 py-1 text-xs hover:bg-white/20"
          title={muted ? "Activar sonido" : "Silenciar"}
        >
          {muted ? "🔇" : "🔊"}
        </button>
        <button
          onClick={() => {
            ensureAudio();
            reset();
          }}
          className="rounded bg-white/10 px-2 py-1 text-xs hover:bg-white/20"
        >
          Reiniciar
        </button>
        <button
          onClick={() => {
            ensureAudio();
            const train = (useGame as unknown as { getState: () => { trainRecruit?: () => void } }).getState().trainRecruit;
            train?.();
          }}
          className="rounded bg-white/10 px-2 py-1 text-xs hover:bg-white/20"
          title="Entrenar recluta (cuesta 15 de trigo)"
        >
          Entrenar recluta (15🌾)
        </button>
      </div>

      {/* 6) Banners de victoria */}
      {victory && (
        <div className="rounded-lg border border-green-400/40 bg-green-900/60 px-3 py-2 text-xs">
          ¡Victoria del slice! Fase 02 en marcha: produce {WIN_TABLON} tablones + {WIN_PAN} pan
          ({stats.tablon}/{WIN_TABLON} 🪚, {stats.pan}/{WIN_PAN} 🍞).
        </div>
      )}
      {victory02 && (
        <div className="rounded-lg border border-yellow-300/50 bg-yellow-900/60 px-3 py-2 text-xs font-semibold text-yellow-100">
          ¡Victoria Fase 02! {WIN_TABLON} tablones + {WIN_PAN} pan conseguidos. ¡Asentamiento
          próspero!
        </div>
      )}
      {victory03 && (
        <div className="rounded-lg border border-yellow-300/50 bg-yellow-900/60 px-3 py-2 text-xs font-semibold text-yellow-100">
          ¡Victoria total! Centro enemigo destruido.
        </div>
      )}
      {defeat && (
        <div className="rounded-lg border border-red-400/40 bg-red-900/60 px-3 py-2 text-xs font-semibold text-red-100">
          Derrota: tu Centro ha caído.
        </div>
      )}

      {/* 2) Paleta de construcción + 3) Demoler */}
      <div className="flex flex-wrap gap-1.5">
        {PALETA.map((t) => {
          const afford = canAfford(resources, t);
          const active = selected === t;
          return (
            <button
              key={t}
              onClick={() => {
                ensureAudio();
                select(active ? null : t);
              }}
              className={`rounded-md border px-2 py-1.5 text-left text-[11px] leading-tight ${
                active
                  ? "border-yellow-300 bg-yellow-900/50"
                  : afford
                    ? "border-white/15 bg-white/5 hover:bg-white/10"
                    : "border-white/10 bg-white/[0.02] opacity-50"
              }`}
              title={BUILDINGS[t].nombre}
            >
              <div className="font-semibold">{BUILDINGS[t].nombre}</div>
              <div className="text-zinc-400">
                🪵{BUILDINGS[t].coste.madera} 🪨{BUILDINGS[t].coste.piedra}
              </div>
            </button>
          );
        })}
        <button
          onClick={() => {
            ensureAudio();
            toggleDemolish();
          }}
          className={`rounded-md border px-2 py-1.5 text-[11px] font-semibold ${
            demolish
              ? "border-red-400 bg-red-900/70 text-red-100"
              : "border-white/15 bg-white/5 hover:bg-white/10"
          }`}
          title="Modo demoler: clic en un edificio para demolerlo (50% devuelto)"
        >
          🧨 Demoler{demolish ? " (ON)" : ""}
        </button>
      </div>

      {/* 4) Edificios productivos con progreso */}
      <div className="rounded-lg border border-white/10 bg-black/50 px-3 py-2">
        <div className="mb-1 font-semibold text-zinc-300">
          Producción ({productivos.length})
        </div>
        {productivos.length === 0 ? (
          <p className="text-[11px] text-zinc-500">
            Sin edificios productivos. Construye aserradero, granja, molino, panadería o pescador.
          </p>
        ) : (
          <ul className="flex max-h-32 flex-col gap-1 overflow-y-auto">
            {productivos.map((b) => {
              const { hp, maxHp } = (b as unknown as {hp?:number;maxHp?:number});
              return (
              <li key={b.id} className="flex items-center gap-2 text-[11px]">
                <span className="w-28 truncate" title={`#${b.id} (${b.x.toFixed(0)},${b.z.toFixed(0)})`}>
                  #{b.id} {BUILDINGS[b.type].nombre}
                </span>
                {hp != null && maxHp != null && (
                  <span className="text-zinc-400" title="Puntos de vida">
                    ❤ {Math.ceil(hp)}/{maxHp}
                  </span>
                )}
                <div className="h-2 flex-1 overflow-hidden rounded bg-white/10">
                  <div
                    className={`h-full rounded ${b.blocked && !b.paused ? "bg-red-400" : "bg-green-400"}`}
                    style={{ width: `${Math.round(b.progress * 100)}%` }}
                  />
                </div>
                {b.paused && <span className="text-yellow-300">Pausado</span>}
                {!b.paused && b.blocked && <span className="text-red-300">Bloq.</span>}
                <button
                  onClick={() => {
                    ensureAudio();
                    togglePause(b.id);
                  }}
                  className="rounded bg-white/10 px-1.5 py-0.5 hover:bg-white/20"
                >
                  {b.paused ? "Reanudar" : "Pausar"}
                </button>
              </li>
              );
            })}
          </ul>
        )}
      </div>

      {/* 5) Alertas */}
      {alerts.length > 0 && (
        <ul className="flex flex-col gap-1">
          {alerts.map((a, i) => (
            <li
              key={`${a.kind}-${i}`}
              className="rounded-md border border-orange-400/30 bg-orange-950/60 px-2 py-1 text-[11px] text-orange-100"
            >
              ⚠ {a.text}
            </li>
          ))}
        </ul>
      )}

      {/* 7) Mensaje de estado */}
      <p className="min-h-4 text-[11px] text-zinc-400">
        {selected
          ? (ghostError ?? `Colocando ${BUILDINGS[selected].nombre}: clic en el terreno (verde válido, rojo inválido).`)
          : (message ?? "Selecciona un edificio.")}
        {selected && message ? ` — ${message}` : ""}
      </p>
    </div>
  );
}
