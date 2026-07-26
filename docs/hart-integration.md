# hart integration (branded Pro reports)

`POST /v1/report/branded` publishes the agency-branded HTML report to
[hart](https://hart.intrane.fr) under the `stampd` owner namespace and returns a live,
shareable URL instead of raw HTML — see `hart_publish` in `src/server.src`.

## Claiming the `stampd` owner namespace (one-time, per hart instance)

hart's write API has no token by default (guarded by rate limits + peage overage instead),
so an **unclaimed** owner name is writable by anyone until someone sets a key for it. Claim
it before first use:

```sh
KEY=$(openssl rand -hex 16)
curl -X POST 'https://hart.intrane.fr/v1/publish?owner=stampd&artifact=_claim&visibility=private' \
  -H "X-Hart-Owner-Key: $KEY" --data-binary '<p>claimed</p>'
curl -X DELETE 'https://hart.intrane.fr/v1/artifacts/stampd/claim' -H "X-Hart-Owner-Key: $KEY"
```

Put `$KEY` in `/etc/stampd/stampd.env` as `HART_OWNER_KEY`. From then on, every
`hart_publish` call from stampd must send that same key in the `X-Hart-Owner-Key` header
(it does, via `env("HART_OWNER_KEY")`) — hart rejects a mismatched key with `403`.

## Config

| Var | Purpose |
|-----|---------|
| `HART_OWNER_KEY` | required to publish; unset = branded reports fall back to inline HTML |
| `HART_URL` | hart base URL (default `https://hart.intrane.fr`) |

## Behavior

- `HART_OWNER_KEY` unset, or the publish call fails/times out → `report_branded` falls back
  to returning the HTML directly (`ok_html`), so the paid feature never hard-fails.
- On success: `{"ok":true,"url":"https://hart.intrane.fr/a/stampd/report-...","format":"hart"}`.
- Visibility is `unlisted` — viewable by anyone with the link, not listed at `/explore`.
