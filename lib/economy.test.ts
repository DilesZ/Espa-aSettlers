import { describe, expect, it } from "vitest";
import {
  BUILDINGS,
  canAfford,
  isVictory,
  payCost,
  placementError,
} from "./economy";

describe("economía fase 01", () => {
  it("centro gratis, casa cuesta 15/5", () => {
    expect(canAfford({ madera: 0, piedra: 0, comida: 0 }, "centro")).toBe(true);
    expect(canAfford({ madera: 14, piedra: 5, comida: 0 }, "casa")).toBe(false);
    expect(canAfford({ madera: 15, piedra: 5, comida: 0 }, "casa")).toBe(true);
  });

  it("payCost descuenta", () => {
    const r = payCost({ madera: 20, piedra: 10, comida: 0 }, "almacen");
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
    expect(isVictory({ madera: 50, piedra: 30, comida: 0 })).toBe(true);
    expect(isVictory({ madera: 49, piedra: 30, comida: 0 })).toBe(false);
    expect(BUILDINGS.lenador).toBeDefined();
  });
});
