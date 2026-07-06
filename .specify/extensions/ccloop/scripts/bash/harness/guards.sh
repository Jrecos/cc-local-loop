#!/usr/bin/env bash
# Per-task stop-guards -> {decision: CONTINUE|ESCALATE}. FAILS CLOSED (missing state => ESCALATE).
# Usage: guards.sh <task-id> [failing-gate-signature]
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/../lib/common.sh"
TASK="${1:?usage: guards.sh <task-id> [failing-signature]}"; SIG="${2:-}"
MAX_ITER="${CCLL_MAX_ITER:-6}";            case "$MAX_ITER"    in ''|*[!0-9]*) MAX_ITER=6;;    esac
TIME_BUDGET="${CCLL_TIME_BUDGET_S:-3600}"; case "$TIME_BUDGET" in ''|*[!0-9]*) TIME_BUDGET=3600;; esac
TDIR="${DATA_DIR}/tasks/${TASK}"; mkdir -p "$TDIR"
date +%s > "$TDIR/heartbeat"                                   # liveness (silent-death detector)
[ -f "$TDIR/start" ] || date +%s > "$TDIR/start"
start="$(cat "$TDIR/start" 2>/dev/null || echo 0)"; case "$start" in ''|*[!0-9]*) start=0;; esac
iter="$(cat "$TDIR/iter" 2>/dev/null || echo 0)";  case "$iter"  in ''|*[!0-9]*) iter=0;;  esac
iter=$((iter+1)); echo "$iter" > "$TDIR/iter"
now="$(date +%s)"; elapsed=$((now - start))
emit(){ printf '{"decision":"%s","reason":"%s","task":"%s","iter":%s,"elapsed_s":%s}\n' "$1" "$2" "$TASK" "$iter" "$elapsed"; }
[ "$start" -eq 0 ]              && { emit ESCALATE "missing start timestamp (fail-closed)"; exit 0; }
[ "$elapsed" -ge "$TIME_BUDGET" ] && { emit ESCALATE "TIME budget exceeded (${elapsed}s>=${TIME_BUDGET}s)"; exit 0; }
[ "$iter" -ge "$MAX_ITER" ]    && { emit ESCALATE "MAX_ITER reached (${iter}>=${MAX_ITER})"; exit 0; }
# circuit breaker over the failing-gate signature (no-progress + oscillation)
if [ -n "$SIG" ]; then
  printf '%s\n' "$SIG" >> "$TDIR/signatures"
  last4="$(tail -n 4 "$TDIR/signatures")"; nlines="$(printf '%s\n' "$last4" | grep -c .)"
  cur="$(printf '%s\n' "$last4" | tail -n 1)"; prev="$(printf '%s\n' "$last4" | tail -n 2 | head -n 1)"
  [ "$nlines" -ge 2 ] && [ "$cur" = "$prev" ] && { emit ESCALATE "no-progress: identical failing signature x2"; exit 0; }
  earlier="$(printf '%s\n' "$last4" | head -n $((nlines-1)))"
  { [ "$nlines" -ge 3 ] && printf '%s\n' "$earlier" | grep -Fxq "$cur"; } && { emit ESCALATE "oscillation: signature repeated within last ${nlines}"; exit 0; }
fi
emit CONTINUE "within budget"
