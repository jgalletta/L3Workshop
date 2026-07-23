import { useRef, useState } from 'react';
import { Upload, FileCheck2, Loader2, FileText } from 'lucide-react';
import {
  uploadApplicationDocuments,
  diagnoseConnection,
  type UploadFilePayload,
} from '@/api/applicationApi';

/**
 * Right-sidebar document upload for the "Apply for a New License" page.
 *
 * The user picks their ID and proof of address, then submits. Both files go to
 * a single server-side endpoint that creates the Application (tied to Jay
 * Walker), stores the files, and starts Document AI extraction. The user then
 * tells the chat assistant they're done and the agent reads the details back.
 */

interface DocSlot {
  key: string;
  label: string;
  hint: string;
}

const DOC_SLOTS: DocSlot[] = [
  { key: 'identity', label: 'Form of Identification', hint: 'Passport, state ID, or driver license.' },
  { key: 'address', label: 'Proof of Address', hint: 'Utility bill, bank statement, or lease.' },
];

export function DocumentUploadPanel() {
  const [files, setFiles] = useState<Record<string, File | null>>({});
  const [status, setStatus] = useState<'idle' | 'submitting' | 'done' | 'error'>('idle');
  const [message, setMessage] = useState<string | null>(null);
  const [diag, setDiag] = useState<string | null>(null);

  const bothPicked = Boolean(files['identity'] && files['address']);

  async function runDiag() {
    setDiag('running…');
    try {
      setDiag(await diagnoseConnection());
    } catch (e) {
      setDiag(e instanceof Error ? e.message : String(e));
    }
  }

  async function handleSubmit() {
    if (!bothPicked) return;
    setStatus('submitting');
    setMessage(null);
    try {
      const payload: UploadFilePayload[] = [
        { title: 'passport', fileName: files['identity']!.name, file: files['identity']! },
        { title: 'powerbill', fileName: files['address']!.name, file: files['address']! },
      ];
      const res = await uploadApplicationDocuments(payload);
      setStatus('done');
      setMessage(
        `Uploaded ${res.uploaded.length} document(s) to your application. Head to the chat and say you're done — the assistant will read and confirm your details.`
      );
    } catch (e) {
      setStatus('error');
      setMessage(e instanceof Error ? e.message : 'Upload failed. Please try again.');
    }
  }

  return (
    <section className="rounded-2xl border border-dmv-line bg-white p-5 shadow-dmv-xs">
      {/* Build stamp — bump on every deploy to confirm the live site is serving fresh code. */}
      <p className="mb-2 text-[10px] font-mono text-dmv-mist">upload build v8 (classic-prefix)</p>
      <h2 className="flex items-center gap-2 text-sm font-semibold text-dmv-navy">
        <FileText className="h-4 w-4 text-dmv-blue" />
        Upload your documents
      </h2>
      <p className="mt-2 text-xs text-dmv-slate">
        Choose your identification and proof of address, then submit. After that,
        tell the assistant you&apos;re done and it will confirm your details.
      </p>

      <div className="mt-4 space-y-3">
        {DOC_SLOTS.map(slot => (
          <PickRow
            key={slot.key}
            slot={slot}
            file={files[slot.key] ?? null}
            disabled={status === 'submitting'}
            onFile={f => setFiles(s => ({ ...s, [slot.key]: f }))}
          />
        ))}
      </div>

      <button
        type="button"
        disabled={!bothPicked || status === 'submitting' || status === 'done'}
        onClick={handleSubmit}
        className="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-lg bg-dmv-blue px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-dmv-navy disabled:opacity-60"
      >
        {status === 'submitting' ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin" /> Submitting…
          </>
        ) : status === 'done' ? (
          <>
            <FileCheck2 className="h-4 w-4" /> Submitted
          </>
        ) : (
          <>
            <Upload className="h-4 w-4" /> Submit documents
          </>
        )}
      </button>

      {message && (
        <p
          className={`mt-3 text-xs ${
            status === 'error' ? 'text-dmv-danger' : 'text-dmv-success'
          }`}
        >
          {message}
        </p>
      )}

      {/* DIAGNOSTIC — shows what the CSRF/session endpoint returns, on-screen. */}
      <button
        type="button"
        onClick={runDiag}
        className="mt-3 text-[10px] font-mono text-dmv-mist underline"
      >
        run connection diagnostic
      </button>
      {diag && (
        <pre className="mt-2 max-h-40 overflow-auto whitespace-pre-wrap rounded bg-dmv-canvas p-2 text-[10px] font-mono text-dmv-ink">
          {diag}
        </pre>
      )}
    </section>
  );
}

function PickRow({
  slot,
  file,
  disabled,
  onFile,
}: {
  slot: DocSlot;
  file: File | null;
  disabled: boolean;
  onFile: (f: File | null) => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const picked = Boolean(file);

  return (
    <div
      className={`rounded-xl border p-3 transition-all ${
        picked ? 'border-dmv-success/40 bg-dmv-success-bg' : 'border-dmv-line bg-white'
      }`}
    >
      <div className="flex items-center justify-between gap-3">
        <div className="min-w-0">
          <p className="text-sm font-semibold text-dmv-navy">{slot.label}</p>
          {picked ? (
            <p className="mt-1 flex items-center gap-1.5 truncate text-xs text-dmv-success">
              <FileCheck2 className="h-3.5 w-3.5 shrink-0" />
              <span className="truncate">{file?.name}</span>
            </p>
          ) : (
            <p className="mt-1 text-xs text-dmv-slate">{slot.hint}</p>
          )}
        </div>
        <button
          type="button"
          disabled={disabled}
          onClick={() => inputRef.current?.click()}
          className="shrink-0 inline-flex items-center gap-1.5 rounded-lg border border-dmv-line bg-white px-3 py-2 text-xs font-medium text-dmv-blue transition-colors hover:border-dmv-blue disabled:opacity-60"
        >
          <Upload className="h-3.5 w-3.5" />
          {picked ? 'Change' : 'Choose'}
        </button>
        <input
          ref={inputRef}
          type="file"
          accept=".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png"
          className="hidden"
          onChange={e => onFile(e.target.files?.[0] ?? null)}
        />
      </div>
    </div>
  );
}
