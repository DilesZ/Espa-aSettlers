import WorldCanvas from "@/components/WorldCanvas";
import HUD from "@/components/HUD";

export const metadata = {
  title: "EspañaSettlers — Slice 01 jugable",
  description: "1 mapa, recolección, 5 edificios, colonos. Objetivo 50/30.",
};

export default function Home() {
  return (
    <div className="flex min-h-screen flex-col gap-4 bg-[#0b1526] p-6 text-zinc-100">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold">EspañaSettlers — Fase 01 Vertical Slice</h1>
          <p className="text-sm text-zinc-400">
            Cámara: arrastrar / rueda zoom / clic derecho rotar. Construir: elige edificio y clic.
          </p>
        </div>
        <a className="text-sm underline" href="/benchmark/">
          Benchmark
        </a>
      </header>
      <HUD />
      <main className="relative min-h-[68vh] flex-1 overflow-hidden rounded-xl border border-white/10">
        <WorldCanvas />
      </main>
    </div>
  );
}
