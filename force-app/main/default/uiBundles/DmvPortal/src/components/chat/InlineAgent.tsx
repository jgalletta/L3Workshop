import { useCallback, useEffect, useRef, useState } from 'react';
import { Sparkles } from 'lucide-react';

/**
 * Persistent, fully-INLINE Agentforce conversation (not the floating widget).
 *
 * This is the SAME Salesforce Embedded Messaging (MIAW) bootstrap the floating
 * chat used — the only difference is three settings that dock the conversation
 * into a page element instead of a bottom-right FAB:
 *   settings.displayMode = 'inline'
 *   settings.disableInlineAutoLaunch = true   (we launch it ourselves on ready)
 *   settings.targetElement = <our div>
 * (Pattern mirrors Salesforce's own Help Agent Accelerator.) It runs against the
 * existing DMV_Channel deployment — no new backend, and it does NOT touch the
 * Agent API / BotRuntime gateway.
 *
 * NOTE: embeddedservice_bootstrap is a page-load SINGLETON — it initialises once
 * and locks in one display mode. That's why the floating widget was removed:
 * inline is now the site's single agent surface.
 */
const ESW = {
  orgId: '00DgL00000XIpEA',
  deploymentName: 'DMV_Channel',
  baseUrl:
    'https://trailsignup-2cf03699ba7fc0.my.site.com/ESWDMVChannel1784685947652',
  scrt2Url: 'https://trailsignup-2cf03699ba7fc0.my.salesforce-scrt.com',
};

declare global {
  interface Window {
    embeddedservice_bootstrap?: {
      settings: {
        language?: string;
        displayMode?: string;
        disableInlineAutoLaunch?: boolean;
        targetElement?: HTMLElement | null;
      };
      init: (
        orgId: string,
        deploymentName: string,
        baseUrl: string,
        opts: { scrt2URL: string }
      ) => void;
      utilAPI?: { launchChat?: () => Promise<void> };
    };
  }
}

// Module-scoped: the bootstrap can only be initialised once per page load.
let bootstrapInitialised = false;

export function InlineAgent() {
  const targetRef = useRef<HTMLDivElement>(null);
  const [status, setStatus] = useState<'loading' | 'ready' | 'error'>(
    'loading'
  );

  const launch = useCallback(() => {
    const api = window.embeddedservice_bootstrap?.utilAPI;
    if (api?.launchChat) {
      void api.launchChat();
      setStatus('ready');
    }
  }, []);

  useEffect(() => {
    const target = targetRef.current;
    if (!target) return;

    // Re-mount within the same SPA session: ESW already initialised, but the
    // previous inline DOM was torn down with its container. Best-effort re-point
    // + re-launch into the fresh target. (If ESW can't re-attach live, a page
    // refresh restores it — acceptable for the demo.)
    if (bootstrapInitialised && window.embeddedservice_bootstrap) {
      window.embeddedservice_bootstrap.settings.targetElement = target;
      launch();
      return;
    }

    window.addEventListener('onEmbeddedMessagingReady', launch);

    const script = document.createElement('script');
    script.type = 'text/javascript';
    script.src = `${ESW.baseUrl}/assets/js/bootstrap.min.js`;
    script.onload = () => {
      const b = window.embeddedservice_bootstrap;
      if (!b) {
        setStatus('error');
        return;
      }
      try {
        b.settings.language = 'en_US';
        b.settings.displayMode = 'inline';
        b.settings.disableInlineAutoLaunch = true;
        b.settings.targetElement = target;
        b.init(ESW.orgId, ESW.deploymentName, ESW.baseUrl, {
          scrt2URL: ESW.scrt2Url,
        });
        bootstrapInitialised = true;
      } catch (err) {
        console.error('Error initialising inline Embedded Messaging:', err);
        setStatus('error');
      }
    };
    script.onerror = () => setStatus('error');
    document.body.appendChild(script);

    return () => window.removeEventListener('onEmbeddedMessagingReady', launch);
  }, [launch]);

  return (
    <div className="flex h-full flex-col overflow-hidden rounded-2xl border border-dmv-line bg-white shadow-dmv-sm">
      {/* Branded chat header */}
      <div className="flex items-center justify-between gap-3 border-b border-dmv-line bg-dmv-navy px-5 py-3.5">
        <div className="flex items-center gap-2.5">
          <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-white/10">
            <Sparkles className="h-4 w-4 text-dmv-gold" />
          </span>
          <div className="leading-tight">
            <p className="text-sm font-semibold text-white">DMV Assistant</p>
            <p className="text-[11px] text-white/70">Powered by Agentforce</p>
          </div>
        </div>
        <span className="inline-flex items-center gap-1.5 rounded-full bg-white/10 px-2.5 py-1 text-[11px] font-medium text-white/90">
          <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
          Online
        </span>
      </div>

      {/* Embedded Messaging renders the inline conversation into this element */}
      <div ref={targetRef} className="relative flex-1 overflow-hidden bg-dmv-sky/30">
        {status !== 'ready' && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 p-6 text-center">
            {status === 'error' ? (
              <p className="max-w-xs text-sm text-dmv-danger">
                The assistant couldn&apos;t load. Please refresh the page to try
                again.
              </p>
            ) : (
              <>
                <div className="h-10 w-10 animate-spin rounded-full border-2 border-dmv-blue/30 border-t-dmv-blue" />
                <p className="text-sm text-dmv-slate">
                  Connecting you to the DMV Assistant…
                </p>
                <button
                  onClick={launch}
                  className="rounded-lg bg-dmv-blue px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-dmv-blue/90"
                >
                  Start conversation
                </button>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
