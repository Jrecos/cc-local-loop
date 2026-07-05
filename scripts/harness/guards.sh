#!/usr/bin/env bash
# Per-task stop-guards -> {decision: CONTINUE|ESCALATE}. FAILS CLOSED (missing state => ESCALATE).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/../lib/common.sh"
TASK="${1:?usage: guards.sh <task-id>}"
MAX_ITER="${CCLL_MAX_ITER:-6}";        case "$MAX_ITER"    in ''|*[!0-9]*) MAX_ITER=6;;    esac
TIME_BUDGET="${CCLL_TIME_BUDGET_S:-3600}"; case "$TIME_BUDGET" in ''|*[!0-9]*) TIME_BUDGET=3600;; esac
TDIR="${DATA_DIR}/tasks/${TASK}"; mkdir -p "$TDIR"
[ -f "$TDIR/start" ] || date +%s > "$TDIR/start"
start="$(cat "$TDIR/start" 2>/dev/null || echo 0)"; case "$start" in ''|*[!0-9]*) start=0;; esac
iter="$(cat "$TDIR/iter" 2>/dev/null || echo 0)"; case "$iter" in ''|*[!0-9]*) iter=0;; esac
iter=$((iter+1)); echo "$iter" > "$TDIR/iter"
now="$(date +%s)"; elapsed=$((now - start))
emit(){ printf '{"decision":"%s","reason":"%s","task":"%s","iter":%s,"elapsed_s":%s}\n' "$1" "$2" "$TASK" "$iter" "$elapsed"; }
if [ "$start" -eq 0 ];            then emit ESCALATE "missing start timestamp (fail-closed)"; exit 0; fi
if [ "$elapsed" -ge "$TIME_BUDGET" ]; then emit ESCALATE "TIME budget exceeded (${elapsed}s>=${TIME_BUDGET}s)"; exit 0; fi
if [ "$iter" -ge "$MAX_ITER" ];   then emit ESCALATE "MAX_ITER reached (${iter}>=${MAX_ITER})"; exit 0; fi
# TODO(T2): no-progress (failing-gate signature x k=2), oscillation (last 4), token budget, gate-hash tripwire, crash.
emit CONTINUE "within budget"
