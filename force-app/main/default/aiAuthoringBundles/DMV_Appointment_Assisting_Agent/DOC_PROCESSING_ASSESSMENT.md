# Document Processing — Honest Assessment

Status as of the latest testing. Purpose: lay out exactly what works, what's
unreliable, the two root causes, and the realistic options — so the
architecture can be decided rather than iterated on live.

## What definitely works

- **Agent flow & routing** — "register for a drivers license" → document
  collection → create application → asks for uploads. Reliable.
- **`create_application`** — fires in agent context; creates the `Application__c`
  (verified: created by the Einstein Agent User).
- **File upload** — paperclip uploads land as ContentDocuments linked to the
  MessagingSession. Reliable (every test session has both PNGs).
- **Doc AI extraction itself** — when it runs cleanly it is correct: extracted
  `Jay Walker / 15 MAY 1995 / 7401 La Jolla Blvd` from the real files.
- **Geocode → rank → book** — all verified end to end (as admin).
- **Publish/compile** — fixed (the outputs-only-action bug); v21 active.

## What's unreliable

Live extraction success rate is roughly **1 in 4** (across all Applications:
**4 "Details Confirmed" vs. 12 empty "Draft"**). The empty Drafts are runs where
`extract_and_update_application` produced nothing.

## Two compounding root causes (this is the key part)

### Cause 1 — the Doc AI service is intermittently flaky
- Proven: the **same file** failed in one call and succeeded seconds later; 6/6
  succeeded on a later retry.
- We captured a truncated error `pErr=Yo...` — almost certainly a transient
  "You've exceeded/reached [rate/throughput]" message.
- **Mitigation already shipped:** `DLProcessApplicationDocuments.safeExtract`
  now retries up to 3×. Helps, but cannot fully fix a service that fails often,
  and 4 rapid callouts per run (2 configs × 2 docs) increases the odds of a hit.

### Cause 2 — session / timing alignment (the bigger structural issue)
- The process action finds files by `WHERE LinkedEntityId = :messagingSessionId`,
  bound to `@variables.RoutableId` (`@MessagingSession.Id`).
- Evidence of misalignment: **APP-0016 was created at 04:56, but no messaging
  session exists after 04:40**, and APP-0016 has **zero linked files**. So the
  application the agent created and the session where the files live did not line
  up — the link query found nothing → empty Draft.
- Likely contributors (not yet isolated):
  - `RoutableId` passed by the agent may not match the session the files landed
    on (e.g., returning to an earlier chat, or a new session mid-flow).
  - Files may not be query-able at the exact moment the action fires (upload not
    yet committed) — a same-turn timing race.

**Net:** even with Doc AI at 100%, Cause 2 alone would produce empty Drafts. The
folded "find-by-RoutableId + process" design is fragile because it depends on the
agent passing the exact right session id at the exact right instant.

## Realistic options

| Option | What it does | Trade-off |
|---|---|---|
| **A. Robust file discovery** | Stop relying solely on `RoutableId`. Find the user's most recent uploaded passport/powerbill across their recent sessions (by end user / recent ContentDocuments), not one session id. | Directly fixes Cause 2. Slightly looser matching; needs a rule for "which files" (most recent by title). |
| **B. Durable instrumentation first** | Log to a custom object (untruncated) the exact `RoutableId` + files-found on every agent run, then one clean live test gives the full picture. | Confirms Cause 2 precisely before changing design. One more test loop, but no more guessing. |
| **C. Separate link vs. process** | Two actions: (1) link files to the app (idempotent, retry-safe), (2) run Doc AI. User can re-trigger just the failed leg. | Removes all-or-nothing fragility; more actions in the agent. |
| **D. Confirm-gated retry** | Keep one action but let the user say "try again" to re-run extraction against the same app until it succeeds. | Cheapest; leans on the retry + user patience. Doesn't fix Cause 2 alignment. |

## Recommendation

**B then A.** First add durable logging (one clean data point removes the
remaining guesswork on Cause 2 — is it the wrong session id, or a timing race?).
Then make file discovery robust (A) so it no longer depends on a single exact
session id. Keep the retry (shipped) for Cause 1. Consider C if you want the flow
to be re-triggerable leg-by-leg.

## What NOT to do (ruled out by evidence)
- **Not an auth / `UserInfo.getSessionId()` / agent-context problem** — extraction
  failed with a valid session (`sid=true`), disproving that theory. No Connected
  App / credential rework is needed.
- **Not the publish/compile bug** — that was the outputs-only action, already fixed.

## Current deployed state
- Agent: **v21 active**, correct flow, retry-hardened extraction Apex live.
- Diagnostic scaffolding removed (`DLDocAIDiagnostic`, `DLSessionTest` deleted).
- Test data: ~16 Applications accumulated (4 good, rest empty Drafts) — cleanup
  candidate.
