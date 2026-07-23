import { IdCard, CheckCircle2, Circle, FileText, Clock } from 'lucide-react';
import { InlineAgent } from '@/components/chat/InlineAgent';
import { DocumentUploadPanel } from '@/components/renew/DocumentUploadPanel';
import { newLicenseChecklist, applicationSummary } from '@/data/demo';

/**
 * "Apply for a New License" — an agent-driven application experience.
 *
 * Split layout (chosen for this build): a PERSISTENT inline Agentforce
 * conversation on the left drives the application, while a contextual panel on
 * the right shows what the resident needs and the live application state. The
 * agent's actual behaviour is wired later — this page proves out the inline
 * embed + UI shell first.
 */
export default function ApplyLicense() {
  return (
    <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8">
      {/* Page header */}
      <div className="mb-8">
        <span className="inline-flex items-center gap-2 rounded-full bg-dmv-blue-10 px-3 py-1 text-xs font-medium text-dmv-blue">
          <IdCard className="h-3.5 w-3.5" />
          Driver&apos;s License &amp; ID
        </span>
        <h1 className="mt-3 text-3xl font-bold text-dmv-navy sm:text-4xl">
          Apply for a New License
        </h1>
        <p className="mt-2 max-w-2xl text-base text-dmv-slate">
          Chat with the DMV Assistant to complete your application. It will guide
          you step by step and let you know what to bring.
        </p>
      </div>

      {/* Split: persistent agent (left) + context (right) */}
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
        {/* Left — persistent inline agent. Tall, fixed height so the
            conversation is the anchor of the page. */}
        <div className="h-[38rem] lg:h-[42rem]">
          <InlineAgent />
        </div>

        {/* Right — contextual side rail */}
        <aside className="space-y-6">
          {/* Document upload — creates the Application + attaches files */}
          <DocumentUploadPanel />

          {/* What you'll need */}
          <section className="rounded-2xl border border-dmv-line bg-white p-5 shadow-dmv-xs">
            <h2 className="flex items-center gap-2 text-sm font-semibold text-dmv-navy">
              <FileText className="h-4 w-4 text-dmv-blue" />
              What you&apos;ll need
            </h2>
            <ul className="mt-4 space-y-3">
              {newLicenseChecklist.map(item => (
                <li key={item.label} className="flex items-start gap-2.5">
                  {item.done ? (
                    <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-dmv-success" />
                  ) : (
                    <Circle className="mt-0.5 h-4 w-4 shrink-0 text-dmv-mist" />
                  )}
                  <div>
                    <p className="text-sm font-medium text-dmv-ink">
                      {item.label}
                    </p>
                    <p className="text-xs text-dmv-slate">{item.hint}</p>
                  </div>
                </li>
              ))}
            </ul>
          </section>

          {/* Your application */}
          <section className="rounded-2xl border border-dmv-line bg-white p-5 shadow-dmv-xs">
            <h2 className="flex items-center gap-2 text-sm font-semibold text-dmv-navy">
              <Clock className="h-4 w-4 text-dmv-blue" />
              Your application
            </h2>
            <dl className="mt-4 space-y-3">
              {applicationSummary.map(row => (
                <div
                  key={row.label}
                  className="flex items-center justify-between gap-3"
                >
                  <dt className="text-xs text-dmv-slate">{row.label}</dt>
                  <dd className="text-right text-sm font-medium text-dmv-ink">
                    {row.value === 'Draft' ? (
                      <span className="rounded-full bg-dmv-gold-10 px-2.5 py-0.5 text-xs font-semibold text-dmv-warning">
                        Draft
                      </span>
                    ) : (
                      row.value
                    )}
                  </dd>
                </div>
              ))}
            </dl>
            <p className="mt-4 text-xs leading-relaxed text-dmv-mist">
              Your progress updates automatically as you chat with the assistant.
            </p>
          </section>
        </aside>
      </div>
    </div>
  );
}
