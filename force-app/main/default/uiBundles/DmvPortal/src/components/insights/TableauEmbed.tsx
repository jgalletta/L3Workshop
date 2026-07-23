import { useState } from 'react';
import { BarChart3, ExternalLink } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';

/**
 * Tableau Cloud dashboard embed (DMV service analytics).
 *
 * We embed via a plain <iframe> rather than the <tableau-viz> web component or
 * the tableau__TableauViz LWC. Two reasons specific to THIS hosting:
 *   1. The app runs in an LWR Experience Cloud site with a strict CSP. An iframe
 *      needs only `frame-src` (already a proven directive here — same as the
 *      SCRT2 chat trusted site). The <tableau-viz> component additionally needs
 *      a third-party `script-src`, which is the riskier unknown in LWR.
 *   2. tableau__TableauViz is an LWC — a different runtime that can't render
 *      inside this React bundle at all.
 * A Tableau Cloud iframe is still fully interactive (filters, tooltips).
 *
 * Requires a CSP Trusted Site for the Tableau host with frame-src enabled
 * (see cspTrustedSites/Tableau_Cloud_Embed). Auth resolves via the viewer's
 * existing Tableau Cloud browser session.
 *
 * Browser URL:  https://prod-useast-b.online.tableau.com/#/site/nfpngo/views/DMBDash/Dashboard1
 * Embed URL:    same host, /t/<site>/views/<workbook>/<view> + embed params.
 */
const TABLEAU_HOST = 'https://prod-useast-b.online.tableau.com';
const TABLEAU_VIEW_PATH = '/t/nfpngo/views/DMBDash/Dashboard1';
const TABLEAU_EMBED_URL = `${TABLEAU_HOST}${TABLEAU_VIEW_PATH}?:embed=y&:showVizHome=no&:tabs=no&:toolbar=bottom`;

export function TableauEmbed() {
  const [loaded, setLoaded] = useState(false);

  return (
    <Card className="overflow-hidden shadow-dmv-xs">
      <CardContent className="p-0">
        {/* Small caption bar with a "open in Tableau" escape hatch */}
        <div className="flex items-center justify-between border-b border-dmv-line bg-white px-4 py-2.5">
          <div className="flex items-center gap-2">
            <BarChart3 className="h-4 w-4 text-dmv-blue" />
            <span className="text-sm font-semibold text-dmv-navy">
              DMV Service Analytics
            </span>
            <span className="text-xs text-dmv-mist">· Tableau Cloud</span>
          </div>
          <a
            href={`${TABLEAU_HOST}/#/site/nfpngo/views/DMBDash/Dashboard1`}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-xs font-medium text-dmv-blue hover:underline"
          >
            Open in Tableau
            <ExternalLink className="h-3.5 w-3.5" />
          </a>
        </div>

        {/* The dashboard */}
        <div className="relative bg-dmv-sky/20">
          {!loaded && (
            <div className="absolute inset-0 z-10 flex flex-col items-center justify-center gap-3 bg-white/60 backdrop-blur-sm">
              <div className="h-9 w-9 animate-spin rounded-full border-2 border-dmv-blue/30 border-t-dmv-blue" />
              <p className="text-sm text-dmv-slate">Loading dashboard…</p>
            </div>
          )}
          <iframe
            title="DMV Service Analytics — Tableau Cloud"
            src={TABLEAU_EMBED_URL}
            onLoad={() => setLoaded(true)}
            className="h-[680px] w-full border-0"
            allowFullScreen
          />
        </div>
      </CardContent>
    </Card>
  );
}
