"use client";

import { useEffect, useRef } from "react";
import * as THREE from "three";
import { useGame } from "@/store/game";
import { FOG_CELL, FOG_N } from "@/lib/fog";

const CAPACITY = FOG_N * FOG_N; // 1024
const Y = 0.15;

export default function FogOverlay() {
  const fog = useGame((s) => s.fog);
  const fogVersion = useGame((s) => s.fogVersion);
  const refUnexplored = useRef<THREE.InstancedMesh>(null);
  const refExplored = useRef<THREE.InstancedMesh>(null);

  useEffect(() => {
    const m0 = refUnexplored.current;
    const m1 = refExplored.current;
    if (!m0 || !m1 || !fog) return;
    const dummy = new THREE.Object3D();
    // Plano 2x2 (XY) -> horizontal (XZ); la malla aporta la altura y=0.15.
    dummy.rotation.set(-Math.PI / 2, 0, 0);
    let n0 = 0;
    let n1 = 0;
    for (let i = 0; i < fog.length; i++) {
      const v = fog[i];
      if (v !== 0 && v !== 1) continue; // 2=visible no se renderiza
      const cx = i % FOG_N;
      const cz = Math.floor(i / FOG_N);
      const x = cx * FOG_CELL - 31;
      const z = cz * FOG_CELL - 31;
      dummy.position.set(x, 0, z);
      dummy.updateMatrix();
      if (v === 0) {
        if (n0 >= CAPACITY) continue;
        m0.setMatrixAt(n0, dummy.matrix);
        n0 += 1;
      } else {
        if (n1 >= CAPACITY) continue;
        m1.setMatrixAt(n1, dummy.matrix);
        n1 += 1;
      }
    }
    m0.count = n0;
    m1.count = n1;
    m0.instanceMatrix.needsUpdate = true;
    m1.instanceMatrix.needsUpdate = true;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fogVersion]);

  return (
    <group>
      <instancedMesh
        ref={refUnexplored}
        args={[undefined, undefined, CAPACITY]}
        position={[0, Y, 0]}
        frustumCulled={false}
      >
        <planeGeometry args={[FOG_CELL, FOG_CELL]} />
        <meshBasicMaterial color="black" transparent opacity={0.85} depthWrite={false} />
      </instancedMesh>
      <instancedMesh
        ref={refExplored}
        args={[undefined, undefined, CAPACITY]}
        position={[0, Y, 0]}
        frustumCulled={false}
      >
        <planeGeometry args={[FOG_CELL, FOG_CELL]} />
        <meshBasicMaterial color="black" transparent opacity={0.4} depthWrite={false} />
      </instancedMesh>
    </group>
  );
}
