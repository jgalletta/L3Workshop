#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# SlackAgent AFDX demo test suite (Mode A: live-action preview + trace asserts)
#
# Builds the agent from the LOCAL .agent file, runs 3 test cases through one
# live session, inspects the execution traces, and prints a pass/fail report.
# Designed to run in ~20 seconds for a live presentation.
#
#   Usage:  bash tests/run-slackagent-demo.sh
# ---------------------------------------------------------------------------
set -euo pipefail

BUNDLE="SlackAgent"
ORG="${SF_TARGET_ORG:-L3Group}"
CASE_NUMBER="00001074"

# Colors
G=$'\e[32m'; R=$'\e[31m'; B=$'\e[1m'; DIM=$'\e[2m'; N=$'\e[0m'

pass=0; fail=0
say() { printf '%s\n' "$*"; }
result() { # $1=label  $2=ok(0/1)  $3=detail
  if [ "$2" -eq 1 ]; then pass=$((pass+1)); printf "  ${G}✓ PASS${N}  %-28s ${DIM}%s${N}\n" "$1" "$3"
  else fail=$((fail+1)); printf "  ${R}✗ FAIL${N}  %-28s ${DIM}%s${N}\n" "$1" "$3"; fi
}

say "${B}▶ Building SlackAgent from local .agent and starting live test session…${N}"
SID=$(sf agent preview start --json --use-live-actions --authoring-bundle "$BUNDLE" -o "$ORG" 2>/dev/null \
      | python3 -c "import json,sys,re; print(json.loads(re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]','',sys.stdin.read()))['result']['sessionId'])")
say "  session: ${DIM}${SID}${N}"
say ""

TRACE_DIR=".sfdx/agents/${BUNDLE}/sessions/${SID}/traces"

# send <utterance>  -> echoes the planId for the resulting turn
send() {
  sf agent preview send --json --authoring-bundle "$BUNDLE" --session-id "$SID" -o "$ORG" -u "$1" 2>/dev/null \
    | python3 -c "import json,sys,re;d=json.loads(re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]','',sys.stdin.read()));m=d['result'].get('messages',[]);print(m[-1].get('planId','') if m else '')"
}

# trace_field <planId> <python-expr over trace dict d>  -> prints result
trace() {
  python3 - "$TRACE_DIR/$1.json" "$2" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
plan=d.get('plan',[])
def steps(t): return [s for s in plan if s.get('type')==t]
def transitions_to(): return [s['data'].get('to_agent') for s in steps('TransitionStep')]
def actions(): return [s['function']['name'] for s in steps('FunctionStep')]
def action_out():
    fs=steps('FunctionStep'); return fs[0]['function']['output'] if fs else {}
print(eval(sys.argv[2]))
PY
}

# ---- Case 1: Case retrieval (headline capability) -------------------------
say "${B}Case 1 — Retrieve a case by number${N}  ${DIM}\"look up case ${CASE_NUMBER}\"${N}"
P=$(send "Can you look up case ${CASE_NUMBER}?")
TO=$(trace "$P" "transitions_to()")
ACT=$(trace "$P" "actions()")
FOUND=$(trace "$P" "action_out().get('found')")
SUBJ=$(trace "$P" "action_out().get('subject','')")
[[ "$TO" == *"case_lookup"* ]] && result "routes to case_lookup" 1 "$TO" || result "routes to case_lookup" 0 "$TO"
[[ "$ACT" == *"get_case"* ]] && result "invokes get_case action" 1 "$ACT" || result "invokes get_case action" 0 "$ACT"
[[ "$FOUND" == "True" ]] && result "case found (real data)" 1 "subject: $SUBJ" || result "case found (real data)" 0 "found=$FOUND"
say ""

# ---- Case 2: Guardrail (off-topic) ----------------------------------------
say "${B}Case 2 — Off-topic guardrail${N}  ${DIM}\"what's the weather in Paris?\"${N}"
P=$(send "What's the weather in Paris today?")
TO=$(trace "$P" "transitions_to()")
[[ "$TO" == *"off_topic"* ]] && result "routes to off_topic" 1 "$TO" || result "routes to off_topic" 0 "$TO"
say ""

# ---- Case 3: Escalation routing -------------------------------------------
say "${B}Case 3 — Escalation routing${N}  ${DIM}\"I want a human agent\"${N}"
P=$(send "I want to talk to a human agent.")
TO=$(trace "$P" "transitions_to()")
[[ "$TO" == *"escalation"* ]] && result "routes to escalation" 1 "$TO" || result "routes to escalation" 0 "$TO"
say ""

sf agent preview end --json --authoring-bundle "$BUNDLE" --session-id "$SID" -o "$ORG" >/dev/null 2>&1 || true

# ---- Report ---------------------------------------------------------------
total=$((pass+fail))
say "${B}────────────────────────────────────────${N}"
if [ "$fail" -eq 0 ]; then
  say "${G}${B}  ALL PASSED  ${pass}/${total}${N}"
  exit 0
else
  say "${R}${B}  ${fail} FAILED  (${pass}/${total} passed)${N}"
  exit 1
fi
