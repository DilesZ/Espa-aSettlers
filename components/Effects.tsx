"use client";

import { Bloom, EffectComposer, Vignette } from "@react-three/postprocessing";
import { useGame } from "@/store/game";

export function Effects() {
  const quality = useGame((s) => s.quality);

  if (quality === "bajo") return null;

  if (quality === "medio") {
    return (
      <EffectComposer>
        <Vignette darkness={0.35} />
      </EffectComposer>
    );
  }

  return (
    <EffectComposer>
      <Bloom intensity={0.35} luminanceThreshold={0.75} luminanceSmoothing={0.2} mipmapBlur />
      <Vignette darkness={0.35} />
    </EffectComposer>
  );
}

export default Effects;
