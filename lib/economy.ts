/** Lógica pura Fase 01 — testeable sin React. */

export type BuildingType = "centro" | "lenador" | "cantera" | "casa" | "almacen";

export const BUILDINGS: Record<
  BuildingType,
  { nombre: string; coste: { madera: number; piedra: number }; color: string; radio: number }
> = {
  centro: { nombre: "Centro Urbano", coste: { madera: 0, piedra: 0 }, color: "#e9c46a", radio: 3 },
  lenador: { nombre: "Leñador", coste: { madera: 10, piedra: 0 }, color: "#90be6d", radio: 2 },
  cantera: { nombre: "Cantera", coste: { madera: 10, piedra: 0 }, color: "#adb5bd", radio: 2 },
  casa: { nombre: "Casa", coste: { madera: 15, piedra: 5 }, color: "#f4a261", radio: 2 },
  almacen: { nombre: "Almacén", coste: { madera: 20, piedra: 10 }, color: "#2a9d8f", radio: 2.5 },
};

export type Resources = { madera: number; piedra: number; comida: number };

export const WIN_MADERA = 50;
export const WIN_PIEDRA = 30;
export const MAP_HALF = 30;
/** Franja de agua: x > 22 es inválida (río). */
export const WATER_X = 22;

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
