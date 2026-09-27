import { describe, expect, it } from "vitest";
import {
  BUILDINGS,
  RECIPES,
  canAfford,
  emptyResources,
  housingCap,
  isVictory,
  isVictory02,
  payCost,
  placementError,
  simulateProduction,
  storageCap,
} from "./economy";

const res = (p: Partial<ReturnType<typeof emptyResources>>) => ({ ...emptyResources(), ...p });

describe("economía fase 01 (regresión)", () => {
  it("centro gratis, casa cuesta 15/5", () => {
    expect(canAfford(res({}), "centro")).toBe(true);
    expect(canAfford(res({ madera: 14, piedra: 5 }), "casa")).toBe(false);
    expect(canAfford(res({ madera: 15, piedra: 5 }), "casa")).toBe(true);
  });

  it("payCost descuenta", () => {
    const r = payCost(res({ madera: 20, piedra: 10 }), "almacen");
    expect(r.madera).toBe(0);
    expect(r.piedra).toBe(0);
  });

  it("placement rechaza agua, borde y colisión", () => {
    expect(placementError(25, 0, "casa", [])).toBe("En el agua");
    expect(placementError(40, 0, "casa", [])).toBe("Fuera del mapa");
    expect(placementError(0, 0, "casa", [{ x: 1, z: 1, radio: 3 }])).toBe(
      "Colisiona con otro edificio",
    );
    expect(placementError(-10, -10, "casa", [])).toBeNull();
  });

  it("victoria 50/30", () => {
    expect(isVictory(res({ madera: 50, piedra: 30 }))).toBe(true);
    expect(isVictory(res({ madera: 49, piedra: 30 }))).toBe(false);
    expect(BUILDINGS.lenador).toBeDefined();
  });
});

describe("economía fase 02", () => {
  it("pescador exige cercanía al río", () => {
    expect(placementError(0, 0, "pescador", [])).toBe(
      "El pescador debe estar junto al río (x≥12)",
    );
    expect(placementError(15, 0, "pescador", [])).toBeNull();
  });

  it("throughput aserradero ±10%: 1 tronco/15s -> 2 tablones", () => {
    const r = RECIPES.aserradero!;
    const out = simulateProduction(r, res({ madera: 100 }), 300);
    // 300s/15s = 20 tandas -> 40 tablones, 80 madera consumida
    expect(out.batches).toBe(20);
    expect(out.stock.tablon).toBe(40);
    expect(out.stock.madera).toBe(80);
  });

  it("cadena pan encadenada: trigo->harina->pan", () => {
    const trigo = simulateProduction(RECIPES.granja!, res({}), 200);
    expect(trigo.batches).toBe(10); // 200/20
    const harina = simulateProduction(RECIPES.molino!, trigo.stock, 120);
    expect(harina.batches).toBe(10); // 120/12, trigo justo
    const pan = simulateProduction(RECIPES.panaderia!, harina.stock, 150);
    expect(pan.batches).toBe(10);
    expect(pan.stock.pan).toBe(10);
    expect(pan.stock.comida).toBe(50);
  });

  it("sin inputs no produce (bloqueo)", () => {
    const out = simulateProduction(RECIPES.molino!, res({}), 600);
    expect(out.batches).toBe(0);
  });

  it("caps: almacén +100, casa +4 colonos", () => {
    expect(storageCap(0)).toBe(200);
    expect(storageCap(2)).toBe(400);
    expect(housingCap(0)).toBe(6);
    expect(housingCap(3)).toBe(18);
  });

  it("victoria02 20 tablones + 15 pan acumulados", () => {
    expect(isVictory02({ tablon: 20, pan: 15 })).toBe(true);
    expect(isVictory02({ tablon: 19, pan: 15 })).toBe(false);
  });
});
