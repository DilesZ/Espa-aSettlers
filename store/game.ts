"use client";

import { create } from "zustand";
import {
  BUILDINGS,
  BuildingType,
  Placed,
  Resources,
  WIN_MADERA,
  WIN_PIEDRA,
  canAfford,
  isVictory,
  payCost,
  placementError,
} from "@/lib/economy";

export type Building = { id: number; type: BuildingType; x: number; z: number };
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

type GameState = {
  resources: Resources;
  colonos: number;
  buildings: Building[];
  settlers: Settler[];
  nodes: Node[];
  selected: BuildingType | null;
  ghost: { x: number; z: number } | null;
  ghostError: string | null;
  message: string | null;
  victory: boolean;
  select: (t: BuildingType | null) => void;
  setGhost: (x: number, z: number) => void;
  place: (x: number, z: number) => void;
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
      // Alterna madera/piedra según lo que falte para la victoria
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

export const useGame = create<GameState>((set, get) => ({
  resources: { madera: 30, piedra: 15, comida: 10 },
  colonos: 6,
  buildings: [{ id: nextId++, type: "centro", x: 0, z: 0 }],
  settlers: initialSettlers,
  nodes: initialNodes,
  selected: null,
  ghost: null,
  ghostError: null,
  message: "Selecciona un edificio y haz clic en el terreno. Objetivo: 50 madera + 30 piedra.",
  victory: false,

  select: (t) => set({ selected: t, ghost: null, ghostError: null }),

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
    const b: Building = { id: nextId++, type: selected, x, z };
    set({
      resources: payCost(resources, selected),
      buildings: [...buildings, b],
      message: `${BUILDINGS[selected].nombre} construido.`,
      selected: null,
      ghost: null,
      ghostError: null,
    });
  },

  tick: (dt) => {
    const { settlers, nodes, resources, victory } = get();
    const capped = Math.min(dt, 0.1);
    let madera = 0;
    let piedra = 0;
    const next = settlers.map((s) => {
      const ns = stepSettler(s, nodes, capped);
      // Entrega al llegar al centro
      if (s.state === "return" && Math.hypot(ns.x - 0, ns.z - 2) < 0.5 && s.carry) {
        if (s.carry === "madera") madera += 5;
        else piedra += 4;
        return { ...ns, state: "idle" as const, carry: null, timer: 0.5 };
      }
      return ns;
    });
    const res = {
      madera: resources.madera + madera,
      piedra: resources.piedra + piedra,
      comida: resources.comida,
    };
    const won = victory || isVictory(res);
    set({
      settlers: next,
      resources: res,
      victory: won,
      message: won
        ? `¡Victoria del slice! ${WIN_MADERA} madera + ${WIN_PIEDRA} piedra conseguidos.`
        : get().message,
    });
  },

  reset: () =>
    set({
      resources: { madera: 30, piedra: 15, comida: 10 },
      buildings: [{ id: nextId++, type: "centro", x: 0, z: 0 }],
      settlers: spawnSettlers(6),
      nodes: initialNodes,
      victory: false,
      selected: null,
      ghost: null,
      message: "Partida reiniciada. Objetivo: 50 madera + 30 piedra.",
    }),
}));
