# Drivers License Agent — Flow & Trigger Mechanics

Agent: **`DMV_Appointment_Assisting_Agent`** (label "Drivers License Agent"),
`AgentforceServiceAgent`, deployed on the **DMV Channel**.

This doc walks the conversation step by step and — importantly — explains **how
each automated step is triggered** (LLM-chosen action vs. deterministic run vs.
transition), and how the document-processing pieces actually fire.

---

## How triggering works in Agent Script (the 3 mechanisms)

Before the flow, the three ways anything "runs" in this agent:

1. **LLM-invoked reasoning action** — defined under a subagent's
   `reasoning: actions:`. The LLM decides *whether/when* to call it based on the
   action `description` and the conversation. Written as
   `name: @actions.x` with `with <input> = ...` (LLM slot-fills) or
   `= @variables.Y` (bound from state). **All of this agent's Apex actions use
   this pattern.**
2. **Deterministic transition** — `@utils.transition to @subagent.X`. Hands the
   conversation from one subagent to the next. One-way.
3. **`set` output capture** — after an action runs, `set @variables.Z =
   @outputs.field` stores a returned value into agent state for later steps.

> ⚠️ **There is no "autolaunched Flow" trigger in this agent.** See the
> [Document AI note](#document-ai-how-it-actually-fires) — the agent triggers
> **Apex**, and that Apex calls the Doc AI logic directly.

---

## The flow, step by step

### 0. Entry → routing
- User: *"I want to register for a drivers license."*
- **`agent_router`** (the `start_agent`) classifies intent and fires
  `go_to_document_collection: @utils.transition to @subagent.document_collection`.
- **Trigger:** LLM-chosen transition, based on the router action descriptions.

### 1. `document_collection` — create the Application, ask for docs
- **Automated step — create the Application:**
  - Reasoning action **`create_application`** → `apex://DLCreateApplication`.
  - **Trigger:** LLM-invoked (instructions tell it to call this first if no
    application exists yet). Input `serviceType` is slot-filled.
  - **Output capture:** `set @variables.ApplicationId = @outputs.applicationId`
    — the new Application Id is stored in agent state and threaded through the
    rest of the conversation.
- Agent then asks the user to **attach** their ID + proof of address (PNG) via
  the messaging **paperclip** (native file upload — not a custom component).
- When the user says they've attached both →
  `go_to_document_processing` transition.

### 2. `document_processing` — link files, run Doc AI, geocode
- **Automated step — the big one:**
  - Reasoning action **`extract_and_update_application`** →
    `apex://DLProcessApplicationDocuments`.
  - **Trigger:** LLM-invoked. Inputs are **bound from state**, not slot-filled:
    - `applicationId = @variables.ApplicationId` (set in step 1)
    - `messagingSessionId = @variables.RoutableId` (the linked
      `@MessagingSession.Id` context variable)
  - **What the Apex does, in order (callout-safe):**
    1. Query `ContentDocumentLink WHERE LinkedEntityId = <messagingSessionId>`
       → find the files the user attached (they link to the **MessagingSession**).
    2. For each file, run the **real Document AI** extractors + LLM categorizer
       (see note below).
    3. Geocode the extracted address (Google Geocoding via `DMV_Maps` cred).
    4. DML: link the ContentDocuments to the **Application** and write the
       extracted fields + lat/long onto it; set status → *Details Confirmed*.
  - **Outputs** (firstName, lastName, birthdate, street, message) are returned
    to the LLM to present.
- Agent presents the extracted details and asks the user to **confirm**.
- On confirm → `go_to_appointment_scheduling` transition.

### 3. `appointment_scheduling` — rank offices, book
- **Automated step — ranking:**
  - Reasoning action **`find_offices`** → `apex://FindOptimalDMVOffices`.
  - **Trigger:** LLM-invoked; `applicationId` + `serviceType` slot-filled.
  - Apex reads the Application's geocoded lat/long, queries the
    **Current DMV Wait Times DMO**, calls Google Distance Matrix for drive time,
    and returns offices ranked by combined travel + wait.
- Agent presents the ranked list; user picks an office + time slot.
- **Automated step — booking:**
  - Reasoning action **`book_appointment`** → `apex://BookDMVAppointment`.
  - **Trigger:** LLM-invoked; inputs (office details, slot, `applicationId`)
    slot-filled from the chosen option.
  - Apex inserts a `DMV_Appointment__c`, links it to the **Application**, and
    sets the Application status → *Scheduled*.
- Agent confirms with the appointment number and date/time.

### Guardrail subagents (always available from the router)
- `escalation` — `@utils.escalate` to a human (LLM-invoked).
- `off_topic` / `ambiguous_question` — redirect / clarify. No actions.

---

## Document AI: how it *actually* fires

This is the most misunderstood part, so to be exact:

- There **is** an autolaunched Flow in the org, `L3_DocAI_ProcessDocuments`,
  from the Doc AI pipeline handoff. **This agent does NOT call that Flow.**
- Instead, the agent calls **Apex `DLProcessApplicationDocuments`** (an
  `@InvocableMethod`), which invokes the pipeline's lower-level Apex **directly**:
  - `L3_DocAI_ExtractData.execute(...)` — runs each Document AI config
    (`passport`, `powerBill`) against a ContentDocument.
  - `L3_DocAI_Categorizer.categorize(...)` — LLM (+ deterministic fallback)
    decides which extractor's output to trust per document.
- Why Apex instead of the Flow: our orchestrator needs a specific
  callout→DML order (Doc AI + geocode callouts first, all DML last) and writes
  to the **Application** (not the Contact the Flow writes to). Calling the Apex
  layer directly gives that control; the autolaunched Flow is an alternative
  entry point to the same underlying Apex, used by the pipeline's LWC.

**So the trigger chain for Doc AI is:**
`LLM calls extract_and_update_application` → `apex://DLProcessApplicationDocuments`
→ `L3_DocAI_ExtractData` + `L3_DocAI_Categorizer` (real Document AI).

---

## Action → backing logic quick reference

| Action (agent) | Target | Trigger | Purpose |
|---|---|---|---|
| `create_application` | `apex://DLCreateApplication` | LLM, then `set` output → `ApplicationId` | Create the hub Application |
| `extract_and_update_application` | `apex://DLProcessApplicationDocuments` | LLM; inputs bound from state | Link files → Doc AI → geocode → update Application |
| `find_offices` | `apex://FindOptimalDMVOffices` | LLM; slot-filled | Rank offices by travel + wait |
| `book_appointment` | `apex://BookDMVAppointment` | LLM; slot-filled | Create + link the appointment |
| `escalate_to_human` | `@utils.escalate` | LLM | Hand off to a human |

## State variables threaded through the flow

| Variable | Type | Set by | Used by |
|---|---|---|---|
| `ApplicationId` | mutable | `create_application` output | `extract_and_update_application`, `find_offices`, `book_appointment` |
| `RoutableId` | linked (`@MessagingSession.Id`) | platform | `extract_and_update_application` (to find uploaded files) |
| `ContactId`, `EndUserId`, `EndUserLanguage` | linked | platform (messaging session) | available if needed |

---

## Gotchas worth remembering

- **Files attach to the MessagingSession, not the Application.** The
  `extract_and_update_application` Apex re-links them to the Application. There
  is no automatic bridge.
- **Every invocable action needs ≥1 input.** An action with only `outputs`
  passes `sf agent validate` but **breaks planner compilation at publish**
  (empty planner → "Invalid Config"). This bit us; `create_application` now has
  a `serviceType` input for exactly this reason.
- **Doc AI needs the `L3_DocAI_Access` permission set** (external credential
  access) assigned to the agent user, and valid image bytes (it 400s on
  hand-rolled files).
