/**
 * Real persistence for the license-renewal flow:
 *   1. create a License_Renewal__c record from the wizard input
 *   2. upload each attached document as a ContentVersion
 *   3. link every uploaded file to the renewal record (ContentDocumentLink)
 *
 * All calls go through the session-scoped `data.fetch` proxy (sfClient.ts), so
 * they run as the signed-in user against the org — no auth handling here.
 */
import { createRecord, sfFetch } from './sfClient';

export interface RenewalInput {
  applicantName: string;
  licenseNumber: string;
  applicantEmail: string;
  licenseClass: string;
  renewalReason: string;
  realIdRequested: boolean;
}

export interface UploadedDoc {
  /** checklist key (e.g. "identity") */
  key: string;
  label: string;
  file: File;
}

export interface RenewalResult {
  recordId: string;
  renewalNumber: string;
  uploaded: string[]; // labels of docs successfully attached
}

/** Read a File as a base64 string (no data: prefix). */
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

/** Upload one file as a ContentVersion linked to `linkedEntityId`. */
async function uploadDocument(
  linkedEntityId: string,
  label: string,
  file: File
): Promise<void> {
  const base64 = await fileToBase64(file);

  // 1. Create the ContentVersion (the file itself).
  const cvRes = await sfFetch('/sobjects/ContentVersion', {
    method: 'POST',
    body: JSON.stringify({
      Title: label,
      PathOnClient: file.name,
      VersionData: base64,
    }),
  });
  if (!cvRes.ok) {
    const t = await cvRes.text().catch(() => '');
    throw new Error(`ContentVersion upload failed (${cvRes.status}): ${t.slice(0, 200)}`);
  }
  const cv = (await cvRes.json()) as { id: string };

  // 2. Resolve the ContentDocumentId from the ContentVersion.
  const cdRes = await sfFetch(
    `/query?q=${encodeURIComponent(
      `SELECT ContentDocumentId FROM ContentVersion WHERE Id='${cv.id}'`
    )}`
  );
  if (!cdRes.ok) {
    throw new Error(`Could not resolve ContentDocumentId (${cdRes.status})`);
  }
  const cd = (await cdRes.json()) as {
    records: Array<{ ContentDocumentId: string }>;
  };
  const contentDocumentId = cd.records?.[0]?.ContentDocumentId;
  if (!contentDocumentId) throw new Error('ContentDocumentId not found.');

  // 3. Link the document to the renewal record.
  const linkRes = await sfFetch('/sobjects/ContentDocumentLink', {
    method: 'POST',
    body: JSON.stringify({
      ContentDocumentId: contentDocumentId,
      LinkedEntityId: linkedEntityId,
      ShareType: 'V',
      Visibility: 'AllUsers',
    }),
  });
  if (!linkRes.ok) {
    const t = await linkRes.text().catch(() => '');
    throw new Error(`ContentDocumentLink failed (${linkRes.status}): ${t.slice(0, 200)}`);
  }
}

/**
 * Submit a renewal: create the record, then attach documents. Document upload
 * failures are collected but do not roll back the record — the renewal is still
 * submitted, and the result reports which files attached.
 */
export async function submitRenewal(
  input: RenewalInput,
  docs: UploadedDoc[]
): Promise<RenewalResult> {
  const recordId = await createRecord('License_Renewal__c', {
    Applicant_Name__c: input.applicantName,
    License_Number__c: input.licenseNumber,
    Applicant_Email__c: input.applicantEmail,
    License_Class__c: input.licenseClass,
    Renewal_Reason__c: input.renewalReason,
    REAL_ID_Requested__c: input.realIdRequested,
    Status__c: 'Submitted',
    Submitted_Date__c: new Date().toISOString(),
  });

  const uploaded: string[] = [];
  for (const doc of docs) {
    try {
      await uploadDocument(recordId, doc.label, doc.file);
      uploaded.push(doc.label);
    } catch (e) {
      // Keep going — a failed attachment shouldn't kill the submission.
      console.error(`Upload failed for "${doc.label}":`, e);
    }
  }

  // Fetch the friendly auto-number name for the confirmation screen.
  let renewalNumber = '';
  try {
    const res = await sfFetch(
      `/sobjects/License_Renewal__c/${recordId}?fields=Name`
    );
    if (res.ok) {
      const rec = (await res.json()) as { Name?: string };
      renewalNumber = rec.Name ?? '';
    }
  } catch {
    // non-fatal; confirmation can show the Id instead
  }

  return { recordId, renewalNumber, uploaded };
}
