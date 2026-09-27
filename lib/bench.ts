export type BenchSample = {
  fps: number;
  ms: number;
  drawCalls: number;
  triangles: number;
};

export function collectBenchSample(renderer: {
  info: { render: { calls: number; triangles: number } };
}): Pick<BenchSample, "drawCalls" | "triangles"> {
  return {
    drawCalls: renderer.info.render.calls,
    triangles: renderer.info.render.triangles,
  };
}

export function summarize(samples: BenchSample[]) {
  const avg = (xs: number[]) => xs.reduce((a, b) => a + b, 0) / Math.max(1, xs.length);
  return {
    fps: avg(samples.map((s) => s.fps)),
    ms: avg(samples.map((s) => s.ms)),
    drawCalls: avg(samples.map((s) => s.drawCalls)),
    triangles: avg(samples.map((s) => s.triangles)),
    n: samples.length,
  };
}
