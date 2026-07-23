import { useRef } from 'react';
import { Upload, FileCheck2, X, Paperclip } from 'lucide-react';
import type { RequiredDoc } from '@/data/demo';

/**
 * Per-document upload list. Each checklist item gets its own dropzone/button.
 * Files are held in parent state as real File objects and uploaded to
 * Salesforce (ContentVersion) on submit.
 */
export function DocumentUpload({
  docs,
  files,
  onChange,
}: {
  docs: RequiredDoc[];
  files: Record<string, File | null>;
  onChange: (key: string, file: File | null) => void;
}) {
  return (
    <div className="space-y-3">
      {docs.map(doc => (
        <DocRow
          key={doc.key}
          doc={doc}
          file={files[doc.key] ?? null}
          onChange={f => onChange(doc.key, f)}
        />
      ))}
      <p className="flex items-center gap-1.5 text-xs text-dmv-mist">
        <Paperclip className="h-3.5 w-3.5" />
        Accepted: PDF, JPG, or PNG · up to 10 MB each
      </p>
    </div>
  );
}

function DocRow({
  doc,
  file,
  onChange,
}: {
  doc: RequiredDoc;
  file: File | null;
  onChange: (f: File | null) => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const uploaded = Boolean(file);

  return (
    <div
      className={`rounded-xl border p-4 transition-all ${
        uploaded
          ? 'border-dmv-success/40 bg-dmv-success-bg'
          : 'border-dmv-line bg-white'
      }`}
    >
      <div className="flex items-center justify-between gap-4">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-dmv-navy">
              {doc.label}
            </span>
            {doc.required ? (
              <span className="rounded bg-dmv-blue-10 px-1.5 py-0.5 text-[10px] font-semibold uppercase text-dmv-blue">
                Required
              </span>
            ) : (
              <span className="rounded bg-dmv-canvas px-1.5 py-0.5 text-[10px] font-semibold uppercase text-dmv-mist">
                Optional
              </span>
            )}
          </div>
          {uploaded ? (
            <p className="mt-1 flex items-center gap-1.5 truncate text-xs text-dmv-success">
              <FileCheck2 className="h-3.5 w-3.5 shrink-0" />
              <span className="truncate">{file?.name}</span>
            </p>
          ) : (
            <p className="mt-1 text-xs text-dmv-slate">{doc.hint}</p>
          )}
        </div>

        <div className="shrink-0">
          {uploaded ? (
            <button
              type="button"
              onClick={() => {
                onChange(null);
                if (inputRef.current) inputRef.current.value = '';
              }}
              className="inline-flex items-center gap-1.5 rounded-lg border border-dmv-line bg-white px-3 py-2 text-xs font-medium text-dmv-slate transition-colors hover:border-dmv-danger/40 hover:text-dmv-danger"
            >
              <X className="h-3.5 w-3.5" />
              Remove
            </button>
          ) : (
            <button
              type="button"
              onClick={() => inputRef.current?.click()}
              className="inline-flex items-center gap-1.5 rounded-lg bg-dmv-blue px-3.5 py-2 text-xs font-medium text-white transition-colors hover:bg-dmv-navy"
            >
              <Upload className="h-3.5 w-3.5" />
              Upload
            </button>
          )}
          <input
            ref={inputRef}
            type="file"
            accept=".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png"
            className="hidden"
            onChange={e => {
              const f = e.target.files?.[0] ?? null;
              onChange(f);
            }}
          />
        </div>
      </div>
    </div>
  );
}
