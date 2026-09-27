"use client";

import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls, Grid, Stats } from "@react-three/drei";
import { useRef } from "react";
import * as THREE from "three";

function SpinningMarker() {
  const ref = useRef<THREE.Mesh>(null);
  useFrame((_, delta) => {
    if (ref.current) ref.current.rotation.y += delta * 0.5;
  });
  return (
    <mesh ref={ref} position={[0, 1, 0]}>
      <boxGeometry args={[2, 2, 2]} />
      <meshStandardMaterial color="#4f772d" roughness={0.8} />
    </mesh>
  );
}

/** Greybox fundación: terreno + marcador. Escala real S6 vendrá en Fase 01. */
export default function WorldCanvas() {
  return (
    <Canvas
      shadows
      dpr={[1, 1.75]}
      camera={{ position: [18, 14, 18], fov: 50 }}
      gl={{ antialias: true, powerPreference: "high-performance" }}
      style={{ width: "100%", height: "100%" }}
    >
      <color attach="background" args={["#0b1526"]} />
      <hemisphereLight intensity={0.7} />
      <directionalLight position={[10, 18, 6]} intensity={1.2} castShadow />
      <SpinningMarker />
      <mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[64, 64]} />
        <meshStandardMaterial color="#1c2b1a" roughness={1} />
      </mesh>
      <Grid infiniteGrid sectionColor="#31572c" cellColor="#22331f" fadeDistance={70} />
      <OrbitControls makeDefault maxPolarAngle={Math.PI / 2.1} />
      {process.env.NODE_ENV === "development" ? <Stats /> : null}
    </Canvas>
  );
}
