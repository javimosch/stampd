#!/usr/bin/env bash
# Deploy stampd to dk1: build, ship the binary, (re)install the systemd unit, restart,
# and health-check. First run also writes /etc/stampd/stampd.env and exposes the domain
# via hotify + Traefik. Idempotent — safe to re-run for updates.
set -euo pipefail
cd "$(dirname "$0")/.."

HOST="${STAMPD_HOST:-dk1}"
DIR=/opt/stampd
PORT=8791
SVC=stampd.service

echo "▸ build + test"
./build.sh
./test.sh >/dev/null

echo "▸ ship binary to $HOST"
scp -q ./stampd "$HOST:/tmp/stampd.new"
scp -q deploy/stampd.service "$HOST:/tmp/stampd.service"

echo "▸ install + restart on $HOST"
ssh "$HOST" bash -s <<REMOTE
set -euo pipefail
sudo mkdir -p $DIR /etc/stampd
# Seed the env file on first deploy: reuse the living Stripe + Resend creds already on dk1.
if [ ! -f /etc/stampd/stampd.env ]; then
  STRIPE_KEY=\$(sudo grep -h '^STRIPE_SECRET_KEY=' /etc/peage/peage.env 2>/dev/null | head -1 | cut -d= -f2-)
  RESEND_KEY=\$(sudo grep -hRE '^RESEND_API_KEY=' /etc/machin-resend-inbox 2>/dev/null | head -1 | cut -d= -f2-)
  {
    echo "STAMPD_PUBLIC_URL=https://stampd.intrane.fr"
    echo "STAMPD_DB=/opt/stampd/stampd.db"
    echo "STAMPD_FROM=stampd <stampd@intrane.fr>"
    echo "STRIPE_SECRET_KEY=\${STRIPE_KEY}"
    echo "RESEND_API_KEY=\${RESEND_KEY}"
    echo "STRIPE_WEBHOOK_SECRET="
    echo "HART_URL=https://hart.intrane.fr"
    echo "HART_OWNER_KEY="
    echo "STAMPD_DAILY_LIMIT=200"
  } | sudo tee /etc/stampd/stampd.env >/dev/null
  sudo chmod 640 /etc/stampd/stampd.env
  echo "  wrote /etc/stampd/stampd.env (stripe=\${STRIPE_KEY:+set} resend=\${RESEND_KEY:+set})"
  echo "  HART_OWNER_KEY is blank -- claim the stampd owner namespace on hart, then set it"
  echo "  there. See docs/hart-integration.md. Until set, branded reports fall back to HTML."
fi
sudo install -m0755 /tmp/stampd.new $DIR/stampd
sudo install -m0644 /tmp/stampd.service /etc/systemd/system/$SVC
sudo systemctl daemon-reload
sudo systemctl enable $SVC >/dev/null 2>&1 || true
sudo systemctl restart $SVC
sleep 1
curl -fsS http://127.0.0.1:$PORT/_health && echo "  health OK"
REMOTE

echo "▸ done. If the domain isn't routed yet, run (once, on $HOST):"
echo "    hotify-cli setup --id stampd --name stampd --domain stampd --port $PORT --cmd true --local"
echo "    hotify-cli setup-dns --id stampd --local"
echo "    hotify-cli setup-traefik --id stampd --challenge-type dns --local"
