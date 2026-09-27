"use client";

import { Canvas, useFrame, ThreeEvent } from "@react-three/fiber";
import { Grid, OrbitControls } from "@react-three/drei";
import { useRef } from "react";
import * as THREE from "three";
import { BUILDINGS } from "@/lib/economy";
import { useGame } from "@/store/game";

function Sim() {
  const tick = useGame((s) => s.tick);
  useFrame((_, delta) => tick(delta));
  return null;
}

function Terrain() {
  const place = useGame((s) => s.place);
  const setGhost = useGame((s) => s.setGhost);
  const selected = useGame((s) => s.selected);
  const onMove = (e: ThreeEvent<PointerEvent>) => {
    if (selected) setGhost(e.point.x, e.point.z);
  };
  const onDown = (e: ThreeEvent<MouseEvent>) => {
    if (selected && e.button === 0) place(e.point.x, e.point.z);
  };
  return (
    <group>
      {/* Suelo */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow onPointerMove={onMove} onPointerDown={onDown}>
        <planeGeometry args={[64, 64]} />
        <meshStandardMaterial color="#1c2b1a" roughness={1} />
      </mesh>
      {/* Río (agua, inválido) */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[27, 0.05, 0]}>
        <planeGeometry args={[10, 64]} />
        <meshStandardMaterial color="#1d4e89" roughness={0.3} metalness={0.4} />
      </mesh>
      <Grid infiniteGrid={false} args={[64, 64]} sectionColor="#31572c" cellColor="#22331f" position={[0, 0.02, 0]} fadeDistance={80} />
    </group>
  );
}

function Buildings() {
  const buildings = useGame((s) => s.buildings);
  const ghost = useGame((s) => s.ghost);
  const ghostError = useGame((s) => s.ghostError);
  const selected = useGame((s) => s.selected);
  return (
    <group>
      {buildings.map((b) => (
        <group key={b.id} position={[b.x, 0, b.z]}>
          <mesh position={[0, 1, 0]} castShadow>
            <boxGeometry args={[BUILDINGS[b.type].radio * 1.6, 2, BUILDINGS[b.type].radio * 1.6]} />
            <meshStandardMaterial color={BUILDINGS[b.type].color} roughness={0.8} />
          </mesh>
          <mesh position={[0, 2.4, 0]}>
            <coneGeometry args={[BUILDINGS[b.type].radio * 1.3, 1.4, 4]} />
            <meshStandardMaterial color="#7f4f24" roughness={0.9} />
          </mesh>
        </group>
      ))}
      {selected && ghost && (
        <mesh position={[ghost.x, 1, ghost.z]}>
          <boxGeometry args={[2.5, 2, 2.5]} />
          <meshStandardMaterial color={ghostError ? "#e63946" : "#80ed99"} transparent opacity={0.6} />
        </mesh>
      )}
    </group>
  );
}

function Settlers() {
  const settlers = useGame((s) => s.settlers);
  return (
    <group>
      {settlers.map((st) => (
        <group key={st.id} position={[st.x, 0, st.z]}>
          <mesh position={[0, 0.5, 0]} castShadow>
            <capsuleGeometry args={[0.3, 0.7, 4, 8]} />
            <meshStandardMaterial color={st.carry ? "#ffd166" : "#f1fa8c"} roughness={0.7} />
          </mesh>
          {st.carry && (
            <mesh position={[0, 1.3, 0]}>
              <boxGeometry args={[0.4, 0.4, 0.4]} />
              <meshStandardMaterial color={st.carry === "madera" ? "#8b5a2b" : "#999"} />
            </mesh>
          )}
        </group>
      ))}
    </group>
  );
}

function Nodes() {
  const nodes = useGame((s) => s.nodes);
  return (
    <group>
      {nodes.map((n) =>
        n.kind === "tree" ? (
          <group key={n.id} position={[n.x, 0, n.z]}>
            <mesh position={[0, 0.6, 0]}>
              <cylinderGeometry args={[0.2, 0.3, 1.2, 6]} />
              <meshStandardMaterial color="#6b4423" />
            </mesh>
            <mesh position={[0, 1.8, 0]}>
              <coneGeometry args={[1, 1.8, 7]} />
              <meshStandardMaterial color="#2d6a4f" roughness={0.9} />
            </mesh>
          </group>
        ) : (
          <group key={n.id} position={[n.x, 0.4, n.z]}>
            <mesh castShadow>
              <dodecahedronGeometry args={[0.9, 0]} />
              <meshStandardMaterial color="#8d99ae" roughness={1} flatShading />
            </mesh>
          </group>
        ),
      )}
    </group>
  );
}

export default function WorldCanvas() {
  const ref = useRef<THREE.Group>(null);
  return (
    <Canvas
      shadows
      dpr={[1, 1.75]}
      camera={{ position: [20, 16, 20], fov: 50 }}
      gl={{ antialias: true, powerPreference: "high-performance" }}
      style={{ width: "100%", height: "100%" }}
    >
      <color attach="background" args={["#0b1526"]} />
      <hemisphereLight intensity={0.7} />
      <directionalLight position={[12, 20, 8]} intensity={1.3} castShadow shadow-mapSize={[2048, 2048]} />
      <Sim />
      <group ref={ref}>
        <Terrain />
        <Buildings />
        <Nodes />
        <Settlers />
      </group>
      <OrbitControls makeDefault maxPolarAngle={Math.PI / 2.15} />
    </Canvas>
  );
}
