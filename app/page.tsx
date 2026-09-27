import WorldCanvas from "@/components/WorldCanvas";
import HUD from "@/components/HUD";
import Minimap from "@/components/Minimap";

export const metadata = {
  title: "EspañaSettlers — Fase 02 Economía",
  description: "Cadenas madera y pan, 10 edificios, colonos. Objetivo 20 tablones + 15 pan.",
};

export default function Home() {
  return (
    <div className="flex min-h-screen flex-col gap-4 bg-[#0b1526] p-6 text-zinc-100">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold">EspañaSettlers — Fase 02 Economía</h1>
          <p className="text-sm text-zinc-400">
            Cámara: arrastrar / rueda zoom / clic derecho rotar. Construir: elige edificio y clic.
            Demoler: modo demoler + clic en edificio.
          </p>
        </div>
        <div className="flex items-center gap-4">
          <Minimap />
          <a className="text-sm underline" href="/benchmark/">
            Benchmark
          </a>
        </div>
      </header>
      <HUD />
      <main className="relative min-h-[68vh] flex-1 overflow-hidden rounded-xl border border-white/10">
        <WorldCanvas />
      </main>
    </div>
  );
}
