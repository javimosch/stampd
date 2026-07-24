#!/usr/bin/env bash
# stampd tests: pure-core unit tests (machin test) + HTTP functional smoke tests.
set -e
cd "$(dirname "$0")"
MACHIN="${MACHIN:-machin}"

echo "── unit: engine (src/sdlt.src) ──"
"$MACHIN" test src/sdlt.src test/sdlt_test.src

echo "── unit: report/helpers (src/core.src) ──"
"$MACHIN" test src/sdlt.src src/core.src test/core_test.src

echo "── unit: Pro-key store (src/store.src) ──"
rm -f /tmp/stampd_test.db /tmp/stampd_test.db-wal /tmp/stampd_test.db-shm
STAMPD_DB=/tmp/stampd_test.db "$MACHIN" test src/store.src test/store_test.src

echo "── functional: HTTP endpoints ──"
[ -x ./stampd ] || ./build.sh
bash test/functional.sh
