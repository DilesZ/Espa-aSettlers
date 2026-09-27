"use client";

import { create } from "zustand";
import {
  BUILDINGS,
  BuildingType,
  CASA_COLONOS,
  MAX_SETTLERS,
  Placed,
  RECIPES,
  Recipe,
  Resources,
  WIN_MADERA,
  WIN_PIEDRA,
  WIN_PAN,
  WIN_TABLON,
  canAfford,
  emptyResources,
  housingCap,
  isVictory,
  isVictory02,
  payCost,
  placementError,
  storageCap,
} from "@/lib/economy";

export type Building = {
  id: number;
  type: BuildingType;
  x: number;
  z: number;
  paused: boolean;
  progress: number;
  blocked: boolean;
};
export type Settler = {
  id: number;
  x: number;
  z: number;
  state: "idle" | "toTree" | "chop" | "toRock" | "mine" | "return";
  tx: number;
  tz: number;
  carry: "madera" | "piedra" | null;
  timer: number;
};
export type Node = { id: number; kind: "tree" | "rock"; x: number; z: number; amount: number };

let nextId = 1;

const initialNodes: Node[] = [
  ...Array.from({ length: 12 }, (_, i) => ({
    id: nextId++,
    kind: "tree" as const,
    x: -24 + (i % 4) * 5,
    z: -20 + Math.floor(i / 4) * 6,
    amount: 100,
  })),
  ...Array.from({ length: 6 }, (_, i) => ({
    id: nextId++,
    kind: "rock" as const,
    x: -20 + (i % 3) * 6,
    z: 12 + Math.floor(i / 3) * 6,
    amount: 100,
  })),
];

export type Alert = { kind: "full" | "workers" | "blocked"; text: string };

type GameState = {
  resources: Resources;
  colonos: number;
  buildings: Building[];
  settlers: Settler[];
  nodes: Node[];
  stats: { tablon: number; pan: number };
  selected: BuildingType | null;
  demolish: boolean;
  ghost: { x: number; z: number } | null;
  ghostError: string | null;
  message: string | null;
  victory: boolean;
  victory02: boolean;
  growTimer: number;
  select: (t: BuildingType | null) => void;
  toggleDemolish: () => void;
  setGhost: (x: number, z: number) => void;
  place: (x: number, z: number) => void;
  clickBuilding: (id: number) => void;
  togglePause: (id: number) => void;
  tick: (dt: number) => void;
  reset: () => void;
};

function spawnSettlers(n: number, x = 0, z = 4): Settler[] {
  return Array.from({ length: n }, () => ({
    id: nextId++,
    x: x + (Math.random() - 0.5) * 4,
    z: z + (Math.random() - 0.5) * 4,
    state: "idle" as const,
    tx: 0,
    tz: 0,
    carry: null,
    timer: Math.random() * 1.5,
  }));
}

const initialSettlers = spawnSettlers(6);

function stepSettler(s: Settler, nodes: Node[], dt: number): Settler {
  const speed = 5 * dt;
  const move = (tx: number, tz: number) => {
    const dx = tx - s.x;
    const dz = tz - s.z;
    const d = Math.hypot(dx, dz);
    if (d < 0.4) return { arrived: true, x: tx, z: tz };
    return { arrived: false, x: s.x + (dx / d) * Math.min(speed, d), z: s.z + (dz / d) * Math.min(speed, d) };
  };
  switch (s.state) {
    case "idle": {
      if (s.timer > 0) return { ...s, timer: s.timer - dt };
      const tree = nodes.find((n) => n.kind === "tree" && n.amount > 0);
      const rock = nodes.find((n) => n.kind === "rock" && n.amount > 0);
      const wantStone = rock && Math.random() < 0.4;
      const target = wantStone ? rock : tree;
      if (!target) return { ...s, timer: 1 };
      return {
        ...s,
        state: target.kind === "tree" ? "toTree" : "toRock",
        tx: target.x,
        tz: target.z,
        timer: 0,
      };
    }
    case "toTree":
    case "toRock": {
      const m = move(s.tx, s.tz);
      if (m.arrived)
        return { ...s, x: m.x, z: m.z, state: s.state === "toTree" ? "chop" : "mine", timer: 3 };
      return { ...s, x: m.x, z: m.z };
    }
    case "chop":
    case "mine": {
      if (s.timer > 0) return { ...s, timer: s.timer - dt };
      return {
        ...s,
        state: "return",
        tx: 0,
        tz: 2,
        carry: s.state === "chop" ? "madera" : "piedra",
      };
    }
    case "return": {
      const m = move(0, 2);
      return { ...s, x: m.x, z: m.z };
    }
  }
}

function hasInputs(res: Resources, r: Recipe): boolean {
  return (Object.keys(r.inputs) as (keyof Resources)[]).every((k) => res[k] >= (r.inputs[k] ?? 0));
}

function clampToCap(res: Resources, cap: number): { res: Resources; full: boolean } {
  const out = { ...res };
  let full = false;
  for (const k of Object.keys(out) as (keyof Resources)[]) {
    if (out[k] > cap) {
      out[k] = cap;
      full = true;
    }
  }
  return { res: out, full };
}

export function deriveAlerts(
  buildings: Building[],
  colonos: number,
  capFull: boolean,
): Alert[] {
  const alerts: Alert[] = [];
  const need = buildings.reduce((a, b) => a + (RECIPES[b.type]?.workers ?? 0), 0);
  if (need > colonos)
    alerts.push({ kind: "workers", text: `Sin transportistas: ${need} puestos, ${colonos} colonos. Construye casas.` });
  if (capFull) alerts.push({ kind: "full", text: "Almacén lleno: amplía con almacenes." });
  const blocked = buildings.filter((b) => b.blocked && !b.paused);
  if (blocked.length > 0)
    alerts.push({ kind: "blocked", text: `Producción bloqueada: ${blocked.map((b) => BUILDINGS[b.type].nombre).join(", ")}.` });
  return alerts;
}

export const useGame = create<GameState>((set, get) => ({
  resources: { ...emptyResources(), madera: 30, piedra: 15, comida: 10 },
  colonos: 6,
  buildings: [{ id: nextId++, type: "centro", x: 0, z: 0, paused: false, progress: 0, blocked: false }],
  settlers: initialSettlers,
  nodes: initialNodes,
  stats: { tablon: 0, pan: 0 },
  selected: null,
  demolish: false,
  ghost: null,
  ghostError: null,
  message: "Fase 02: encadena Aserradero y Panadería. Objetivo: 20 tablones + 15 pan.",
  victory: false,
  victory02: false,
  growTimer: 30,

  select: (t) => set({ selected: t, demolish: false, ghost: null, ghostError: null }),
  toggleDemolish: () => set((s) => ({ demolish: !s.demolish, selected: null, ghost: null })),

  setGhost: (x, z) => {
    const { selected, buildings } = get();
    if (!selected) return;
    const placed: Placed[] = buildings.map((b) => ({
      x: b.x,
      z: b.z,
      radio: BUILDINGS[b.type].radio,
    }));
    set({ ghost: { x, z }, ghostError: placementError(x, z, selected, placed) });
  },

  place: (x, z) => {
    const { selected, buildings, resources } = get();
    if (!selected) return;
    const placed: Placed[] = buildings.map((b) => ({
      x: b.x,
      z: b.z,
      radio: BUILDINGS[b.type].radio,
    }));
    const err = placementError(x, z, selected, placed);
    if (err) {
      set({ message: `No se puede construir: ${err}.` });
      return;
    }
    if (!canAfford(resources, selected)) {
      set({ message: `Sin recursos para ${BUILDINGS[selected].nombre}.` });
      return;
    }
    const b: Building = { id: nextId++, type: selected, x, z, paused: false, progress: 0, blocked: false };
    set({
      resources: payCost(resources, selected),
      buildings: [...buildings, b],
      message: `${BUILDINGS[selected].nombre} construido.`,
      selected: null,
      ghost: null,
      ghostError: null,
    });
  },

  clickBuilding: (id) => {
    const { demolish, buildings, resources } = get();
    if (!demolish) return;
    const b = buildings.find((x) => x.id === id);
    if (!b || b.type === "centro") {
      set({ message: "El Centro Urbano no se puede demoler." });
      return;
    }
    const c = BUILDINGS[b.type].coste;
    set({
      buildings: buildings.filter((x) => x.id !== id),
      resources: {
        ...resources,
        madera: resources.madera + Math.floor(c.madera / 2),
        piedra: resources.piedra + Math.floor(c.piedra / 2),
      },
      message: `${BUILDINGS[b.type].nombre} demolido (50% devuelto).`,
      demolish: false,
    });
  },

  togglePause: (id) =>
    set((s) => ({
      buildings: s.buildings.map((b) => (b.id === id ? { ...b, paused: !b.paused } : b)),
    })),

  tick: (dt) => {
    const st = get();
    const capped = Math.min(dt, 0.1);

    // 1) Recolectores
    let madera = 0;
    let piedra = 0;
    const next = st.settlers.map((s) => {
      const ns = stepSettler(s, st.nodes, capped);
      if (s.state === "return" && Math.hypot(ns.x - 0, ns.z - 2) < 0.5 && s.carry) {
        if (s.carry === "madera") madera += 5;
        else piedra += 4;
        return { ...ns, state: "idle" as const, carry: null, timer: 0.5 };
      }
      return ns;
    });

    // 2) Producción
    const almacenes = st.buildings.filter((b) => b.type === "almacen").length;
    const cap = storageCap(almacenes);
    let res: Resources = {
      ...st.resources,
      madera: st.resources.madera + madera,
      piedra: st.resources.piedra + piedra,
    };
    let tablonMade = 0;
    let panMade = 0;
    // Workers: se asignan por orden de construcción
    let freeWorkers = st.colonos;
    const buildings = st.buildings.map((b) => {
      const recipe = RECIPES[b.type];
      if (!recipe) return b;
      if (freeWorkers < recipe.workers) return { ...b, blocked: false };
      freeWorkers -= recipe.workers;
      if (b.paused) return { ...b, progress: 0, blocked: false };
      if (!hasInputs(res, recipe)) return { ...b, progress: 0, blocked: true };
      const progress = b.progress + capped / recipe.time;
      if (progress < 1) return { ...b, progress, blocked: false };
      // Completa tanda
      for (const k of Object.keys(recipe.inputs) as (keyof Resources)[]) res[k] -= recipe.inputs[k] ?? 0;
      for (const k of Object.keys(recipe.outputs) as (keyof Resources)[]) res[k] += recipe.outputs[k] ?? 0;
      if (recipe.outputs.tablon) tablonMade += recipe.outputs.tablon;
      if (recipe.outputs.pan) panMade += recipe.outputs.pan;
      return { ...b, progress: 0, blocked: false };
    });

    const clamped = clampToCap(res, cap);
    res = clamped.res;
    const stats = { tablon: st.stats.tablon + tablonMade, pan: st.stats.pan + panMade };

    // 3) Crecimiento: +1 colono cada 60s si hay comida y vivienda
    const casas = st.buildings.filter((b) => b.type === "casa").length;
    const hcap = Math.min(housingCap(casas), MAX_SETTLERS);
    let colonos = st.colonos;
    let settlers = next;
    let growTimer = st.growTimer - capped;
    let food = res.comida;
    if (growTimer <= 0) {
      growTimer = 60;
      if (colonos < hcap && food >= 10) {
        food -= 10;
        colonos += 1;
        settlers = [...next, ...spawnSettlers(1)];
      }
    }

    const won = st.victory || isVictory(res);
    const won02 = st.victory02 || isVictory02(stats);
    set({
      settlers,
      resources: { ...res, comida: food },
      buildings,
      stats,
      colonos,
      growTimer,
      victory: won,
      victory02: won02,
      message: won02
        ? `¡Victoria Fase 02! ${WIN_TABLON} tablones + ${WIN_PAN} pan producidos.`
        : won
          ? `¡Victoria del slice! ${WIN_MADERA} madera + ${WIN_PIEDRA} piedra.`
          : st.message,
    });
  },

  reset: () =>
    set({
      resources: { ...emptyResources(), madera: 30, piedra: 15, comida: 10 },
      buildings: [{ id: nextId++, type: "centro", x: 0, z: 0, paused: false, progress: 0, blocked: false }],
      settlers: spawnSettlers(6),
      nodes: initialNodes,
      stats: { tablon: 0, pan: 0 },
      colonos: 6,
      victory: false,
      victory02: false,
      selected: null,
      demolish: false,
      ghost: null,
      growTimer: 30,
      message: "Partida reiniciada. Objetivo Fase 02: 20 tablones + 15 pan.",
    }),
}));

// Re-export para HUD
export { CASA_COLONOS };
