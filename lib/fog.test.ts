import { describe, expect, it } from "vitest";
import { FOG_N, cellOf, computeFog, isCellVisible } from "./fog";

describe("niebla de guerra", () => {
  it("celda centro y esquinas", () => {
    expect(cellOf(0, 0)).toBe(16 * FOG_N + 16);
    expect(cellOf(-40, -40)).toBe(0);
    expect(cellOf(40, 40)).toBe(FOG_N * FOG_N - 1);
  });

  it("viewer revela y el resto decae a explorado", () => {
    const prev = new Array(FOG_N * FOG_N).fill(0);
    const v1 = computeFog(prev, [{ x: 0, z: 0, range: 8 }]);
    expect(isCellVisible(v1, 0, 0)).toBe(true);
    expect(isCellVisible(v1, 20, 20)).toBe(false);
    const v2 = computeFog(v1, []);
    expect(v2[16 * FOG_N + 16]).toBe(1); // explorado, no visible
  });

  it("torre ve más lejos que colono", () => {
    const prev = new Array(FOG_N * FOG_N).fill(0);
    expect(isCellVisible(computeFog(prev, [{ x: 0, z: 0, range: 5 }]), 0, 7)).toBe(false);
    expect(isCellVisible(computeFog(prev, [{ x: 0, z: 0, range: 16 }]), 0, 7)).toBe(true);
  });
});
