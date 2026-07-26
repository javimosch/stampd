#!/usr/bin/env bash
# Functional smoke test: boot the server, hit the endpoints, assert on the JSON.
set -e
cd "$(dirname "$0")/.."
PORT="${PORT:-8791}"
BIN=./stampd
export STAMPD_DB=/tmp/stampd-func.db
rm -f "$STAMPD_DB" "$STAMPD_DB"-wal "$STAMPD_DB"-shm

$BIN serve -port "$PORT" >/tmp/stampd-func.log 2>&1 &
SRV=$!
trap "kill $SRV 2>/dev/null || true" EXIT
sleep 1

fail(){ echo "FAIL: $1"; exit 1; }
pass(){ echo "ok: $1"; }

# health
curl -sf "http://127.0.0.1:$PORT/_health" | grep -q '"ok":true' || fail "health"
pass "health"

# api/calc standard 600k -> stamp_duty 20000
R=$(curl -sf "http://127.0.0.1:$PORT/api/calc?price=600000&buyer=standard&income=120000")
echo "$R" | grep -q '"stamp_duty":20000' || fail "calc stamp_duty ($R)"
echo "$R" | grep -q '"total_upfront_cash":' || fail "calc upfront"
echo "$R" | grep -q '"affordable":1' || fail "calc affordable"
pass "api/calc standard"

# first-time buyer 425k -> 6250
curl -sf "http://127.0.0.1:$PORT/api/calc?price=425000&buyer=first_time" | grep -q '"stamp_duty":6250' || fail "calc FTB"
pass "api/calc first_time"

# additional 600k -> 50000
curl -sf "http://127.0.0.1:$PORT/api/calc?price=600000&buyer=additional" | grep -q '"stamp_duty":50000' || fail "calc additional"
pass "api/calc additional"

# bad input -> 400 + ok:false
curl -s "http://127.0.0.1:$PORT/api/calc?price=0" | grep -q '"ok":false' || fail "calc bad input"
pass "api/calc validation"

# landing HTML + guide + llms.txt + snippet
curl -sf "http://127.0.0.1:$PORT/" | grep -qi 'stampd' || fail "landing"
curl -sf "http://127.0.0.1:$PORT/guide" | grep -q 'BUYER TYPES' || fail "guide"
curl -sf "http://127.0.0.1:$PORT/llms.txt" | grep -q '/api/calc' || fail "llms.txt"
curl -sf "http://127.0.0.1:$PORT/help-json" | grep -q '"tool":"stampd"' || fail "help-json"
curl -sf "http://127.0.0.1:$PORT/snippet" | grep -q 'llms.txt' || fail "snippet"
pass "landing + guide + llms + help-json + snippet"

# email without config -> 503 (not configured)
curl -s -X POST "http://127.0.0.1:$PORT/v1/report/email" -H 'content-type: application/json' \
  -d '{"to":"a@b.com","price":600000,"buyer":"standard"}' | grep -q '503\|not configured' || \
  curl -s -X POST "http://127.0.0.1:$PORT/v1/report/email" -H 'content-type: application/json' \
  -d '{"to":"a@b.com","price":600000,"buyer":"standard"}' | grep -q 'not configured' || fail "email unconfigured"
pass "email guarded when unconfigured"

# Pro gating: branded report is 402 without a valid key.
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://127.0.0.1:$PORT/v1/report/branded" \
  -H 'content-type: application/json' -d '{"price":600000,"buyer":"standard"}')
[ "$CODE" = "402" ] || fail "branded without key should be 402 (got $CODE)"
curl -s "http://127.0.0.1:$PORT/v1/pro/verify?key=stmp_bogus" | grep -q '"pro":false' || fail "verify bogus key"
pass "Pro branded report gated (402 without key)"

# Grant a key (writes to STAMPD_DB the server also reads), then the branded report is HTML.
KEY=$($BIN pro-grant agent@agency.co.uk | grep -o 'stmp_[0-9a-f]*')
[ -n "$KEY" ] || fail "pro-grant produced no key"
curl -s "http://127.0.0.1:$PORT/v1/pro/verify?key=$KEY" | grep -q '"pro":true' || fail "verify granted key"
curl -sf -X POST "http://127.0.0.1:$PORT/v1/report/branded" -H "X-Stampd-Key: $KEY" \
  -H 'content-type: application/json' \
  -d '{"price":600000,"buyer":"standard","agency_name":"Camden Homes","agent_name":"Jo","phone":"020 7000 0000","email":"jo@camdenhomes.co.uk"}' \
  | grep -qi 'Camden Homes' || fail "branded report with key returns branded HTML"
pass "Pro key unlocks branded report (agency branding present)"

# Free-use daily ceiling: a second server on a tiny limit, isolated port + DB.
QPORT=$((PORT + 1))
export STAMPD_DB=/tmp/stampd-func-quota.db
rm -f "$STAMPD_DB" "$STAMPD_DB"-wal "$STAMPD_DB"-shm
STAMPD_DAILY_LIMIT=2 $BIN serve -port "$QPORT" >/tmp/stampd-func-quota.log 2>&1 &
QSRV=$!
trap "kill $SRV $QSRV 2>/dev/null || true" EXIT
sleep 1
curl -s -o /dev/null -w "" "http://127.0.0.1:$QPORT/api/calc?price=600000" # call 1/2
curl -s -o /dev/null -w "" "http://127.0.0.1:$QPORT/api/calc?price=600000" # call 2/2
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$QPORT/api/calc?price=600000") # 3rd -> 429
[ "$CODE" = "429" ] || fail "3rd call past STAMPD_DAILY_LIMIT=2 should be 429 (got $CODE)"
pass "free-use daily ceiling returns 429 past the limit"

echo "ALL FUNCTIONAL TESTS PASSED"
