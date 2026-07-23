/**
 * Salesforce data-SDK helpers. `data.fetch` is a session-scoped Fetch proxy
 * provided by the UI-bundle runtime — it targets the org with the signed-in
 * user's session, so we never handle auth ourselves. Used here for REST calls
 * (record create + file upload) that GraphQL doesn't cover as cleanly.
 */
import { createDataSDK } from '@salesforce/sdk-data';

const API_VERSION = 'v62.0';

async function sfFetch(
  path: string,
  init?: RequestInit
): Promise<Response> {
  const data = await createDataSDK();
  if (!data.fetch) {
    throw new Error('Salesforce fetch proxy is unavailable in this surface.');
  }
  const url = path.startsWith('/services/')
    ? path
    : `/services/data/${API_VERSION}${path}`;
  return data.fetch(url, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(init?.headers ?? {}),
    },
  });
}

/** Create a single sObject record; returns its new Id. */
export async function createRecord(
  sobject: string,
  fields: Record<string, unknown>
): Promise<string> {
  const res = await sfFetch(`/sobjects/${sobject}`, {
    method: 'POST',
    body: JSON.stringify(fields),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(
      `Failed to create ${sobject} (${res.status}): ${text.slice(0, 300)}`
    );
  }
  const json = (await res.json()) as { id: string; success: boolean };
  return json.id;
}

/** Raw session-scoped fetch for endpoints that need full control. */
export { sfFetch };
