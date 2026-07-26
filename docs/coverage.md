# stampd test coverage

Run: `./test.sh`

## Summary

| Suite      | Assertions | Function coverage | Threshold | Status |
|------------|-----------:|-------------------|-----------|--------|
| Unit       | 120        | pure modules 100% | > 20% | PASS |
| Functional | 10 checks  | all HTTP routes   | —     | PASS |

**Unit function coverage over the whole `src/` tree: ≈ 31/66 functions ≈ 47%.**
The pure modules — `src/sdlt.src` (the engine), `src/core.src` (formatters + report
builder + onboarding snippet), and `src/store.src` (the Pro-key + daily-usage store) — are
unit-tested at 100%. The CLI (`src/cli.src`) and HTTP server (`src/server.src`) are
I/O-bound and covered by the functional suite instead (including the Pro paywall — 402
without a key, hart-published report with a granted key — and the free-use daily ceiling).

## Unit tests

Pure functions tested via `machin test` — no HTTP, no env, no side effects. The SDLT
figures are cross-checked against the official gov.uk calculator (rates effective
1 April 2025).

### src/sdlt.src — the buying-cost engine (15/15 functions, 53 assertions)

| Function                  | What's covered |
|---------------------------|----------------|
| `band_tax`                | slice inside/below/spanning a band, 0% band |
| `sdlt_standard`           | under-threshold, 250k, 295k, 600k, 925k, 1M, 2M (all bands) |
| `sdlt_first_time`         | ≤300k free, 425k, 500k boundary, relief lost >500k |
| `sdlt_additional`         | 40k boundary, under-40k, 300k, 600k surcharge |
| `nonres_surcharge`        | applied/skipped, under-40k, resident |
| `sdlt`                    | dispatch by buyer type, unknown → standard, non-resident stacking |
| `sdlt_effective_rate_bp`  | blended rate, price 0 guard |
| `lr_fee`                  | every Land Registry price band |
| `deposit` / `loan_amount` | 10%/25%/100% (cash buyer) |
| `pow_f`                   | 2^10, x^0, 1^480 |
| `monthly_payment`         | amortization value, 0% straight-line, zero-loan/term guards |
| `income_multiple_x100`    | 4.5x, 4.0x, zero-income guard |
| `upfront_cash`            | full completion-day total |
| `big`                     | exercised transitively as the top-band sentinel |

### src/core.src — formatters + report builder (10/10 functions, 50 assertions)

| Function             | What's covered |
|-----------------------|----------------|
| `gbp`                 | zero, <1000, thousands, millions, negative |
| `bp_pct`              | 3.33, 12.00, 0.05, 0.00 |
| `x100_str`            | 4.52, 4.00, 0.09 |
| `buyer_ok`            | each valid type, rejects, empty |
| `sig_field`           | extract t/v1, missing key, empty header |
| `sdlt_explain`        | FTB relief lost >£500k (and no bogus additional-property claim), FTB relief applies, additional surcharge, sub-£40k exemptions, standard bands, resident vs non-resident |
| `calc_report`         | JSON shape, locked values, affordable/unaffordable branches |
| `unq_json`            | quoted, unquoted, number passthrough, empty |
| `day_bucket`          | epoch, just-under/exactly-one day, a real timestamp |
| `onboarding_snippet`  | starts with the site URL, points at llms.txt, mentions non-resident |

### src/store.src — Pro-key + daily-usage store (7/7 functions, 17 assertions)

| Function                 | What's covered |
|---------------------------|----------------|
| `mint_pro_key`             | prefix, exact length |
| `pro_key_add` / `pro_key_valid` | empty/unknown/added key, independent keys |
| `pro_session_seen`         | empty/unknown/known session_id (webhook-retry idempotency) |
| `usage_check_and_incr`     | disabled (limit≤0), under/at/over limit, independent IPs, day rollover |

## Functional tests (`test/functional.sh`)

Boots the real binary and drives it with `curl`: `/_health`, `/api/calc` for standard /
first-time / additional buyers, input validation (400 + `ok:false`), the hosted landing
page, `/guide`, `/llms.txt`, `/help-json`, `/snippet`, the Resend email route's guard when
unconfigured, the Pro paywall (402 → key → branded report), and a second server instance
on `STAMPD_DAILY_LIMIT=2` proving the 3rd call returns 429.
