# stampd

**The true cost of buying a UK home — Stamp Duty and every other fee, in one number.**

stampd is a tiny, agent-first micro-SaaS for the UK (England & Northern Ireland) property
market. Give it a purchase price and a buyer profile; it returns everything a London buyer
actually needs to budget for: **Stamp Duty (SDLT)**, deposit, legal & survey fees, Land
Registry, the monthly mortgage repayment, and the **total cash needed on completion day** —
plus a 4.5×-income affordability flag.

- 🧮 **Deterministic engine** — SDLT rates effective **1 April 2025**, cross-checked against
  the official gov.uk calculator.
- 🤖 **Agent-first** — JSON on stdout, semantic exit codes, a built-in `guide`, `help-json`,
  and `/llms.txt`. Built to the conventions at <https://cli-specs.intrane.fr/>.
- 👤 **Non-technical hosted calculator** — a clean web UI where a buyer or estate agent gets
  the full breakdown and can email themselves a report.
- 📦 **One static binary** — HTTP server + CLI in the same program. Pure
  [machin](https://github.com/javimosch/machin) (MFL). No Node, no ORM, no runtime deps.

Hosted: **https://stampd.intrane.fr** · Open source (MIT).

## Quick start (CLI)

```sh
./build.sh
./stampd calc --price 600000 --buyer standard --income 120000
```

```json
{"ok":true,"input":{...},"result":{
  "stamp_duty":20000,"stamp_duty_effective_pct":"3.33",
  "deposit":60000,"loan":540000,"monthly_payment":3001,
  "land_registry_fee":295,"total_fees":3394,
  "total_upfront_cash":83394,"income_multiple":"4.50","affordable":1}}
```

Learn the tool the way an agent would:

```sh
./stampd guide        # the operating manual (model, loop, concepts, gotchas)
./stampd help-json    # machine-readable command + flag catalog
```

### Buyer types

| Type          | Meaning |
|---------------|---------|
| `standard`    | Moving home / you already own a property (standard SDLT bands) |
| `first_time`  | First-time buyer relief: 0% to £300k (only when price ≤ £500k) |
| `additional`  | Second home / buy-to-let: +5% surcharge on every band |

Add `--non-resident` for the 2% non-UK-resident surcharge (stacks on any of the above).

### calc flags

`--price` (required) · `--buyer` · `--non-resident` · `--deposit-pct` (10) · `--rate` (4.5) ·
`--years` (25) · `--income` · `--legal` (1500) · `--survey` (600) · `--mortgage-fee` (999).

## HTTP API

```sh
./stampd serve -port 8080
curl "http://localhost:8080/api/calc?price=600000&buyer=standard&income=120000"
```

| Route | Description |
|-------|-------------|
| `GET /` | the hosted calculator (HTML) |
| `GET\|POST /api/calc` | the full buying-cost report as JSON |
| `POST /v1/report/email` | `{"to","price","buyer",...}` — emails the breakdown (Resend) |
| `POST /v1/checkout` | start a Stripe Checkout session for stampd Pro |
| `POST /v1/stripe/webhook` | Stripe webhook (HMAC-verified) |
| `GET /guide` · `GET /llms.txt` · `GET /help-json` | agent onboarding |
| `GET /_health` | liveness |

## Configuration (env)

| Var | Purpose |
|-----|---------|
| `RESEND_API_KEY` | enables `POST /v1/report/email` |
| `STAMPD_FROM` | email From (default `stampd <onboarding@resend.dev>`) |
| `STRIPE_SECRET_KEY` | enables `POST /v1/checkout` |
| `STRIPE_WEBHOOK_SECRET` | verifies `POST /v1/stripe/webhook` |
| `STAMPD_PUBLIC_URL` | base URL for checkout redirects (default the hosted domain) |

Email and billing routes fail safe with a `503` when their key is absent, so the
calculator and API run fine with zero configuration.

## Tests

```sh
./test.sh   # 83 unit assertions (machin test) + 7 functional HTTP checks
```

The pure engine (`src/sdlt.src`) and report layer (`src/core.src`) are unit-tested at 100%;
see [docs/coverage.md](docs/coverage.md).

## Disclaimer

stampd gives **estimates only** and is **not** tax, legal, or financial advice. SDLT is
computed for England & Northern Ireland (Scotland's LBTT and Wales's LTT differ). Always
confirm with a solicitor or your lender before committing.

## License

MIT © stampd
