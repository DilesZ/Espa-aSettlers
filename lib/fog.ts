/** Niebla de guerra: grid 32x32 sobre mapa 64x64 (celda 2m). 0=inexplorado,1=explorado,2=visible. */

export const FOG_N = 32;
export const FOG_CELL = 2;

export function cellOf(x: number, z: number): number {
  const cx = Math.max(0, Math.min(FOG_N - 1, Math.floor((x + 32) / FOG_CELL)));
  const cz = Math.max(0, Math.min(FOG_N - 1, Math.floor((z + 32) / FOG_CELL)));
  return cz * FOG_N + cx;
}

export type Viewer = { x: number; z: number; range: number };

export function computeFog(prev: number[], viewers: Viewer[]): number[] {
  const next = prev.slice();
  // Decae visible->explorado
  for (let i = 0; i < next.length; i++) if (next[i] === 2) next[i] = 1;
  for (const v of viewers) {
    const r = Math.ceil(v.range / FOG_CELL);
    const ccx = Math.floor((v.x + 32) / FOG_CELL);
    const ccz = Math.floor((v.z + 32) / FOG_CELL);
    for (let dz = -r; dz <= r; dz++) {
      for (let dx = -r; dx <= r; dx++) {
        const cx = ccx + dx;
        const cz = ccz + dz;
        if (cx < 0 || cz < 0 || cx >= FOG_N || cz >= FOG_N) continue;
        if (Math.hypot(dx * FOG_CELL, dz * FOG_CELL) <= v.range) next[cz * FOG_N + cx] = 2;
      }
    }
  }
  return next;
}

export function isCellVisible(fog: number[], x: number, z: number): boolean {
  return fog[cellOf(x, z)] === 2;
}
