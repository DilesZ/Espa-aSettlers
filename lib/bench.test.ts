import { describe, expect, it } from "vitest";
import { summarize } from "./bench";

describe("bench summarize", () => {
  it("promedia muestras", () => {
    const r = summarize([
      { fps: 120, ms: 8.3, drawCalls: 10, triangles: 5000 },
      { fps: 60, ms: 16.6, drawCalls: 20, triangles: 9000 },
    ]);
    expect(r.n).toBe(2);
    expect(r.fps).toBeCloseTo(90);
    expect(r.drawCalls).toBeCloseTo(15);
  });
});
