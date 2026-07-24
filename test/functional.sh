#!/usr/bin/env bash
# Functional smoke test: boot the server, hit the endpoints, assert on the JSON.
set -e
cd "$(dirname "$0")/.."
PORT="${PORT:-8791}"
BIN=./stampd

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

# landing HTML + guide + llms.txt
curl -sf "http://127.0.0.1:$PORT/" | grep -qi 'stampd' || fail "landing"
curl -sf "http://127.0.0.1:$PORT/guide" | grep -q 'BUYER TYPES' || fail "guide"
curl -sf "http://127.0.0.1:$PORT/llms.txt" | grep -q '/api/calc' || fail "llms.txt"
curl -sf "http://127.0.0.1:$PORT/help-json" | grep -q '"tool":"stampd"' || fail "help-json"
pass "landing + guide + llms + help-json"

# email without config -> 503 (not configured)
curl -s -X POST "http://127.0.0.1:$PORT/v1/report/email" -H 'content-type: application/json' \
  -d '{"to":"a@b.com","price":600000,"buyer":"standard"}' | grep -q '503\|not configured' || \
  curl -s -X POST "http://127.0.0.1:$PORT/v1/report/email" -H 'content-type: application/json' \
  -d '{"to":"a@b.com","price":600000,"buyer":"standard"}' | grep -q 'not configured' || fail "email unconfigured"
pass "email guarded when unconfigured"

echo "ALL FUNCTIONAL TESTS PASSED"
