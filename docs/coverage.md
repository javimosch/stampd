# stampd test coverage

Run: `./test.sh`

## Summary

| Suite      | Assertions | Function coverage | Threshold | Status |
|------------|-----------:|-------------------|-----------|--------|
| Unit       | 83         | 21/21 pure funcs = 100% | > 20% | PASS |
| Functional | 7 checks   | all HTTP routes         | —     | PASS |

**Unit function coverage over the whole `src/` tree: 20/45 functions ≈ 44%.**
The two pure modules — `src/sdlt.src` (the engine) and `src/core.src` (formatters +
report builder) — are unit-tested at 100%. The CLI (`src/cli.src`) and HTTP server
(`src/server.src`) are I/O-bound and covered by the functional suite instead.

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

### src/core.src — formatters + report builder (6/6 functions, 30 assertions)

| Function       | What's covered |
|----------------|----------------|
| `gbp`          | zero, <1000, thousands, millions, negative |
| `bp_pct`       | 3.33, 12.00, 0.05, 0.00 |
| `x100_str`     | 4.52, 4.00, 0.09 |
| `buyer_ok`     | each valid type, rejects, empty |
| `sig_field`    | extract t/v1, missing key, empty header |
| `calc_report`  | JSON shape, locked values, affordable/unaffordable branches |

## Functional tests (`test/functional.sh`)

Boots the real binary and drives it with `curl`: `/_health`, `/api/calc` for standard /
first-time / additional buyers, input validation (400 + `ok:false`), the hosted landing
page, `/guide`, `/llms.txt`, `/help-json`, and the Resend email route's guard when
unconfigured.
