# SlackAgent — Test Suite & Demo Guide

Fast AFDX test suite for the **SlackAgent** Agentforce service agent, built to
demo **build → test → deploy** from VS Code in a live presentation.

## What's here

| File | Purpose |
|---|---|
| `run-slackagent-demo.sh` | The demo runner (Mode A). Builds from the local `.agent`, runs 3 cases through one live session, asserts against execution traces, prints a green/red report. Runs in ~25s. |
| `SlackAgent_Demo.yaml` | Mode B test spec (`AiEvaluationDefinition`). Ready to deploy **in an org with Agentforce Testing Center enabled** (not available in the current org — see Caveat). |

## What the suite tests

| # | Utterance | Asserts | Capability shown |
|---|---|---|---|
| 1 | "Can you look up case 00001074?" | routes to `case_lookup`, invokes `get_case`, returns real case data | ⭐ Case retrieval |
| 2 | "What's the weather in Paris today?" | routes to `off_topic` | Guardrail |
| 3 | "I want to talk to a human agent." | routes to `escalation` | Routing |

Assertions read the live execution **traces** at
`.sfdx/agents/SlackAgent/sessions/<id>/traces/` — subagent transitions, action
invocations, and the `get_case` output (`found` / `subject`).

## Run it

```bash
bash tests/run-slackagent-demo.sh
```

Exit `0` = all passed (green), `1` = a case failed (red). Target org defaults to
`L3Group`; override with `SF_TARGET_ORG=<alias>`.

> **Tip:** do one warm-up run before going on stage — the first run of the day
> is slower while the agent compiles and caches warm.

## The build → test → deploy story (talk track)

```bash
# 1. BUILD — edit the agent, then compile-check it
sf agent validate authoring-bundle --json --api-name SlackAgent

# 2. TEST — run the suite (green in ~25s)
bash tests/run-slackagent-demo.sh

# 3. DEPLOY — publish a version and make it live
sf agent publish authoring-bundle --json --api-name SlackAgent
sf agent activate --json --api-name SlackAgent
```

## Talking points

- **Everything from VS Code / the CLI.** No clicking through Setup — author the
  `.agent` file, validate, test, and deploy from one terminal.
- **Tests run against live actions.** The suite executes the real `CaseLookup`
  Apex against real Case data, not mocks — so a green run proves the whole path
  (routing → action → grounded response) actually works.
- **Traces are the source of truth.** Instead of eyeballing the chat reply, the
  runner inspects the execution trace to assert *which subagent ran* and *which
  action fired* — the same signal you'd use to debug a failure.
- **Fast feedback loop.** ~25s to test three conversation paths means you can
  edit the agent and re-verify in the same breath — the inner loop for agent dev.
- **Guardrails are testable too.** Off-topic and escalation are asserted just
  like the happy path, so you can prove the agent stays in scope.

## What was built (context)

The SlackAgent was extended to **retrieve a Case by case number**:

- **`case_lookup` subagent** + router handoff in `SlackAgent.agent`.
- **`CaseLookup` Apex** (`apex://CaseLookup`) — invocable, bulkified SOQL on
  `Case` by `CaseNumber`.
- **Access wiring** — an Einstein Agent User, the `SlackAgent_Access` permission
  set (Apex + Case read), and a Case sharing rule so the agent user can read
  cases. (Private `Case` sharing was why the agent initially saw 0 rows.)
- Published + activated as **version 1**.

## Caveat — Testing Center (Mode B) not available here

`sf agent test create` fails in the current org with *"Not available for deploy
for this organization"* — the `AiEvaluationDefinition` metadata type isn't
enabled. That's an org entitlement, not a config error.

- **This org:** use `run-slackagent-demo.sh` (Mode A) — same AFDX CLI, works today.
- **An org with Testing Center enabled:** deploy and run the persistent suite:
  ```bash
  sf agent test create --json --spec tests/SlackAgent_Demo.yaml --api-name SlackAgent_Demo -o <org>
  sf agent test run --json --api-name SlackAgent_Demo --wait 10 --result-format json -o <org>
  ```
