"use client";

import { useRef } from "react";
import { useFrame } from "@react-three/fiber";
import * as THREE from "three";

/** Factor día (1) .. noche (0) compartido por módulo, actualizado cada frame. */
export const dayRef = { v: 1 };

/** Lee el factor día actual: 0 (noche) .. 1 (día). Pensado para usar dentro de loops/mutaciones, no dispara re-render. */
export function useDayFactor(): number {
  return dayRef.v;
}

const CYCLE = 240; // segundos por ciclo día/noche
const RADIUS = 30;

const NIGHT = new THREE.Color("#060b18");
const DAY = new THREE.Color("#87b5e0");
const SUNSET = new THREE.Color("#e8956b");
const SUN_DAY = new THREE.Color("#fff4e0");
const SUN_SET = new THREE.Color("#ff9a3c");

const _bg = new THREE.Color();
const _sun = new THREE.Color();

export function DayNight() {
  const dirRef = useRef<THREE.DirectionalLight>(null!);
  const hemiRef = useRef<THREE.HemisphereLight>(null!);
  const bgRef = useRef<THREE.Color>(null!);

  useFrame((state) => {
    const elapsed = state.clock.elapsedTime;
    const angle = (elapsed * Math.PI * 2) / CYCLE;
    const s = Math.sin(angle); // altura del sol: 1 cenit, -1 nadir, 0 horizonte
    const dayFactor = THREE.MathUtils.clamp((s + 1) / 2, 0, 1);
    dayRef.v = dayFactor;

    const dir = dirRef.current;
    if (dir) {
      dir.position.set(Math.cos(angle) * RADIUS, s * RADIUS, 12);
      dir.intensity = 0.05 + dayFactor * (1.3 - 0.05);
      // Cálido al amanecer/atardecer (sol bajo), blanco cuando está alto.
      const warmth = THREE.MathUtils.clamp(1 - Math.abs(s) * 2.5, 0, 1);
      dir.color.copy(_sun.lerpColors(SUN_DAY, SUN_SET, warmth));
    }

    const hemi = hemiRef.current;
    if (hemi) {
      hemi.intensity = 0.1 + dayFactor * (0.7 - 0.1);
    }

    if (bgRef.current) {
      if (s >= 0) {
        bgRef.current.copy(_bg.lerpColors(SUNSET, DAY, THREE.MathUtils.clamp(s * 2, 0, 1)));
      } else {
        bgRef.current.copy(_bg.lerpColors(SUNSET, NIGHT, THREE.MathUtils.clamp(-s * 2, 0, 1)));
      }
    }
  });

  return (
    <>
      <directionalLight
        ref={dirRef}
        castShadow
        position={[RADIUS, RADIUS, 12]}
        intensity={1.3}
        color="#fff4e0"
        shadow-mapSize-width={2048}
        shadow-mapSize-height={2048}
        shadow-camera-left={-40}
        shadow-camera-right={40}
        shadow-camera-top={40}
        shadow-camera-bottom={-40}
        shadow-camera-near={1}
        shadow-camera-far={100}
      />
      <hemisphereLight ref={hemiRef} args={["#bfd9ff", "#3a4a3a", 0.7]} />
      <color ref={bgRef} attach="background" args={["#87b5e0"]} />
    </>
  );
}

export default DayNight;
