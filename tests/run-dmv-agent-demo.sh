#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# DMV Appointment Assisting Agent — AFDX demo test (Mode A).
#
# Scenario: a customer located in DAVIS, CA books a DRIVER LICENSE RENEWAL.
# The optimal office (least travel + wait) is Sacramento Broadway.
#
# Two layers are tested:
#   A. AGENT (live preview + trace asserts) — routing to appointment_scheduling
#      and invocation of find_offices.
#   B. ACTIONS (direct Apex via REST) — with a real Davis-located Contact,
#      confirms Sacramento Broadway ranks #1 and a booking is created.
#      (Preview can't inject the session ContactId, so the Davis-specific
#      travel-time ranking is verified at the action layer.)
#
#   Usage:  bash tests/run-dmv-agent-demo.sh
# ---------------------------------------------------------------------------
set -uo pipefail

BUNDLE="DMV_Appointment_Assisting_Agent"
ORG="${SF_TARGET_ORG:-L3Group}"
SERVICE="Driver License Renewal"
EXPECTED_TOP="Sacramento Broadway"   # nearest to Davis, CA

G=$'\e[32m'; R=$'\e[31m'; B=$'\e[1m'; DIM=$'\e[2m'; N=$'\e[0m'
pass=0; fail=0
result() { if [ "$2" -eq 1 ]; then pass=$((pass+1)); printf "  ${G}✓ PASS${N}  %-34s ${DIM}%s${N}\n" "$1" "$3"; else fail=$((fail+1)); printf "  ${R}✗ FAIL${N}  %-34s ${DIM}%s${N}\n" "$1" "$3"; fi; }

echo "${B}▶ DMV Agent demo — customer in Davis, CA booking a $SERVICE${N}"
echo ""

# ===========================================================================
# LAYER A — Agent routing + action invocation (live preview + traces)
# ===========================================================================
echo "${B}Layer A — Agent conversation (live preview)${N}"
SID=$(sf agent preview start --json --use-live-actions --authoring-bundle "$BUNDLE" -o "$ORG" 2>/dev/null \
  | python3 -c "import json,sys,re; print(json.loads(re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]','',sys.stdin.read()))['result']['sessionId'])")
TRACE_DIR=".sfdx/agents/${BUNDLE}/sessions/${SID}/traces"

send() { sf agent preview send --json --authoring-bundle "$BUNDLE" --session-id "$SID" -o "$ORG" -u "$1" 2>/dev/null \
  | python3 -c "import json,sys,re;d=json.loads(re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]','',sys.stdin.read()));m=d['result'].get('messages',[]);print(m[-1].get('planId','') if m else '')"; }
tget() { python3 - "$TRACE_DIR/$1.json" "$2" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); plan=d.get('plan',[])
def transitions(): return [s['data'].get('to_agent') for s in plan if s.get('type')=='TransitionStep']
def actions(): return [s['function']['name'] for s in plan if s.get('type')=='FunctionStep']
print(eval(sys.argv[2]))
PY
}

P=$(send "I need to renew my driver's license and want to book an appointment")
TR=$(tget "$P" "transitions()"); AC=$(tget "$P" "actions()")
[[ "$TR" == *"appointment_scheduling"* ]] && result "routes to appointment_scheduling" 1 "$TR" || result "routes to appointment_scheduling" 0 "$TR"
[[ "$AC" == *"find_offices"* ]] && result "invokes find_offices" 1 "$AC" || result "invokes find_offices" 0 "(no action; agent likely asked for info — $AC)"
sf agent preview end --json --authoring-bundle "$BUNDLE" --session-id "$SID" -o "$ORG" >/dev/null 2>&1 || true
echo ""

# ===========================================================================
# LAYER B — Action layer with a real Davis-located Contact (direct Apex)
# ===========================================================================
echo "${B}Layer B — Optimization + booking (Davis, CA contact)${N}"

# Tx1: ensure a Contact is located in Davis (DML isolated from callout).
cat > /tmp/dmv_setdavis.apex <<'PY'
Contact c = [SELECT Id FROM Contact LIMIT 1];
c.MailingLatitude=38.5449; c.MailingLongitude=-121.7405;
c.MailingCity='Davis'; c.MailingState='CA'; c.MailingPostalCode='95616';
update c;
System.debug('CID:'+c.Id);
PY
sf apex run --file /tmp/dmv_setdavis.apex -o "$ORG" >/dev/null 2>&1

# Tx2: rank + book, emit a compact RESULT line.
cat > /tmp/dmv_rankbook.apex <<'PY'
Contact c = [SELECT Id FROM Contact WHERE MailingCity='Davis' LIMIT 1];
FindOptimalDMVOffices.Request fr = new FindOptimalDMVOffices.Request();
fr.contactId=c.Id; fr.serviceType='Driver License Renewal';
FindOptimalDMVOffices.Result r = FindOptimalDMVOffices.findOffices(new List<FindOptimalDMVOffices.Request>{fr})[0];
String top = (r.offices!=null && !r.offices.isEmpty()) ? r.offices[0].officeName : 'NONE';
Decimal topTravel = (r.offices!=null && !r.offices.isEmpty()) ? r.offices[0].estimatedTravelMinutes : null;
System.debug('TOP:'+top+'|travel='+topTravel);
if (r.found) {
  FindOptimalDMVOffices.OfficeOption o = r.offices[0];
  BookDMVAppointment.Request br = new BookDMVAppointment.Request();
  br.contactId=c.Id; br.officeId=o.officeId; br.officeName=o.officeName; br.officeCity=o.city; br.officeRegion=o.region;
  br.officeLatitude=o.latitude; br.officeLongitude=o.longitude; br.serviceType='Driver License Renewal'; br.timeSlot='10:00 AM';
  br.expectedWaitMinutes=o.expectedWaitMinutes; br.congestionStatus=o.congestionStatus; br.estimatedTravelMinutes=o.estimatedTravelMinutes;
  BookDMVAppointment.Result b = BookDMVAppointment.book(new List<BookDMVAppointment.Request>{br})[0];
  System.debug('BOOKED:'+b.success+'|'+b.appointmentNumber+'|'+b.appointmentDateTime);
}
PY
sf apex run --file /tmp/dmv_rankbook.apex -o "$ORG" --json 2>/dev/null | grep -vE 'Warning:|Ignoring' > /tmp/dmv_rb.json
eval "$(python3 - <<'PY'
import json
import html
r=json.load(open('/tmp/dmv_rb.json')).get('result',{})
top=""; travel=""; booked=""; num=""; when=""
for l in r.get('logs','').split('\n'):
    if '|DEBUG|' not in l: continue
    m=html.unescape(l.split('|DEBUG|')[-1].strip())
    if m.startswith('TOP:'):
        body=m[4:]; top=body.split('|')[0]; travel=body.split('travel=')[-1]
    if m.startswith('BOOKED:'):
        parts=m[7:].split('|'); booked=parts[0]; num=parts[1] if len(parts)>1 else ''; when=parts[2] if len(parts)>2 else ''
print(f'TOP_OFFICE={top!r}')
print(f'TOP_TRAVEL={travel!r}')
print(f'BOOKED={booked!r}')
print(f'APPT_NUM={num!r}')
print(f'APPT_WHEN={when!r}')
PY
)"

[[ "$TOP_OFFICE" == "$EXPECTED_TOP" ]] && result "optimal office = $EXPECTED_TOP" 1 "travel=${TOP_TRAVEL} min" || result "optimal office = $EXPECTED_TOP" 0 "got: $TOP_OFFICE"
[[ -n "$TOP_TRAVEL" && "$TOP_TRAVEL" != "null" ]] && result "real drive time returned (maps API)" 1 "${TOP_TRAVEL} min" || result "real drive time returned (maps API)" 0 "travel was null"
[[ "$BOOKED" == "true" ]] && result "appointment booked" 1 "$APPT_NUM @ $APPT_WHEN" || result "appointment booked" 0 "booked=$BOOKED"
echo ""

total=$((pass+fail))
echo "${B}────────────────────────────────────────${N}"
if [ "$fail" -eq 0 ]; then echo "${G}${B}  ALL PASSED  ${pass}/${total}${N}"; exit 0
else echo "${R}${B}  ${fail} FAILED  (${pass}/${total} passed)${N}"; exit 1; fi
