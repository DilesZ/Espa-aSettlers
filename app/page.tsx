export const metadata = {
  title: "EspañaSettlers — Descargar juego nativo para Windows",
  description:
    "Descarga EspañaSettlers para Windows. Juego nativo de estrategia y gestión con 11 edificios, cadenas de producción, IA rival, niebla de guerra y ciclo día/noche.",
};

const caracteristicas = [
  {
    titulo: "11 edificios",
    texto: "Talador, aserradero, cantera, mina, panadería, molino, granja y más para levantar tu asentamiento.",
  },
  {
    titulo: "Cadenas de producción",
    texto: "Madera, tablones, piedra, herramientas, trigo, harina y pan conectados en una economía viva.",
  },
  {
    titulo: "IA rival",
    texto: "Compite contra una IA rival que expande su territorio y disputa los recursos del mapa.",
  },
  {
    titulo: "Niebla de guerra",
    texto: "Explora, vigila con torres y revela el mapa poco a poco.",
  },
  {
    titulo: "Día y noche",
    texto: "Ciclo día/noche con ambiente dinámico sobre el mismo mapa.",
  },
];

export default function Home() {
  return (
    <div className="flex min-h-screen flex-col bg-[#0b1526] text-zinc-100">
      <header className="mx-auto flex w-full max-w-5xl flex-col gap-6 px-6 pb-10 pt-16 text-center">
        <p className="text-sm font-medium uppercase tracking-widest text-amber-300">
          Juego nativo para Windows
        </p>
        <h1 className="text-4xl font-bold sm:text-5xl">EspañaSettlers</h1>
        <p className="mx-auto max-w-2xl text-lg text-zinc-300">
          Juego de estrategia y gestión: construye tu asentamiento, domina las cadenas de
          producción y supera a la IA rival. Descarga la versión nativa para Windows.
        </p>
        <div className="flex flex-col items-center justify-center gap-3 sm:flex-row">
          <a
            href="https://github.com/DilesZ/Espa-aSettlers/releases"
            className="rounded-lg bg-amber-400 px-6 py-3 font-semibold text-black transition hover:bg-amber-300"
          >
            Descargar para Windows
          </a>
          <a
            href="#"
            aria-disabled="true"
            title="Disponible próximamente en itch.io"
            className="rounded-lg border border-white/20 px-6 py-3 font-semibold text-zinc-200 transition hover:border-white/40"
          >
            itch.io — próximamente
          </a>
        </div>
        <p className="text-sm text-zinc-400">
          Versión de GitHub Releases (.exe + .pck). La demo web queda archivada en{" "}
          <a className="underline" href="/benchmark/">
            /benchmark
          </a>
          .
        </p>
      </header>

      <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-10 px-6 pb-16">
        <section aria-labelledby="caracteristicas" className="rounded-xl border border-white/10 p-6">
          <h2 id="caracteristicas" className="mb-4 text-xl font-semibold">
            Características
          </h2>
          <ul className="grid gap-4 sm:grid-cols-2">
            {caracteristicas.map((c) => (
              <li key={c.titulo} className="rounded-lg bg-white/5 p-4">
                <h3 className="font-semibold text-amber-200">{c.titulo}</h3>
                <p className="mt-1 text-sm text-zinc-300">{c.texto}</p>
              </li>
            ))}
          </ul>
        </section>

        <section aria-labelledby="requisitos" className="rounded-xl border border-white/10 p-6">
          <h2 id="requisitos" className="mb-4 text-xl font-semibold">
            Requisitos mínimos
          </h2>
          <ul className="list-disc space-y-1 pl-6 text-sm text-zinc-300">
            <li>Windows 10 64-bit</li>
            <li>GPU con soporte Vulkan</li>
            <li>4 GB de RAM</li>
          </ul>
        </section>

        <section aria-labelledby="smartscreen" className="rounded-xl border border-amber-300/30 bg-amber-300/5 p-6">
          <h2 id="smartscreen" className="mb-2 text-xl font-semibold">
            Aviso de Windows SmartScreen
          </h2>
          <p className="text-sm text-zinc-300">
            Al ser un publisher desconocido, Windows puede mostrar una advertencia de SmartScreen.
            Pulsa <strong>Más información</strong> y después{" "}
            <strong>Ejecutar de todas formas</strong>. Recomendamos verificar el SHA256 publicado
            en la página de la release antes de ejecutar el instalable.
          </p>
        </section>

        <section className="rounded-xl border border-white/10 p-6 text-sm text-zinc-400">
          <p>
            ¿Buscabas la demo web? Sigue disponible como archivo histórico en{" "}
            <a className="underline" href="/benchmark/">
              /benchmark
            </a>
            . El juego principal ahora se distribuye como aplicación nativa de Windows.
          </p>
        </section>
      </main>

      <footer className="border-t border-white/10 px-6 py-6 text-center text-sm text-zinc-500">
        EspañaSettlers — build nativo de Windows generado con Godot desde GitHub Actions.
      </footer>
    </div>
  );
}
