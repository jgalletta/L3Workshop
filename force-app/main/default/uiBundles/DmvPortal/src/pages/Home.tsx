import { Link } from 'react-router';
import { ArrowRight, Search, Sparkles } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { serviceTiles } from '@/data/demo';

export default function Home() {
  return (
    <div>
      {/* ---------- Hero ---------- */}
      <section className="relative overflow-hidden">
        {/* soft layered background */}
        <div className="pointer-events-none absolute inset-0 -z-10">
          <div className="absolute inset-0 bg-gradient-to-b from-dmv-blue-10 via-dmv-sky to-transparent" />
          <div className="absolute -top-24 left-1/2 h-96 w-[52rem] -translate-x-1/2 rounded-full bg-dmv-blue/10 blur-3xl" />
        </div>

        <div className="mx-auto max-w-7xl px-4 pt-16 pb-14 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-3xl text-center">
            <span className="inline-flex items-center gap-2 rounded-full border border-dmv-blue-20 bg-white/70 px-3.5 py-1.5 text-xs font-medium text-dmv-blue shadow-dmv-xs backdrop-blur">
              <Sparkles className="h-3.5 w-3.5" />
              Most DMV business can be completed online
            </span>
            <h1 className="mt-6 text-4xl font-bold leading-[1.1] tracking-tight text-dmv-navy sm:text-5xl">
              Skip the line.
              <br />
              <span className="text-dmv-blue">Do it online.</span>
            </h1>
            <p className="mx-auto mt-5 max-w-xl text-base leading-relaxed text-dmv-slate sm:text-lg">
              Apply for a driver license, get instant answers, and track your
              services — all in one place, in minutes.
            </p>

            {/* Search bar */}
            <div className="mx-auto mt-8 flex max-w-xl items-center gap-2 rounded-2xl border border-dmv-line bg-white/80 p-2 shadow-dmv backdrop-blur">
              <Search className="ml-2 h-5 w-5 shrink-0 text-dmv-mist" />
              <input
                type="text"
                placeholder="Search services — e.g. “apply for a license”, “REAL ID”"
                className="flex-1 bg-transparent px-1 py-2 text-sm text-dmv-ink outline-none placeholder:text-dmv-mist"
                aria-label="Search DMV services"
              />
              <Button asChild size="lg" className="rounded-xl">
                <Link to="/assistant">Ask DMV</Link>
              </Button>
            </div>
          </div>
        </div>
      </section>

      {/* ---------- Service tiles ---------- */}
      <section className="mx-auto max-w-7xl px-4 pb-20 sm:px-6 lg:px-8">
        <h2 className="mb-6 text-xl font-semibold text-dmv-navy">
          What would you like to do?
        </h2>
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {serviceTiles.map(tile => {
            const Icon = tile.icon;
            const interactive = Boolean(tile.to);
            const inner = (
              <div
                className={`group relative flex h-full flex-col rounded-2xl border border-dmv-line bg-white p-6 shadow-dmv-xs transition-all ${
                  interactive
                    ? 'hover:-translate-y-1 hover:border-dmv-blue-20 hover:shadow-dmv-glow'
                    : 'opacity-95'
                }`}
              >
                {tile.badge && (
                  <span className="absolute right-4 top-4 rounded-full bg-dmv-blue-10 px-2.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-dmv-blue">
                    {tile.badge}
                  </span>
                )}
                <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-xl bg-dmv-blue-10 text-dmv-blue transition-colors group-hover:bg-dmv-blue group-hover:text-white">
                  <Icon className="h-6 w-6" />
                </div>
                <h3 className="text-base font-semibold text-dmv-navy">
                  {tile.title}
                </h3>
                <p className="mt-1.5 flex-1 text-sm leading-relaxed text-dmv-slate">
                  {tile.description}
                </p>
                {interactive && (
                  <span className="mt-4 inline-flex items-center gap-1 text-sm font-medium text-dmv-blue">
                    Get started
                    <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
                  </span>
                )}
              </div>
            );

            return tile.to ? (
              <Link key={tile.title} to={tile.to} className="rounded-2xl">
                {inner}
              </Link>
            ) : (
              <div key={tile.title}>{inner}</div>
            );
          })}
        </div>
      </section>
    </div>
  );
}
