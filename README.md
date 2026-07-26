# stampd

**Stamp duty for overseas buyers of London property — the 2% non-resident surcharge, done right.**

stampd is a tiny, agent-first micro-SaaS for UK (England & Northern Ireland) property costs,
focused on the case generic calculators handle worst: an **overseas / non-UK-resident buyer**
of a London property. Give it a purchase price and a buyer profile; it returns everything a
buyer actually needs to budget for: **Stamp Duty (SDLT)** — including the **2% non-resident
surcharge and its stacking with the additional-property surcharge** — deposit, legal & survey
fees, Land Registry, the monthly mortgage repayment, and the **total cash needed on
completion day**.

- 🌍 **Built for the non-resident case** — the 2% surcharge, its £40k threshold, and its
  stacking with the buy-to-let surcharge (up to 19% on the top slice) — the numbers generic
  UK calculators most often omit or get wrong.
- 🧮 **Deterministic engine** — SDLT rates effective **1 April 2025**, cross-checked against
  the official gov.uk calculator.
- 🤖 **Agent-first** — JSON on stdout, semantic exit codes, a built-in `guide`, `help-json`,
  and `/llms.txt`. Built to the conventions at <https://cli-specs.intrane.fr/>.
- 👤 **Non-technical hosted calculator** — a clean web UI for a buyer, or for a relocation
  consultant / international-buyer specialist advising one.
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

## Pricing — what's free, what's paid

- **Free:** the hosted calculator and the entire JSON API (`/api/calc`) — unlimited, no key.
  Great for overseas buyers and for AI agents automating cost lookups.
- **stampd Pro — £29 one-off (for relocation consultants / international-buyer specialist
  agencies):** buying it mints a **Pro key** (emailed to you) that unlocks **branded client
  reports** — a print-ready "Cost of Buying" one-pager carrying *your firm's name, agent, and
  contact details*, to send a client before they commit. The `POST /v1/report/branded`
  endpoint returns `402 Payment Required` without a valid `X-Stampd-Key`. Keys are minted
  automatically by the Stripe webhook on payment (or granted manually with
  `stampd pro-grant <email>` for comps).

```sh
curl -X POST https://stampd.intrane.fr/v1/report/branded \
  -H 'X-Stampd-Key: stmp_...' -H 'content-type: application/json' \
  -d '{"price":850000,"buyer":"standard","non_resident":"1","agency_name":"Camden Relocation","agent_name":"Jo","phone":"020...","email":"jo@camdenrelocation.co.uk"}'
# -> a self-contained, print-to-PDF branded HTML report
```

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
| `POST /v1/report/branded` | **Pro** — branded HTML report; needs `X-Stampd-Key` (402 without) |
| `GET /v1/pro/verify` | is a Pro key valid? `?key=` or `X-Stampd-Key` |
| `POST /v1/checkout` | start a Stripe Checkout session for stampd Pro |
| `POST /v1/stripe/webhook` | Stripe webhook (HMAC) — mints + emails the Pro key on payment |
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
| `STAMPD_DB` | SQLite path for the Pro-key store (default `stampd.db`) |

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
