"use client";

import { BUILDINGS, BuildingType, WIN_MADERA, WIN_PIEDRA } from "@/lib/economy";
import { useGame } from "@/store/game";

const ORDER: BuildingType[] = ["lenador", "cantera", "casa", "almacen"];

export default function HUD() {
  const resources = useGame((s) => s.resources);
  const colonos = useGame((s) => s.colonos);
  const selected = useGame((s) => s.selected);
  const select = useGame((s) => s.select);
  const message = useGame((s) => s.message);
  const victory = useGame((s) => s.victory);
  const reset = useGame((s) => s.reset);
  const ghostError = useGame((s) => s.ghostError);
  const buildings = useGame((s) => s.buildings);

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-4 rounded-lg border border-white/10 bg-black/50 px-4 py-2 text-sm">
        <span>🪵 {Math.floor(resources.madera)}/{WIN_MADERA}</span>
        <span>🪨 {Math.floor(resources.piedra)}/{WIN_PIEDRA}</span>
        <span>🌾 {Math.floor(resources.comida)}</span>
        <span>🧍 {colonos}</span>
        <span>🏠 {buildings.length}</span>
        <button onClick={reset} className="ml-auto rounded bg-white/10 px-3 py-1 hover:bg-white/20">
          Reiniciar
        </button>
      </div>
      {victory && (
        <div className="rounded-lg border border-green-400/40 bg-green-900/60 px-4 py-3 text-sm">
          ¡Victoria del slice! Tienes {WIN_MADERA} madera + {WIN_PIEDRA} piedra. Fase 02: cadenas de
          producción.
        </div>
      )}
      <div className="flex flex-wrap gap-2">
        {ORDER.map((t) => {
          const afford =
            resources.madera >= BUILDINGS[t].coste.madera &&
            resources.piedra >= BUILDINGS[t].coste.piedra;
          const active = selected === t;
          return (
            <button
              key={t}
              onClick={() => select(active ? null : t)}
              className={`rounded-lg border px-3 py-2 text-left text-xs ${
                active
                  ? "border-yellow-300 bg-yellow-900/40"
                  : afford
                    ? "border-white/15 bg-white/5 hover:bg-white/10"
                    : "border-white/10 bg-white/[0.02] opacity-50"
              }`}
              title={BUILDINGS[t].nombre}
            >
              <div className="font-semibold">{BUILDINGS[t].nombre}</div>
              <div>
                🪵{BUILDINGS[t].coste.madera} 🪨{BUILDINGS[t].coste.piedra}
              </div>
            </button>
          );
        })}
      </div>
      <p className="text-xs text-zinc-400">
        {selected
          ? ghostError ?? `Colocando ${BUILDINGS[selected].nombre}: clic en el terreno (verde válido, rojo inválido).`
          : (message ?? "Selecciona un edificio.")}
      </p>
    </div>
  );
}
