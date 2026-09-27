import WorldCanvas from "@/components/WorldCanvas";

export const metadata = {
  title: "EspañaSettlers — Fundación 00",
  description: "Boot Next.js + R3F. Vertical slice en Fase 01.",
};

export default function Home() {
  return (
    <div className="flex min-h-screen flex-col bg-[#0b1526] text-zinc-100">
      <header className="flex items-center justify-between px-6 py-4">
        <div>
          <h1 className="text-xl font-semibold">EspañaSettlers — Fase 00 Fundación</h1>
          <p className="text-sm text-zinc-400">
            Boot R3F verificado. Gameplay real en Fase 01 (vertical slice).
          </p>
        </div>
        <nav className="flex gap-4 text-sm">
          <a className="underline" href="/benchmark/">
            Benchmark
          </a>
          <a
            className="underline"
            href="https://github.com/DilesZ/Espa-aSettlers.git"
            target="_blank"
            rel="noreferrer"
          >
            Repo
          </a>
        </nav>
      </header>
      <main className="relative mx-6 mb-6 min-h-[70vh] flex-1 overflow-hidden rounded-xl border border-white/10">
        <WorldCanvas />
        <div className="pointer-events-none absolute bottom-3 left-3 rounded bg-black/60 px-3 py-2 text-xs">
          Madera: 0 · Piedra: 0 · Comida: 0 · Colonos: 0 (HUD real en Fase 01)
        </div>
      </main>
    </div>
  );
}
