# DMV React Site — Document Upload Integration (Handoff)

**Goal:** On the DMV portal's **"Apply for a License"** tab, add a document
upload area to the **right sidebar** so a user can upload their **ID** and
**proof of address**. The uploaded files must land on a Salesforce
`Application__c` record so the Agentforce chat agent can read them, extract the
details (name, DOB, address), and confirm them back to the user.

This doc is for the engineer who owns the **React DMV site source** (that source
is not in the Salesforce org metadata or the agent repo, so it needs to be wired
on the React side). Everything on the Salesforce side is already built and
deployed — see "Salesforce side (done)" below.

---

## The end-to-end flow

```
[React site: Apply for a License tab, right sidebar]
   user uploads ID + proof of address
        │
        ▼
   create an Application__c (tied to the Jay Walker demo contact)
   attach both files to that Application as ContentVersions/ContentDocuments
        │
        ▼
[Agentforce chat on the same page]
   user: "I want to apply for a license"  → agent asks for documents
   user uploads via the sidebar (above), then types "done"
   agent runs extraction → verifies → reads back name/DOB/address for confirmation
   → proceeds to scheduling
```

The React work is **only the first box**: create the Application and attach the
files. The agent handles the rest.

---

## What the React component must do (2 steps)

### Step 1 — Create the Application record
Create one `Application__c` when the user starts uploading (or on first file).
It must be tied to the demo contact and set to Draft.

**Two ways to do it — pick whichever matches how the site already calls Salesforce:**

**Option A — call the Apex we already built (simplest):**
There is a deployed `@AuraEnabled` method that creates the Application (already
tied to the Jay Walker golden contact) and returns its Id:

```
Apex class:  DLPageUploadController
Method:      createApplicationForUpload()  // returns the new Application Id (string)
```
- If the site uses **LWC/Aura bridges or the Apex REST pattern**, call this.
- If the site calls Salesforce over **REST**, expose this via an Apex REST
  endpoint (or use Option B instead).

**Option B — create it directly via Salesforce REST API:**
```
POST {instanceUrl}/services/data/v63.0/sobjects/Application__c
Authorization: Bearer <session/OAuth token>
Content-Type: application/json

{
  "Status__c": "Draft",
  "Contact__c": "003gL00000zSE1hQAG"   // Jay Walker golden contact
}
```
Response `id` is the Application Id — keep it for Step 2.

- **instanceUrl:** `https://trailsignup-2cf03699ba7fc0.my.salesforce.com`
- **Golden contact (Jay Walker):** `003gL00000zSE1hQAG`

### Step 2 — Attach the two files to that Application
Each uploaded file becomes a `ContentVersion` linked to the Application.

```
POST {instanceUrl}/services/data/v63.0/sobjects/ContentVersion
Authorization: Bearer <token>
Content-Type: application/json

{
  "Title": "passport",                 // or "powerbill" — see note below
  "PathOnClient": "passport.png",
  "VersionData": "<base64 of the file bytes>",
  "FirstPublishLocationId": "<Application Id from Step 1>"
}
```
- `FirstPublishLocationId = <Application Id>` is what links the file to the
  Application (creates the ContentDocumentLink automatically). This is the key field.
- Repeat for both files (ID document + proof of address).

**Filename note:** the agent's Doc AI runs **both** a passport reader and a
power-bill reader on every file and classifies by *content*, not filename — so
the exact `Title`/`PathOnClient` does **not** need to be "passport"/"powerbill".
Any title is fine. (Use clear names anyway for readability.)

**File format:** real image scans (PNG/JPG) or PDF. Doc AI rejects tiny/invalid
files, so send the actual uploaded bytes, not placeholders.

---

## Where to insert it in the React app

I don't have the React source, so this is by-convention — adjust to the repo:

1. **Find the "Apply for a License" route/page component** (search the router
   for the tab label or its path, e.g. `apply`, `license`).
2. That page likely has a layout with a main area and a **right sidebar/aside**.
   Add a new component there, e.g. `DocumentUploadPanel`.
3. `DocumentUploadPanel` responsibilities:
   - On mount (or first file selected): call **Step 1** → store `applicationId`.
   - Render two file inputs: "Form of Identification" and "Proof of Address".
   - On each file chosen: base64-encode and **Step 2** POST to attach it to
     `applicationId`.
   - Show per-file success state, and a final "Both documents uploaded — head to
     the chat and say you're done" message.
4. **Auth:** reuse whatever token/session mechanism the site already uses for its
   existing Salesforce calls (that's why the create/attach are shown as REST —
   match the app's current auth pattern; don't invent a new one).

---

## Site configuration required (Salesforce Setup)

The site user (guest or authenticated, depending on the site's login setting)
must be able to create the Application and attach files. A permission set is
already deployed for this:

- **Permission set:** `DMV Site Upload Access` (`DMV_Site_Upload_Access`)
  - Grants: `Application__c` (create/read/edit) + `Contact__c`/`Status__c` FLS +
    `DLPageUploadController` Apex access.
- **Assign it to the site's user:**
  - **Setup → Digital Experiences → DmvPortalSite → Administration** → open the
    **Guest User Profile / site user**, then assign `DMV_Site_Upload_Access`.
  - (Guest users cannot be assigned perm sets via CLI/API — this must be done in
    the site admin UI.)
- If files are uploaded by the **guest** user, also confirm the guest user has
  **"Create" on ContentVersion** and file-upload is allowed for the site.

---

## Salesforce side (already done — no action needed)

- **Jay Walker golden contact:** `003gL00000zSE1hQAG` (La Jolla, CA address).
- **`Application__c`** object with fields the agent populates:
  `First_Name__c, Last_Name__c, Birthdate__c, Street__c, City__c, State__c,
  Postal_Code__c, Latitude__c, Longitude__c, Service_Type__c, Status__c,
  Contact__c`.
- **`DLPageUploadController.createApplicationForUpload()`** — creates the
  Draft Application tied to Jay Walker, returns its Id.
- **Agent (`DMV_Appointment_Assisting_Agent`, active):** on "done", runs
  `DLProcessApplicationDocuments`, which discovers the most recent Draft
  Application that has files, runs Doc AI (passport + power-bill readers),
  geocodes the address, writes the details to the Application, and the agent
  reads them back to the user for verification.

## How to test the handoff worked
1. On the Apply-for-a-License tab, upload two document images via the sidebar.
2. Confirm an `Application__c` (Status Draft, Contact = Jay Walker) was created
   with **2 files** attached (check the Files related list).
3. In the chat: "I want to apply for a license" → follow prompts → upload done →
   type **done**.
4. The agent should reply with the extracted **name / DOB / address** for
   confirmation. If it says it couldn't read them, the files didn't attach to
   the Application (revisit Step 2 / the perm set).

## Key IDs & endpoints (quick reference)
| Thing | Value |
|---|---|
| instanceUrl | `https://trailsignup-2cf03699ba7fc0.my.salesforce.com` |
| Jay Walker contact | `003gL00000zSE1hQAG` |
| Create Application (Apex) | `DLPageUploadController.createApplicationForUpload()` |
| Create Application (REST) | `POST /services/data/v63.0/sobjects/Application__c` |
| Attach file (REST) | `POST /services/data/v63.0/sobjects/ContentVersion` with `FirstPublishLocationId` = Application Id |
| Permission set | `DMV_Site_Upload_Access` |
