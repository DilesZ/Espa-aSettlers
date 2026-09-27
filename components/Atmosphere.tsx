"use client";

import { useRef } from "react";
import { useFrame } from "@react-three/fiber";
import { Sparkles } from "@react-three/drei";
import * as THREE from "three";
import { RECIPES } from "@/lib/economy";
import { useGame } from "@/store/game";
import { dayRef } from "@/components/DayNight";

/** Dos láminas de agua sobre el río (x=27) con deriva en z opuesta + pulso de opacidad. */
export function WaterFX() {
  const mesh1 = useRef<THREE.Mesh>(null);
  const mesh2 = useRef<THREE.Mesh>(null);
  const mat1 = useRef<THREE.MeshStandardMaterial>(null);
  const mat2 = useRef<THREE.MeshStandardMaterial>(null);

  useFrame(({ clock }) => {
    const t = clock.elapsedTime;
    if (mesh1.current) mesh1.current.position.z = Math.sin(t * 0.3) * 1.5;
    if (mesh2.current) mesh2.current.position.z = Math.cos(t * 0.3) * 1.5;
    if (mat1.current) mat1.current.opacity = 0.55 + Math.sin(t * 1.2) * 0.08;
    if (mat2.current) mat2.current.opacity = 0.3 + Math.cos(t * 1.2) * 0.06;
  });

  return (
    <group>
      <mesh ref={mesh1} rotation={[-Math.PI / 2, 0, 0]} position={[27, 0.06, 0]}>
        <planeGeometry args={[10, 64]} />
        <meshStandardMaterial
          ref={mat1}
          color="#3a86ff"
          transparent
          opacity={0.55}
          roughness={0.25}
          metalness={0.35}
          depthWrite={false}
        />
      </mesh>
      <mesh ref={mesh2} rotation={[-Math.PI / 2, 0, 0]} position={[27, 0.1, 0]}>
        <planeGeometry args={[10, 64]} />
        <meshStandardMaterial
          ref={mat2}
          color="#3a86ff"
          transparent
          opacity={0.3}
          roughness={0.2}
          metalness={0.4}
          depthWrite={false}
        />
      </mesh>
    </group>
  );
}

/** Humo/chispas sobre edificios productivos no pausados. */
export function Chimneys() {
  const buildings = useGame((s) => s.buildings);
  const activos = buildings.filter((b) => RECIPES[b.type] != null && !b.paused);
  return (
    <group>
      {activos.map((b) => (
        <Sparkles
          key={b.id}
          count={12}
          scale={[1.5, 2.5, 1.5]}
          size={3}
          speed={0.25}
          color="#cfd8dc"
          position={[b.x, 3, b.z]}
        />
      ))}
    </group>
  );
}

/** Luciérnagas amarillas visibles solo de noche (dayRef.v < 0.35). */
export function Fireflies() {
  const group = useRef<THREE.Group>(null);

  useFrame(() => {
    if (group.current) group.current.visible = dayRef.v < 0.35;
  });

  return (
    <group ref={group}>
      <Sparkles count={30} scale={[40, 6, 40]} size={2.5} speed={0.4} color="#ffe66d" />
    </group>
  );
}

export default function Atmosphere() {
  return (
    <group>
      <WaterFX />
      <Chimneys />
      <Fireflies />
    </group>
  );
}
