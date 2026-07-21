# Meta-Prompt: Set Up a Salesforce Org for the L3 Course

You are an AI agent (Claude Code) with access to:
- the **Salesforce CLI** (`sf`, v2.138.x) on this machine, and
- a **browser-automation MCP** (navigate / click / type / screenshot / read accessibility tree).

Your job is to provision a Salesforce org for the L3 course by completing the eight steps
below **in order**. Work conversationally: confirm inputs with the running user, report what
you did after each step, detect-and-skip work that's already done, and stop to ask if a step
fails in a way you can't safely recover from.

---

## Operating rules (read first)

1. **Parse `--json` stdout, ignore stderr.** The `sf` CLI prints a version-update warning to
   stderr on nearly every call. Always pass `--json` and read structured stdout; treat the
   stderr warning as noise.
2. **Thread the target org explicitly.** Pass `--target-org <alias>` (or `-o <alias>`) on every
   `sf` command. Never rely on a default org.
3. **Detect before you act.** Every step has a "check first" — if the work is already done,
   report it as success and move on. Never error on already-enabled / already-exists.
4. **Multi-record inserts use anonymous Apex**, not `sf data create record` (which inserts one
   record and can't return IDs for member loops). Write the Apex to a temp `.apex` file, run it
   with `sf apex run --file <path> --target-org <alias> --json`, and parse `System.debug` marker
   lines (e.g. `System.debug('NEWUSERID:'+u.Id);`) out of the log to capture new IDs.
   Reference idiom: `/Users/jblankenship/Documents/ExternalUserApp/scripts/org-setup.mjs`
   (Apex-insert `:277-299`, debug-parse `:634-647`, login-skip `:255-262`).
5. **Confirm destructive or irreversible actions** (user creation, sandbox creation) before
   running them.

---

## Step 0 — Collect inputs

**First, confirm the org's origin.** Ask the running user to confirm they spun up the target org
from the L3 demo-org provisioning page:
<https://trailhead.salesforce.com/content/employee/modules/advanced-agentic-workflow-architecture/get-your-demo-org?trail_id=value-creation-of-agentforce-360#get-your-demo-org-from-solutions-workspace>
(the "Get your demo org from Solutions Workspace" flow). If they did not, stop and have them
provision the org from that location before continuing — the rest of this setup assumes that org.

Then ask the running user for / determine:

| Input | Required | Default / behavior |
|---|---|---|
| `targetOrgAlias` — the **production or business (trial)** org | yes | none — must be supplied; verify it's reachable |
| `newUsername` — username for the cloned user | yes | globally unique across all of Salesforce, email-format |
| `newUserEmail` | no | default to the template user's `Email` |
| Template user | no | default `Name = 'Trail User'`; fall back to the authenticated admin if not found; **confirm with user** |
| Profile for new user | no | default = template's `ProfileId`; allow override if license-limited |
| Group (fixed) | — | Label `Vibe Code Group`, DeveloperName `Vibe_Code_Group` |
| Sandbox (fixed) | — | Name `L3Sandbox`, license type `Developer` |

Verify the org is reachable and capture its authenticated username:

```bash
sf org display --target-org <targetOrgAlias> --json
```

If exit code ≠ 0, instruct the user to authenticate first:
`sf org login web --alias <targetOrgAlias>`.

---

## Step 1 — Enable Data Cloud  **[UI / browser]**

There is **no** Metadata/Tooling/CLI toggle for Data Cloud enablement — it is a UI provisioning
action. Use the browser MCP.

1. **Detect first.** Open Setup → Quick Find "Data Cloud Setup". If the page already shows Data
   Cloud as enabled/provisioned, report success and skip.
2. Otherwise click the **Set Up / Enable** affordance. Read the accessibility tree or a screenshot
   to find it — labels drift across releases, so don't hard-code selectors.
3. **You are not done until you click "Get Started" (and any follow-on confirm) and the page
   confirms Data Cloud is being provisioned.** The initial "Set Up Your Data Cloud Instance"
   button alone does **not** complete enablement — a **"Get Started"** button appears (often on a
   second screen or modal) that you **must** click to actually kick off provisioning. After
   clicking it, read the page back and verify a provisioning banner / "in progress" / "active"
   state is shown. If you only clicked the first button and never saw/clicked "Get Started",
   Data Cloud is **not** enabled. (A prior run made this mistake — do not repeat it.)
4. Provisioning is asynchronous (minutes). It is OK to proceed to Steps 2–4 once the provisioning
   request is confirmed accepted, but **Step 5 is hard-gated on Data Cloud being fully
   provisioned** (see Step 5 precondition).
5. If the page offers **no** enable affordance, the org's edition/license likely lacks Data Cloud
   entitlements — report this clearly to the user and continue.

> ⚠️ **Do not confirm Data Cloud enablement by querying for the `DataStream` object via Apex.**
> That object can be queryable before provisioning actually completes and is not a reliable
> signal. Confirm via the **Data Cloud Setup page in the browser** showing active/provisioned.

---

## Step 2 — Enable Agentforce  **[UI / browser]**

Same as Step 1: no API toggle exists.

1. **Detect first.** Setup → Quick Find "Agentforce Agents" (or "Einstein Agents" / "Agents").
   If already On, report success and skip.
2. Agentforce often requires **Einstein / Einstein Generative AI** to be enabled first. If
   prompted, go to Setup → "Einstein Setup" / "Einstein Generative AI", turn it on, and **accept
   any acceptable-use / legal consent modal**.
3. Toggle **Agentforce Agents** to On; accept any consent dialog.
4. If no enable affordance exists, report the entitlement gap and continue.

---

## Step 3 — Clone the Trail User  **[API]**

### 3a. Resolve the template user
```bash
sf data query --target-org <targetOrgAlias> --json -q \
"SELECT Id, Username, ProfileId, UserRoleId, UserType, Email, LastName, FirstName, Alias, \
 LanguageLocaleKey, LocaleSidKey, EmailEncodingKey, TimeZoneSidKey \
 FROM User WHERE Name = 'Trail User' LIMIT 1"
```
If **0 rows**, fall back to the authenticated user (use the username from Step 0's
`sf org display`): `... WHERE Username = '<authenticatedUsername>'`.
**Show the resolved template user to the running user and confirm before cloning.**

### 3b. Read the template's assignments
Permission set & permission set group assignments (exclude profile-owned):
```bash
sf data query --target-org <targetOrgAlias> --json -q \
"SELECT PermissionSetId, PermissionSetGroupId, PermissionSet.Name, PermissionSet.IsOwnedByProfile \
 FROM PermissionSetAssignment WHERE AssigneeId = '<templateUserId>'"
```
→ **Drop every row where `PermissionSet.IsOwnedByProfile = true`** (those are auto-created with the profile).

Public group memberships:
```bash
sf data query --target-org <targetOrgAlias> --json -q \
"SELECT GroupId, Group.DeveloperName FROM GroupMember WHERE UserOrGroupId = '<templateUserId>'"
```

### 3c. Prompt for the username and validate
Ask for `newUsername`. Validate: globally unique, email-format. Derive `Alias` from the template
but **truncate to ≤ 8 characters** (append digits if needed to avoid collision).

### 3d. Insert the user + assignments via anonymous Apex
Write a temp `.apex` file like:
```apex
User u = new User(
  Username          = '<newUsername>',
  Email             = '<newUserEmail or template.Email>',
  LastName          = '<template.LastName>',
  FirstName         = '<template.FirstName>',
  Alias             = '<alias<=8>',
  ProfileId         = '<template.ProfileId>',
  UserRoleId        = '<template.UserRoleId>',   // omit this line if null
  EmailEncodingKey  = '<template.EmailEncodingKey>',
  LanguageLocaleKey = '<template.LanguageLocaleKey>',
  LocaleSidKey      = '<template.LocaleSidKey>',
  TimeZoneSidKey    = '<template.TimeZoneSidKey>'
);
insert u;
System.debug('NEWUSERID:' + u.Id);

List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
// for each kept PSA row: psas.add(new PermissionSetAssignment(AssigneeId=u.Id, PermissionSetId='<id>'));
// for each PSG row:       psas.add(new PermissionSetAssignment(AssigneeId=u.Id, PermissionSetGroupId='<id>'));
if (!psas.isEmpty()) insert psas;

List<GroupMember> gms = new List<GroupMember>();
// for each group row: gms.add(new GroupMember(UserOrGroupId=u.Id, GroupId='<id>'));
if (!gms.isEmpty()) insert gms;
```
Run it:
```bash
sf apex run --file <temp>.apex --target-org <targetOrgAlias> --json
```
Parse `NEWUSERID:` from the debug log and keep the new user Id.

### 3e. Handle license errors
If insert fails with `LICENSE_LIMIT_EXCEEDED` (common when cloning the System Administrator
profile on a trial), tell the user and offer to use a lighter-weight profile; re-run with the
chosen `ProfileId`.

---

## Step 4 — Create the "Vibe Code Group" public group  **[API]** — *before the sandbox*

`Group` is **not** a Metadata API type — create it as a record. Run this step **before** Step 5
so the group is captured in the sandbox snapshot.

**Check first:**
```bash
sf data query --target-org <targetOrgAlias> --json -q \
"SELECT Id FROM Group WHERE DeveloperName = 'Vibe_Code_Group'"
```
If it exists, skip the insert. Otherwise create it (and add both the new cloned user **and the
base/template user** as members, plus any others the user names) via anonymous Apex:
```apex
Group g = new Group(Name='Vibe Code Group', DeveloperName='Vibe_Code_Group', Type='Regular');
insert g;
System.debug('GROUPID:' + g.Id);

// Add cloned user (dynamic lookup — no hardcoded IDs)
User newUser = [SELECT Id FROM User WHERE Username = '<newUsername>' LIMIT 1];
insert new GroupMember(GroupId = g.Id, UserOrGroupId = newUser.Id);

// Add base/template user (dynamic lookup — no hardcoded IDs)
User baseUser = [SELECT Id FROM User WHERE Username = '<templateUsername>' LIMIT 1];
insert new GroupMember(GroupId = g.Id, UserOrGroupId = baseUser.Id);
```
(`Type='Regular'` = a public group.)

---

## Step 5 — Create the L3Sandbox Developer sandbox  **[API, async]**

**Precondition 1 — Data Cloud must be fully provisioned before you create the sandbox.**
A sandbox snapshots the production org at creation time. If Data Cloud provisioning is still
in progress or not yet started, the sandbox will not inherit it and cannot be patched afterward.

Confirm Data Cloud is provisioned by navigating Setup → Quick Find "Data Cloud Setup" in the
browser. The page must show Data Cloud as **active/provisioned** (not "Set Up", not "Get Started",
not a pending spinner). Verify in the **browser UI** — do **not** rely on an Apex `DataStream`
query as proof (it can succeed before provisioning finishes). If provisioning is still in progress,
**wait and re-check every 5 minutes** until it is complete before proceeding. Do not skip this gate.

> 🚫 **This gate is one-shot — you cannot fix it later with a refresh.** A Developer sandbox
> can only be refreshed (or deleted) **after its license refresh interval has elapsed (~1 day)**.
> `sf org refresh sandbox` fails immediately with
> `INVALID_INPUT: You can refresh or delete sandboxes only after the refresh interval for their
> license type has elapsed` if you try sooner. So if you create the sandbox before Data Cloud is
> live, you're stuck for ~24h. **Do not create the sandbox until Data Cloud is fully provisioned.**

**Precondition 2:** Sandboxes can only be created from a **production or business (trial) org that
has sandbox licenses** — this will **fail on a Trailhead Playground / scratch / dev org**. Before
running, sanity-check sandbox capability; if unavailable, report clearly and stop here.

```bash
sf org create sandbox --target-org <targetOrgAlias> \
  --name L3Sandbox --license-type Developer --alias L3Sandbox --async --no-prompt --json
```
(`--name` ≤ 10 chars; "L3Sandbox" = 9, OK. Backed by `SandboxInfo` / `SandboxProcess`.)

---

## Step 6 — Poll until the sandbox is Completed  **[API gate]**

Sandbox creation is asynchronous and can take many minutes (often 20–40+ for a Developer sandbox).
Poll:
```bash
sf org resume sandbox --name L3Sandbox --target-org <targetOrgAlias> --wait 0 --json
```
(Or resume by job id: `sf org resume sandbox --job-id <SandboxProcessId> -o <targetOrgAlias> --wait 0 --json`.)

Status progresses `Pending → Processing → Activating → Completed`. **You must actively keep polling
until status = `Completed` — do not stop at `Pending`/`Processing` and hand the polling back to the
user.** Re-check every ~2 minutes (a single long `--wait 120` per call is fine; loop until done).
A prior run stopped while the sandbox was still `Pending` — do not repeat that. Only once status is
`Completed` do you proceed to Step 7. Report progress to the user on each poll.

---

## Step 7 — Authenticate to the sandbox  **[API / UI]**

Try the existing connection first (exit 0 = already connected):
```bash
sf org display --target-org L3Sandbox --json
```
If not connected, log in via the sandbox endpoint:
```bash
sf org login web --instance-url https://test.salesforce.com --alias L3Sandbox
```

---

## Step 8 — Enable Data Cloud and Agentforce inside the sandbox  **[UI / browser]**

A sandbox does **not** automatically carry over Data Cloud / Agentforce enablement from the
source org — these are per-org provisioning actions and must be turned on again **in the
sandbox itself** after it's created and authenticated.

Repeat **Step 1 (Data Cloud)** and **Step 2 (Agentforce)** against the sandbox, this time using
the sandbox's authenticated browser session (open it via
`sf org open --target-org L3Sandbox --path lightning/setup/SetupOneHome/home --json` or the
sandbox login flow from Step 7). The same rules apply:

- **Data Cloud:** detect first; if not enabled, click the Set Up affordance **and** the follow-on
  **"Get Started"** button, then verify the Data Cloud Setup page shows active/provisioning. Do
  **not** rely on an Apex `DataStream` query as proof.
- **Agentforce:** detect first; enable Einstein / Einstein Generative AI if prompted (accept the
  consent modal), then toggle Agentforce Agents to On.
- If either is already enabled in the sandbox, report success and skip.

> Note: the source-org gate (do not create the sandbox until Data Cloud is provisioned in prod)
> still applies — but the sandbox needs its **own** enablement regardless, so do this step every time.

---

## Step 9 — Recreate the group inside the sandbox  **[API]**

A Developer sandbox copies metadata + setup data, so `Vibe_Code_Group` likely already exists in
L3Sandbox (it was created in Step 4, before the snapshot).

**Check first:**
```bash
sf data query --target-org L3Sandbox --json -q \
"SELECT Id FROM Group WHERE DeveloperName = 'Vibe_Code_Group'"
```
- If present, reconcile its members instead of inserting (avoid `DUPLICATE_DEVELOPER_NAME`).
- If absent, insert it exactly as in Step 4 but against `--target-org L3Sandbox`.

**Re-map members by Username, not Id** — user Ids differ between orgs. Both the cloned user
**and the base/template user** must be reconciled. For each intended member, resolve the sandbox
user Id by `Username`, then insert the missing `GroupMember` rows:
```bash
sf data query --target-org L3Sandbox --json -q \
"SELECT Id FROM User WHERE Username IN ('<newUsername>.l3sandbox', '<templateUsername>.l3sandbox')"
```
(Sandbox usernames are typically `<prodUsername>.l3sandbox`.)

---

## Verification checklist

Run these and report results:

- **Data Cloud / Agentforce (source org)** — show enabled in Setup (or confirmed already enabled).
- **Cloned user** —
  `sf data query -o <targetOrgAlias> --json -q "SELECT Username, ProfileId FROM User WHERE Username='<newUsername>'"`
  returns the user; spot-check its `PermissionSetAssignment` / `GroupMember` rows match the
  template (minus profile-owned).
- **Group (source org)** — `Group WHERE DeveloperName='Vibe_Code_Group'` exists with expected members.
- **Sandbox** — `sf org list --json` shows `L3Sandbox`; `sf org resume sandbox` status = `Completed`.
- **Data Cloud / Agentforce (sandbox)** — both enabled **inside L3Sandbox** (Step 8), verified in the
  sandbox's Setup UI.
- **Group (sandbox)** — `Group WHERE DeveloperName='Vibe_Code_Group'` exists in **L3Sandbox** with
  members re-mapped by Username.

---

## Risks & gotchas (keep in mind throughout)

- Data Cloud / Agentforce may already be enabled → skip, don't error; some editions lack the entitlement entirely.
- `Name = 'Trail User'` is not guaranteed → fall back to the admin user and **confirm**.
- Cloning the admin profile can hit `LICENSE_LIMIT_EXCEEDED` on trials → offer a lighter profile.
- `Username` is globally unique; `Alias` ≤ 8 chars.
- Exclude profile-owned permission sets (`IsOwnedByProfile = true`).
- `Group` is **not** Metadata API — never `sf project deploy` it; insert a record.
- Watch for `DeveloperName` collisions (query first, especially in the sandbox).
- **Data Cloud must be fully provisioned before sandbox creation** — the sandbox snapshots the org at creation time and cannot inherit Data Cloud retroactively. Gate Step 5 on the Data Cloud Setup page showing active/provisioned.
- Sandboxes require a prod/business org — fail fast on Playgrounds/scratch orgs.
- Sandbox creation is async & slow — gate Steps 8–9 on `Completed`.
- A sandbox does **not** inherit Data Cloud / Agentforce enablement — re-enable both inside the sandbox (Step 8).
- Sandbox is a separate org connection (test.salesforce.com); member Ids differ — map by Username.
- Ignore the `sf` stderr version-update warning; read `--json` stdout.
- Setup UI labels change across releases — read the page, don't hard-code selectors.
