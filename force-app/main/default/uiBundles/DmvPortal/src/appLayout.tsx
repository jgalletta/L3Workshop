import { Outlet, Link, useLocation } from 'react-router';
import { useState } from 'react';
import { Menu, X, CircleUserRound } from 'lucide-react';
import { getAllRoutes } from './router-utils';
import { DmvLogo } from '@/components/brand/DmvLogo';

/*
 * DMV chrome: a navy top utility strip (State-of-California style), a glassy
 * white primary header with the DMV shield logo + nav, and a navy footer.
 * Fictional "Department of Motor Vehicles" for demonstration — not an official
 * government service; a clear demo disclaimer sits below the header.
 */

const ADMIN_NAME = 'Jay Walker';

export default function AppLayout() {
  const [isOpen, setIsOpen] = useState(false);
  const location = useLocation();

  const isActive = (path: string) =>
    path === '/'
      ? location.pathname === '/'
      : location.pathname.startsWith(path);

  const navigationRoutes = getAllRoutes()
    .filter(
      r =>
        r.handle?.showInNavigation === true &&
        r.fullPath !== undefined &&
        r.handle?.label !== undefined
    )
    .map(r => ({ path: r.fullPath, label: r.handle?.label as string }));

  return (
    <div className="flex min-h-screen flex-col">
      {/* Skip link (WCAG) */}
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-lg focus:bg-white focus:px-4 focus:py-2 focus:text-dmv-navy focus:shadow-dmv"
      >
        Skip to main content
      </a>

      {/* ---------- Top utility strip ---------- */}
      <div className="bg-dmv-navy text-white">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-1.5 text-[11px] sm:px-6 lg:px-8">
          <span className="font-medium tracking-wide text-white/80">
            An official demonstration portal · State Services
          </span>
          <div className="hidden items-center gap-4 text-white/80 sm:flex">
            <span className="hover:text-dmv-gold">Translate</span>
            <span className="hover:text-dmv-gold">Locations</span>
            <span className="hover:text-dmv-gold">Help</span>
          </div>
        </div>
      </div>

      {/* ---------- Primary header (glassy, sticky) ---------- */}
      <header className="glass sticky top-0 z-40 border-b border-dmv-line shadow-dmv-xs">
        <div className="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-3 sm:px-6 lg:px-8">
          <Link to="/" className="flex items-center gap-3 rounded-lg">
            <DmvLogo className="h-11 w-11 shrink-0" />
            <span className="flex flex-col leading-tight">
              <span className="text-base font-bold text-dmv-navy sm:text-lg">
                Department of Motor Vehicles
              </span>
              <span className="text-[11px] font-medium uppercase tracking-[0.14em] text-dmv-blue sm:text-xs">
                Online Services
              </span>
            </span>
          </Link>

          {/* Desktop nav */}
          <nav className="hidden items-center gap-1 md:flex">
            {navigationRoutes.map(item => (
              <Link
                key={item.path}
                to={item.path}
                className={`rounded-lg px-3.5 py-2 text-sm font-medium transition-colors ${
                  isActive(item.path)
                    ? 'bg-dmv-blue-10 text-dmv-navy'
                    : 'text-dmv-slate hover:bg-dmv-blue-10/60 hover:text-dmv-navy'
                }`}
              >
                {item.label}
              </Link>
            ))}
            <span className="ml-2 flex items-center gap-2 border-l border-dmv-line pl-3 text-sm text-dmv-slate">
              <CircleUserRound className="h-5 w-5 text-dmv-blue" />
              <span className="hidden lg:inline">{ADMIN_NAME}</span>
            </span>
          </nav>

          {/* Mobile toggle */}
          <button
            onClick={() => setIsOpen(o => !o)}
            className="rounded-lg p-2 text-dmv-navy hover:bg-dmv-blue-10 md:hidden"
            aria-label="Toggle menu"
            aria-expanded={isOpen}
          >
            {isOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
          </button>
        </div>

        {/* Gold accent hairline — the signature element */}
        <div className="h-[3px] w-full bg-gradient-to-r from-dmv-gold via-dmv-gold to-dmv-gold-70" />

        {/* Mobile nav drawer */}
        {isOpen && (
          <div className="border-t border-dmv-line bg-white/95 md:hidden">
            <div className="mx-auto max-w-7xl px-4 py-3 sm:px-6">
              <div className="flex flex-col gap-1">
                {navigationRoutes.map(item => (
                  <Link
                    key={item.path}
                    to={item.path}
                    onClick={() => setIsOpen(false)}
                    className={`rounded-lg px-3 py-2 text-sm font-medium ${
                      isActive(item.path)
                        ? 'bg-dmv-blue-10 text-dmv-navy'
                        : 'text-dmv-slate hover:bg-dmv-blue-10/60'
                    }`}
                  >
                    {item.label}
                  </Link>
                ))}
                <span className="mt-1 flex items-center gap-2 border-t border-dmv-line px-3 pt-3 text-sm text-dmv-slate">
                  <CircleUserRound className="h-5 w-5 text-dmv-blue" />
                  {ADMIN_NAME}
                </span>
              </div>
            </div>
          </div>
        )}
      </header>

      {/* ---------- Main ---------- */}
      <main id="main" className="flex-1">
        <Outlet />
      </main>

      {/* ---------- Footer ---------- */}
      <footer className="mt-16 bg-dmv-navy text-white">
        <div className="h-[3px] w-full bg-gradient-to-r from-dmv-gold via-dmv-gold to-dmv-gold-70" />
        <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8">
          <div className="flex items-center gap-3">
            <DmvLogo className="h-9 w-9" variant="light" />
            <span className="text-sm font-bold">
              Department of Motor Vehicles
            </span>
          </div>
          <p className="mt-4 max-w-2xl text-xs leading-relaxed text-white/70">
            The Department of Motor Vehicles serves residents with driver
            licensing, identification, and vehicle services. This portal is a
            demonstration built on the Salesforce platform.
          </p>
          <nav className="mt-6 flex flex-wrap gap-x-6 gap-y-2 text-xs text-white/80">
            {[
              'Home',
              'Renew DL/ID',
              'REAL ID',
              'Appointments',
              'Privacy',
              'Accessibility',
              'Contact us',
            ].map(l => (
              <span key={l} className="hover:text-dmv-gold hover:underline">
                {l}
              </span>
            ))}
          </nav>
          <p className="mt-6 text-xs text-white/55">
            © 2026 Department of Motor Vehicles (demonstration)
          </p>
        </div>
      </footer>
    </div>
  );
}
