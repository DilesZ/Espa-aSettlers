"use client";

import { create } from "zustand";
import {
  AI_BASE,
  BUILDINGS,
  BUILDING_HP,
  BuildingType,
  CASA_COLONOS,
  MAX_SETTLERS,
  Placed,
  RAIDER_DPS,
  RAIDER_HP,
  RECIPES,
  RECRUIT_COST,
  RECRUIT_DPS,
  RECRUIT_HP,
  Recipe,
  Resources,
  TORRE_DPS,
  TORRE_RANGE,
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
import { FOG_N, computeFog, type Viewer } from "@/lib/fog";
import { playSound } from "@/lib/audio";

export type Building = {
  id: number;
  type: BuildingType;
  x: number;
  z: number;
  paused: boolean;
  progress: number;
  blocked: boolean;
  hp: number;
  maxHp: number;
  cd: number;
};
export type AiBuilding = { id: number; type: BuildingType; x: number; z: number; hp: number };
export type Raider = { id: number; x: number; z: number; hp: number; tx: number; tz: number; timer: number };
export type Recruit = { id: number; x: number; z: number; hp: number; tx: number; tz: number; timer: number };
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
  victory03: boolean;
  defeat: boolean;
  growTimer: number;
  // Fase 03: rival, combate, niebla
  raiders: Raider[];
  recruits: Recruit[];
  aiBuildings: AiBuilding[];
  aiQueue: number;
  aiBuildTimer: number;
  aiRaidTimer: number;
  elapsed: number;
  fog: number[];
  fogVersion: number;
  fogTimer: number;
  quality: "alto" | "medio" | "bajo";
  setQuality: (q: "alto" | "medio" | "bajo") => void;
  select: (t: BuildingType | null) => void;
  toggleDemolish: () => void;
  setGhost: (x: number, z: number) => void;
  place: (x: number, z: number) => void;
  clickBuilding: (id: number) => void;
  togglePause: (id: number) => void;
  trainRecruit: () => void;
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

function moveToward(x: number, z: number, tx: number, tz: number, step: number) {
  const dx = tx - x;
  const dz = tz - z;
  const d = Math.hypot(dx, dz);
  if (d < 0.5) return { arrived: true, x: tx, z: tz };
  return { arrived: false, x: x + (dx / d) * Math.min(step, d), z: z + (dz / d) * Math.min(step, d) };
}

/** Puestos de expansión IA en espiral alrededor de su base. */
const AI_QUEUE: BuildingType[] = [
  "granja",
  "aserradero",
  "casa",
  "torre",
  "molino",
  "panaderia",
  "casa",
  "torre",
  "granja",
  "aserradero",
];
const AI_OFFSETS: [number, number][] = [
  [7, 0],
  [-7, 2],
  [0, 7],
  [2, -7],
  [8, 6],
  [-6, -6],
  [6, -6],
  [-8, 6],
  [0, 10],
  [10, -2],
];

function mkBuilding(type: BuildingType, x: number, z: number): Building {
  const maxHp = BUILDING_HP[type];
  return { id: nextId++, type, x, z, paused: false, progress: 0, blocked: false, hp: maxHp, maxHp, cd: 0 };
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
  buildings: [mkBuilding("centro", 0, 0)],
  settlers: initialSettlers,
  nodes: initialNodes,
  stats: { tablon: 0, pan: 0 },
  selected: null,
  demolish: false,
  ghost: null,
  ghostError: null,
  message: "Fase 03: hay un rival al noreste. Objetivo final: destruye su Centro.",
  victory: false,
  victory02: false,
  victory03: false,
  defeat: false,
  growTimer: 30,
  raiders: [],
  recruits: [],
  aiBuildings: [{ id: nextId++, type: "centro", x: AI_BASE.x, z: AI_BASE.z, hp: 300 }],
  aiQueue: 0,
  aiBuildTimer: 35,
  aiRaidTimer: 45,
  elapsed: 0,
  fog: new Array(FOG_N * FOG_N).fill(0),
  fogVersion: 0,
  fogTimer: 0,
  quality: "alto",
  setQuality: (q) => set({ quality: q }),

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
    const b: Building = mkBuilding(selected, x, z);
    playSound("build");
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

  trainRecruit: () => {
    const { resources, colonos, buildings } = get();
    const casas = buildings.filter((b) => b.type === "casa").length;
    if (colonos >= Math.min(housingCap(casas), MAX_SETTLERS)) {
      set({ message: "Sin vivienda libre para reclutas. Construye casas." });
      return;
    }
    if (resources.comida < RECRUIT_COST) {
      set({ message: `Sin comida para reclutar (cuesta ${RECRUIT_COST}).` });
      return;
    }
    playSound("click");
    const r: Recruit = {
      id: nextId++,
      x: (Math.random() - 0.5) * 4,
      z: 4 + (Math.random() - 0.5) * 4,
      hp: RECRUIT_HP,
      tx: 0,
      tz: 4,
      timer: 0,
    };
    set({
      resources: { ...resources, comida: resources.comida - RECRUIT_COST },
      recruits: [...get().recruits, r],
      colonos: colonos + 1,
      message: "Recluta entrenado: buscará enemigos automáticamente.",
    });
  },

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

    if (madera + piedra > 0) playSound("coin");

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
    if ((won && !st.victory) || (won02 && !st.victory02)) playSound("win");

    // 4) Torres propias: fuego automático al raider más cercano
    let raiders = st.raiders.map((r) => ({ ...r }));
    let buildingsHP = buildings.map((b) => ({ ...b }));
    for (const t of buildingsHP) {
      if (t.type !== "torre" || t.paused) continue;
      t.cd -= capped;
      if (t.cd > 0) continue;
      const target = raiders
        .filter((r) => Math.hypot(r.x - t.x, r.z - t.z) <= TORRE_RANGE)
        .sort((a, b) => Math.hypot(a.x - t.x, a.z - t.z) - Math.hypot(b.x - t.x, b.z - t.z))[0];
      if (target) {
        target.hp -= TORRE_DPS * 1;
        t.cd = 1;
        playSound("hit");
      }
    }
    raiders = raiders.filter((r) => r.hp > 0);

    // 5) Reclutas: buscan enemigo (raider > edificios IA) y atacan
    let aiBuildings = st.aiBuildings.map((b) => ({ ...b }));
    const recruits = st.recruits.map((u) => ({ ...u }));
    const deadRecruits = new Set<number>();
    for (const u of recruits) {
      const foe = raiders
        .slice()
        .sort((a, b) => Math.hypot(a.x - u.x, a.z - u.z) - Math.hypot(b.x - u.x, b.z - u.z))[0];
      const targetB = aiBuildings
        .slice()
        .sort((a, b) => Math.hypot(a.x - u.x, a.z - u.z) - Math.hypot(b.x - u.x, b.z - u.z))[0];
      const tx = foe ? foe.x : (targetB?.x ?? u.x);
      const tz = foe ? foe.z : (targetB?.z ?? u.z);
      const m = moveToward(u.x, u.z, tx, tz, 6 * capped);
      u.x = m.x;
      u.z = m.z;
      if (m.arrived) {
        if (foe && Math.hypot(foe.x - u.x, foe.z - u.z) < 2) {
          foe.hp -= RECRUIT_DPS * capped;
          playSound("hit");
        } else if (!foe && targetB && Math.hypot(targetB.x - u.x, targetB.z - u.z) < 3) {
          targetB.hp -= RECRUIT_DPS * capped;
          playSound("hit");
        }
      }
      void u.tx;
      void u.tz;
    }
    raiders = raiders.filter((r) => r.hp > 0);

    // 6) Raiders IA: van al edificio propio más cercano y lo golpean
    for (const r of raiders) {
      const nearRec = recruits
        .filter((u) => !deadRecruits.has(u.id))
        .sort((a, b) => Math.hypot(a.x - r.x, a.z - r.z) - Math.hypot(b.x - r.x, b.z - r.z))[0];
      const nearB = buildingsHP
        .slice()
        .sort((a, b) => Math.hypot(a.x - r.x, a.z - r.z) - Math.hypot(b.x - r.x, b.z - r.z))[0];
      const dRec = nearRec ? Math.hypot(nearRec.x - r.x, nearRec.z - r.z) : Infinity;
      const dB = nearB ? Math.hypot(nearB.x - r.x, nearB.z - r.z) : Infinity;
      if (dRec < dB && nearRec) {
        const m = moveToward(r.x, r.z, nearRec.x, nearRec.z, 5 * capped);
        r.x = m.x;
        r.z = m.z;
        if (m.arrived && dRec < 2) {
          nearRec.hp -= RAIDER_DPS * capped;
          if (nearRec.hp <= 0) deadRecruits.add(nearRec.id);
        }
      } else if (nearB) {
        const m = moveToward(r.x, r.z, nearB.x, nearB.z, 5 * capped);
        r.x = m.x;
        r.z = m.z;
        if (m.arrived && dB < 2.5) {
          nearB.hp -= RAIDER_DPS * capped;
          playSound("hit");
        }
      }
      void r.tx;
      void r.tz;
      void r.timer;
    }
    const recruitsAlive = recruits.filter((u) => u.hp > 0 && !deadRecruits.has(u.id));
    const recruitDeaths = recruits.length - recruitsAlive.length;
    buildingsHP = buildingsHP.filter((b) => b.hp > 0);
    aiBuildings = aiBuildings.filter((b) => b.hp > 0);

    // Derrota / victoria total
    const centroAlive = buildingsHP.some((b) => b.type === "centro");
    const aiCentroAlive = aiBuildings.some((b) => b.type === "centro");
    const defeat =
      st.defeat ||
      !centroAlive ||
      (aiBuildings.length >= 10 && !won02 && !st.victory03);
    const won03 = st.victory03 || !aiCentroAlive;
    if (won03 && !st.victory03) playSound("win");

    // 7) IA: construye cada 35s y envía raiders cada 45s
    const elapsed = st.elapsed + capped;
    let aiQueue = st.aiQueue;
    let aiBuildTimer = st.aiBuildTimer - capped;
    if (aiBuildTimer <= 0 && aiQueue < AI_QUEUE.length) {
      aiBuildTimer = 35;
      const [ox, oz] = AI_OFFSETS[aiQueue % AI_OFFSETS.length];
      const type = AI_QUEUE[aiQueue % AI_QUEUE.length];
      aiBuildings = [
        ...aiBuildings,
        { id: nextId++, type, x: AI_BASE.x + ox, z: AI_BASE.z + oz, hp: BUILDING_HP[type] },
      ];
      aiQueue += 1;
    }
    let aiRaidTimer = st.aiRaidTimer - capped;
    let raidAlarm = false;
    const raidCap = Math.min(3 + Math.floor(elapsed / 120), 8);
    if (aiRaidTimer <= 0) {
      aiRaidTimer = 45;
      if (raiders.length < raidCap) {
        raiders = [
          ...raiders,
          { id: nextId++, x: AI_BASE.x, z: AI_BASE.z, hp: RAIDER_HP, tx: 0, tz: 0, timer: 0 },
        ];
        playSound("alarm");
        raidAlarm = true;
      }
    }

    // 8) Niebla cada 0.5s
    let fog = st.fog;
    let fogVersion = st.fogVersion;
    let fogTimer = st.fogTimer - capped;
    if (fogTimer <= 0) {
      fogTimer = 0.5;
      const viewers: Viewer[] = [
        ...buildingsHP.map((b) => ({
          x: b.x,
          z: b.z,
          range: b.type === "torre" ? 16 : 12,
        })),
        ...settlers.map((s) => ({ x: s.x, z: s.z, range: 8 })),
        ...recruitsAlive.map((u) => ({ x: u.x, z: u.z, range: 8 })),
      ];
      fog = computeFog(fog.length === FOG_N * FOG_N ? fog : new Array(FOG_N * FOG_N).fill(0), viewers);
      fogVersion += 1;
    }

    set({
      settlers,
      resources: { ...res, comida: food },
      buildings: buildingsHP,
      stats,
      colonos: colonos - recruitDeaths,
      recruits: recruitsAlive,
      raiders,
      aiBuildings,
      aiQueue,
      aiBuildTimer,
      aiRaidTimer,
      elapsed,
      fog,
      fogVersion,
      fogTimer,
      growTimer,
      victory: won,
      victory02: won02,
      victory03: won03,
      defeat,
      message: won03
        ? "¡Victoria total! Centro enemigo destruido."
        : defeat && !st.defeat
          ? aiBuildings.length >= 10
            ? "Derrota: la IA alcanzó Tier 3 antes que tú."
            : "Derrota: tu Centro ha caído."
          : raidAlarm
            ? "¡Incursión enemiga en camino!"
            : won02
            ? `¡Victoria Fase 02! ${WIN_TABLON} tablones + ${WIN_PAN} pan producidos.`
            : won
              ? `¡Victoria del slice! ${WIN_MADERA} madera + ${WIN_PIEDRA} piedra.`
              : get().message,
    });
  },

  reset: () =>
    set({
      resources: { ...emptyResources(), madera: 30, piedra: 15, comida: 10 },
      buildings: [mkBuilding("centro", 0, 0)],
      settlers: spawnSettlers(6),
      nodes: initialNodes,
      stats: { tablon: 0, pan: 0 },
      colonos: 6,
      victory: false,
      victory02: false,
      victory03: false,
      defeat: false,
      selected: null,
      demolish: false,
      ghost: null,
      growTimer: 30,
      raiders: [],
      recruits: [],
      aiBuildings: [{ id: nextId++, type: "centro", x: AI_BASE.x, z: AI_BASE.z, hp: 300 }],
      aiQueue: 0,
      aiBuildTimer: 35,
      aiRaidTimer: 45,
      elapsed: 0,
      fog: new Array(FOG_N * FOG_N).fill(0),
      fogVersion: 0,
      fogTimer: 0,
      quality: get().quality,
      message: "Partida reiniciada. Hay un rival al noreste: destruye su Centro.",
    }),
}));

// Re-export para HUD
export { CASA_COLONOS };
