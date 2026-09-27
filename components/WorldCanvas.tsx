"use client";

import { Canvas, useFrame, ThreeEvent } from "@react-three/fiber";
import { Grid, OrbitControls } from "@react-three/drei";
import { useRef } from "react";
import * as THREE from "three";
import { BUILDINGS } from "@/lib/economy";
import { useGame, type Building } from "@/store/game";

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

/** Mezcla un color hex con #555555 para estado en pausa (gris apagado). */
function mutedColor(hex: string): string {
  const c = new THREE.Color(hex);
  c.lerp(new THREE.Color("#555555"), 0.6);
  return `#${c.getHexString()}`;
}

/** Aspas simples del molino: caja rotando vía useFrame en subcomponente. */
function MillBlades({ paused, front }: { paused: boolean; front: number }) {
  const ref = useRef<THREE.Group>(null);
  useFrame((_, delta) => {
    if (ref.current && !paused) ref.current.rotation.z += delta * 2.5;
  });
  return (
    <group ref={ref} position={[0, 2.5, front]}>
      <mesh castShadow>
        <boxGeometry args={[0.18, 2.4, 0.18]} />
        <meshStandardMaterial color="#f8f9fa" roughness={0.6} />
      </mesh>
      <mesh rotation={[0, 0, Math.PI / 2]} castShadow>
        <boxGeometry args={[0.18, 2.4, 0.18]} />
        <meshStandardMaterial color="#f8f9fa" roughness={0.6} />
      </mesh>
    </group>
  );
}

function BuildingItem({
  b,
  demolish,
  onSelect,
}: {
  b: Building;
  demolish: boolean;
  onSelect: (id: number) => void;
}) {
  const pulseRef = useRef<THREE.Group>(null);
  // Se lee progress vía prop (closure del render), sin suscribir la store dentro del frame.
  const progress = b.progress;
  const paused = b.paused;

  useFrame(({ clock }) => {
    if (!pulseRef.current) return;
    if (!paused && progress > 0) {
      const s = 1 + 0.04 * Math.sin(clock.elapsedTime * 4);
      pulseRef.current.scale.setScalar(s);
    } else if (pulseRef.current.scale.x !== 1) {
      pulseRef.current.scale.setScalar(1);
    }
  });

  const base = BUILDINGS[b.type].color;
  const color = paused ? mutedColor(base) : base;
  const size = BUILDINGS[b.type].radio * 1.6;
  const roofR = BUILDINGS[b.type].radio * 1.3;

  const handleClick = (e: ThreeEvent<MouseEvent>) => {
    e.stopPropagation();
    onSelect(b.id);
  };
  const handleOver = (e: ThreeEvent<PointerEvent>) => {
    e.stopPropagation();
    if (demolish) document.body.style.cursor = "pointer";
  };
  const handleOut = () => {
    document.body.style.cursor = "auto";
  };

  return (
    <group position={[b.x, 0, b.z]}>
      <group ref={pulseRef}>
        <mesh
          position={[0, 1, 0]}
          castShadow
          onClick={handleClick}
          onPointerOver={handleOver}
          onPointerOut={handleOut}
        >
          <boxGeometry args={[size, 2, size]} />
          <meshStandardMaterial color={color} roughness={0.8} />
        </mesh>
        <mesh position={[0, 2.4, 0]}>
          <coneGeometry args={[roofR, 1.4, 4]} />
          <meshStandardMaterial color={paused ? "#555555" : "#7f4f24"} roughness={0.9} />
        </mesh>
        {b.type === "molino" && <MillBlades paused={paused} front={size / 2 + 0.15} />}
      </group>
    </group>
  );
}

function Buildings() {
  const buildings = useGame((s) => s.buildings);
  const ghost = useGame((s) => s.ghost);
  const ghostError = useGame((s) => s.ghostError);
  const selected = useGame((s) => s.selected);
  const demolish = useGame((s) => s.demolish);
  const clickBuilding = useGame((s) => s.clickBuilding);
  const ghostSize = selected ? BUILDINGS[selected].radio * 1.6 : 2.5;
  return (
    <group>
      {buildings.map((b) => (
        <BuildingItem key={b.id} b={b} demolish={demolish} onSelect={clickBuilding} />
      ))}
      {selected && ghost && (
        <mesh position={[ghost.x, 1, ghost.z]}>
          <boxGeometry args={[ghostSize, 2, ghostSize]} />
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
