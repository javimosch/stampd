#!/usr/bin/env bash
# Provision (or re-provision) the stampd chat assistant on the chatsnip instance.
#
# The landing-page chat is a chatsnip agent with ONE declarative tool pointed at
# stampd's own public /api/calc. That's the whole integration: no stampd code
# calls an LLM, and no chatsnip code lives in this repo — stampd just carries the
# agent's prompt + tool config (both public, no secrets) and a <script> tag.
#
# Why a chat at all: the hard part for an overseas buyer isn't arithmetic, it's
# CLASSIFICATION — "additional property" counts homes owned anywhere in the world,
# and non-residence is about days in the UK, not nationality. A form makes the
# visitor self-classify and they get it wrong; the assistant interrogates them and
# picks the right parameters. The tool guarantees the numbers are the engine's.
#
# Run ON the chatsnip host (needs its DB + binary):
#   ssh dk1 'bash -s' < chat/setup.sh
set -euo pipefail

CHATSNIP="${CHATSNIP:-/opt/chatsnip/chatsnip}"
export CHATSNIP_DB="${CHATSNIP_DB:-/opt/chatsnip/data.db}"
SLUG="${SLUG:-stampd}"
ORIGIN="${ORIGIN:-https://stampd.intrane.fr}"
# Must be a tool-calling-capable model. The instance default (a cheap small
# model) does NOT reliably emit tool_calls.
MODEL="${MODEL:-openai/gpt-4o-mini}"
# Public page + a tool loop = each turn is 2-3 paid completions. Keep it bounded.
BUDGET="${BUDGET:-80000}"          # agent tokens/day
VISITOR_BUDGET="${VISITOR_BUDGET:-8000}"
RATE_LIMIT="${RATE_LIMIT:-6}"      # messages/minute per visitor

cd "$(dirname "$0")" 2>/dev/null || true
PROMPT_FILE="${PROMPT_FILE:-./prompt.txt}"
TOOLS_FILE="${TOOLS_FILE:-./tools.json}"

# First-impression config. Without it visitors saw a bare bubble they wouldn't
# click, and an empty panel that didn't say what the bot was for. The greeting is
# STATIC (no LLM call — this renders on every page view) and the chips give a
# one-tap way in that also teaches what the bot can do.
TITLE="Stamp duty for overseas buyers"
GREETING="Buying UK property from abroad? I'll work out your exact stamp duty — including the 2% non-resident and 5% additional-property surcharges most calculators miss — plus the total cash you'll need on completion.

What's the purchase price?"
# Pipe-separated: these are questions, and questions contain commas.
SUGGEST="£850,000 and I own a home abroad|Am I counted as a non-resident buyer?|First-time buyer at £600,000|What will it cost me in total?"
OPEN_AFTER="${OPEN_AFTER:-6000}"   # ms; auto-opens once per visitor, desktop only

if "$CHATSNIP" agent show "$SLUG" >/dev/null 2>&1; then
  echo "▸ updating existing agent '$SLUG'"
  "$CHATSNIP" agent update "$SLUG" -prompt-file "$PROMPT_FILE" -model "$MODEL" \
    -origin "$ORIGIN" -budget "$BUDGET" \
    -visitor-budget "$VISITOR_BUDGET" -rate-limit "$RATE_LIMIT" \
    -title "$TITLE" -greeting "$GREETING" -suggest "$SUGGEST" -open-after "$OPEN_AFTER" >/dev/null
else
  echo "▸ creating agent '$SLUG'"
  "$CHATSNIP" agent create -slug "$SLUG" -name "stampd assistant" \
    -prompt-file "$PROMPT_FILE" -model "$MODEL" -origin "$ORIGIN" \
    -budget "$BUDGET" -visitor-budget "$VISITOR_BUDGET" -rate-limit "$RATE_LIMIT" \
    -title "$TITLE" -greeting "$GREETING" -suggest "$SUGGEST" -open-after "$OPEN_AFTER" >/dev/null
fi

# Only READ-ONLY tools here, deliberately. /api/calc has no side effects. The
# email-a-report endpoint is intentionally NOT exposed: an anonymous public chat
# that can trigger outbound mail to an arbitrary address is a spam vector, and it
# would spend stampd's shared per-IP send quota from chatsnip's server IP.
"$CHATSNIP" agent tools set "$SLUG" -file "$TOOLS_FILE"
"$CHATSNIP" agent tools show "$SLUG"

echo "▸ snippet for the landing page:"
"$CHATSNIP" snippet "$SLUG" -base-url https://chatsnip.intrane.fr
