/** Lógica pura Fases 01-02 — testeable sin React. */

export type BuildingType =
  | "centro"
  | "lenador"
  | "cantera"
  | "casa"
  | "almacen"
  | "aserradero"
  | "granja"
  | "molino"
  | "panaderia"
  | "pescador";

export const BUILDINGS: Record<
  BuildingType,
  { nombre: string; coste: { madera: number; piedra: number }; color: string; radio: number }
> = {
  centro: { nombre: "Centro Urbano", coste: { madera: 0, piedra: 0 }, color: "#e9c46a", radio: 3 },
  lenador: { nombre: "Leñador", coste: { madera: 10, piedra: 0 }, color: "#90be6d", radio: 2 },
  cantera: { nombre: "Cantera", coste: { madera: 10, piedra: 0 }, color: "#adb5bd", radio: 2 },
  casa: { nombre: "Casa (+4 colonos)", coste: { madera: 15, piedra: 5 }, color: "#f4a261", radio: 2 },
  almacen: { nombre: "Almacén (+100 cap)", coste: { madera: 20, piedra: 10 }, color: "#2a9d8f", radio: 2.5 },
  aserradero: { nombre: "Aserradero", coste: { madera: 25, piedra: 10 }, color: "#b5835a", radio: 2.5 },
  granja: { nombre: "Granja", coste: { madera: 20, piedra: 5 }, color: "#d4a373", radio: 2.5 },
  molino: { nombre: "Molino", coste: { madera: 30, piedra: 15 }, color: "#e5e5e5", radio: 2.5 },
  panaderia: { nombre: "Panadería", coste: { madera: 30, piedra: 20 }, color: "#c08552", radio: 2.5 },
  pescador: { nombre: "Pescador (río)", coste: { madera: 15, piedra: 0 }, color: "#48cae4", radio: 2 },
};

export type Resources = {
  madera: number;
  piedra: number;
  comida: number;
  tablon: number;
  trigo: number;
  harina: number;
  pan: number;
};

export const emptyResources = (): Resources => ({
  madera: 0,
  piedra: 0,
  comida: 0,
  tablon: 0,
  trigo: 0,
  harina: 0,
  pan: 0,
});

export const WIN_MADERA = 50;
export const WIN_PIEDRA = 30;
/** Victoria Fase 02: producción acumulada. */
export const WIN_TABLON = 20;
export const WIN_PAN = 15;
export const MAP_HALF = 30;
/** Franja de agua: x > 22 es inválida (río). */
export const WATER_X = 22;
/** El pescador debe estar cerca del río. */
export const FISH_MIN_X = 12;
export const BASE_CAP = 200;
export const ALMACEN_BONUS = 100;
export const CASA_COLONOS = 4;
export const MAX_SETTLERS = 60;

export type Recipe = {
  building: BuildingType;
  inputs: Partial<Resources>;
  outputs: Partial<Resources>;
  time: number;
  workers: number;
};

export const RECIPES: Partial<Record<BuildingType, Recipe>> = {
  // 1 tronco (10s de tala aprox) -> 2 tablones (15s)
  aserradero: {
    building: "aserradero",
    inputs: { madera: 1 },
    outputs: { tablon: 2 },
    time: 15,
    workers: 1,
  },
  // 1 trigo (20s) -> 1 harina (12s) -> 1 pan (15s)
  granja: { building: "granja", inputs: {}, outputs: { trigo: 1 }, time: 20, workers: 1 },
  molino: { building: "molino", inputs: { trigo: 1 }, outputs: { harina: 1 }, time: 12, workers: 1 },
  panaderia: {
    building: "panaderia",
    inputs: { harina: 1 },
    outputs: { pan: 1, comida: 5 },
    time: 15,
    workers: 1,
  },
  pescador: { building: "pescador", inputs: {}, outputs: { comida: 3 }, time: 18, workers: 1 },
};

export function storageCap(almacenes: number): number {
  return BASE_CAP + almacenes * ALMACEN_BONUS;
}

export function housingCap(casas: number): number {
  return 6 + casas * CASA_COLONOS;
}

export function canAfford(res: Resources, t: BuildingType): boolean {
  const c = BUILDINGS[t].coste;
  return res.madera >= c.madera && res.piedra >= c.piedra;
}

export function payCost(res: Resources, t: BuildingType): Resources {
  const c = BUILDINGS[t].coste;
  return { ...res, madera: res.madera - c.madera, piedra: res.piedra - c.piedra };
}

export type Placed = { x: number; z: number; radio: number };

export function placementError(
  x: number,
  z: number,
  t: BuildingType,
  placed: Placed[],
): string | null {
  if (Math.abs(x) > MAP_HALF || Math.abs(z) > MAP_HALF) return "Fuera del mapa";
  if (x > WATER_X) return "En el agua";
  // Pendiente simulada: esquinas montañosas inválidas
  if (Math.abs(x) + Math.abs(z) > 52) return "Pendiente >30°";
  // Pescador junto al río
  if (t === "pescador" && x < FISH_MIN_X) return "El pescador debe estar junto al río (x≥12)";
  const r = BUILDINGS[t].radio;
  for (const b of placed) {
    const d = Math.hypot(b.x - x, b.z - z);
    if (d < b.radio + r + 0.5) return "Colisiona con otro edificio";
  }
  return null;
}

export function isVictory(res: Resources): boolean {
  return res.madera >= WIN_MADERA && res.piedra >= WIN_PIEDRA;
}

export function isVictory02(stats: { tablon: number; pan: number }): boolean {
  return stats.tablon >= WIN_TABLON && stats.pan >= WIN_PAN;
}

/** Sim headless determinista: produce durante `seconds` con stock dado. */
export function simulateProduction(
  recipe: Recipe,
  stock: Resources,
  seconds: number,
): { stock: Resources; batches: number } {
  const s = { ...stock };
  const batches = Math.floor(seconds / recipe.time);
  let done = 0;
  for (let i = 0; i < batches; i++) {
    const ok = (Object.keys(recipe.inputs) as (keyof Resources)[]).every(
      (k) => s[k] >= (recipe.inputs[k] ?? 0),
    );
    if (!ok) break;
    for (const k of Object.keys(recipe.inputs) as (keyof Resources)[]) s[k] -= recipe.inputs[k] ?? 0;
    for (const k of Object.keys(recipe.outputs) as (keyof Resources)[]) s[k] += recipe.outputs[k] ?? 0;
    done++;
  }
  return { stock: s, batches: done };
}
