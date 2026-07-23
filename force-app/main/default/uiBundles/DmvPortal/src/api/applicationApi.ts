/**
 * Document upload for the "Apply for a New License" page.
 *
 * The site runs completely unauthenticated (guest user), which can't create
 * Application__c / ContentVersion records directly — client-side /sobjects/
 * writes come back as an HTML login redirect and fail to parse as JSON.
 *
 * Instead we POST once to the server-side Apex REST endpoint
 * (`DLApplicationUploadResource`, `without sharing` → runs in system context),
 * which creates the Application, stores each file as a ContentVersion linked to
 * it (the ContentDocumentLink), and kicks off Document AI extraction. The guest
 * user only needs permission to invoke that one class.
 *
 * IMPORTANT — we do NOT use the `data.fetch` SDK proxy here. The SDK flags
 * `services/apexrest` as always-CSRF-protected, so it forces a CSRF-token GET
 * against the ui-api endpoint first; for an unauthenticated guest that token
 * request returns an HTML login page, which the SDK then fails to parse as JSON
 * ("Unexpected token '<'"). The endpoint itself needs no CSRF token for the
 * guest (verified), so we hit it with a plain same-origin fetch against the
 * SITE-PREFIXED path (e.g. /dmvportalsite/services/apexrest/dmvUpload). A bare
 * "/services/..." would drop the site prefix and lose the guest context.
 *
 * Each response is read as text first so we surface the REAL error (HTML
 * redirects, CSRF pages) instead of a generic JSON-parse failure.
 */

const APEX_REST_PATH = '/services/apexrest/dmvUpload';

/**
 * The app is served from the LWR site at basePath "/dmv". An LWR container
 * serves EVERY sub-path (including /services/apexrest/*) as the SPA shell, so a
 * request to "/dmv/services/apexrest/dmvUpload" comes back as index.html
 * ("Unexpected token '<'") and never reaches Apex.
 *
 * The classic companion site at "/dmvportalsite" (same my.site.com origin, same
 * guest session, and the guest there has the DLApplicationUploadResource class
 * grant) DOES route /services/apexrest/* to Apex — verified returning
 * {"success":true}. So we deliberately post to that prefix, not the LWR one.
 */
const APEX_SITE_PREFIX = '/dmvportalsite';

function sitePrefix(): string {
  return APEX_SITE_PREFIX;
}

function uploadUrl(): string {
  return `${APEX_SITE_PREFIX}${APEX_REST_PATH}`;
}

export interface UploadFilePayload {
  title: string;
  fileName: string;
  file: File;
}

export interface UploadResult {
  applicationId: string;
  applicationNumber?: string;
  uploaded: string[];
}

function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      const comma = result.indexOf(',');
      resolve(comma >= 0 ? result.slice(comma + 1) : result);
    };
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

/**
 * POST helper — plain same-origin fetch (NOT the data.fetch SDK, see file
 * header). Surfaces non-JSON responses with status + snippet so an HTML
 * redirect/login page produces a readable error instead of a bare parse throw.
 */
async function postJson(path: string, body: unknown): Promise<Record<string, unknown>> {
  const res = await fetch(path, {
    method: 'POST',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const raw = await res.text();
  try {
    return JSON.parse(raw) as Record<string, unknown>;
  } catch {
    throw new Error(
      `Non-JSON from ${path} (status ${res.status}, ${raw.length} bytes): ${raw.slice(0, 140)}`
    );
  }
}

/**
 * DIAGNOSTIC: show the resolved upload URL and what a minimal POST to it
 * returns, on-screen, so we can confirm the guest hits Apex (JSON) and not a
 * login redirect (HTML) — without needing browser DevTools.
 */
export async function diagnoseConnection(): Promise<string> {
  const url = uploadUrl();
  const lines: string[] = [`resolved sitePrefix: "${sitePrefix()}"`, `POST ${url}`];
  try {
    const r = await fetch(url, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ files: [{ title: 'diag', fileName: 'diag.txt', base64: 'ZGlhZw==' }] }),
    });
    const body = await r.text();
    lines.push(`-> ${r.status} ${r.headers.get('content-type') ?? ''} | ${body.slice(0, 160)}`);
  } catch (e) {
    lines.push(`-> threw: ${e instanceof Error ? e.message : String(e)}`);
  }
  return lines.join('\n');
}

export async function uploadApplicationDocuments(
  docs: UploadFilePayload[]
): Promise<UploadResult> {
  // Base64-encode every file, then hand the whole set to the server-side
  // endpoint in one request. The Apex class creates the Application, the
  // ContentVersions, and the links — all in system context — so the unauthed
  // guest user never needs create access on those objects.
  const files = await Promise.all(
    docs.map(async d => ({
      title: d.title,
      fileName: d.fileName,
      base64: await fileToBase64(d.file),
    }))
  );

  const resp = await postJson(uploadUrl(), { files });

  if (resp.success !== true) {
    const msg = typeof resp.message === 'string' ? resp.message : 'Upload failed. Please try again.';
    throw new Error(msg);
  }

  return {
    applicationId: String(resp.applicationId ?? ''),
    applicationNumber:
      typeof resp.applicationNumber === 'string' ? resp.applicationNumber : undefined,
    // The endpoint returns one result for the whole batch; reflect the count of
    // files we sent so the UI can say "Uploaded N document(s)".
    uploaded: docs.map(d => d.title),
  };
}
