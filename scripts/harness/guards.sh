#!/usr/bin/env bash
# Evaluate stop-guards over the iteration ledger -> {decision: CONTINUE|ESCALATE, reason}
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/../lib/common.sh"
LEDGER_ARG="${1:-$LEDGER}"; MAX_ITER="${CCLL_MAX_ITER:-6}"
n=0; [ -f "$LEDGER_ARG" ] && n="$(wc -l < "$LEDGER_ARG" | tr -d ' ')"
# TODO(preflight): also evaluate no-progress (same failing-gate signature x k=2), oscillation (repeat in last 4),
#   TIME budget (PRIMARY for unattended), token/cost budget, gate-file hash mismatch (reward-hack tripwire).
if [ "${n:-0}" -ge "$MAX_ITER" ]; then
  printf '{"decision":"ESCALATE","reason":"MAX_ITER (%s) reached"}\n' "$MAX_ITER"
else
  printf '{"decision":"CONTINUE","reason":"within budget (iter=%s/%s)"}\n' "${n:-0}" "$MAX_ITER"
fi
