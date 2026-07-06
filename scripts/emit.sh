#!/usr/bin/env bash
# Append a VALIDATED structured telemetry event to the ONE event stream. Observability-only — NEVER injected (G1).
# Loud WARN on bad input but ALWAYS exit 0 (telemetry must never kill the loop). Fed by the harness scripts' JSON (G8).
# Usage: emit.sh <event> [json-object] [source]   e.g.  emit.sh gate '{"status":"fail","failing":["scope:x"]}' harness
# NOTE: do NOT add `set -e` here — the always-exit-0 contract relies on limping past any failed helper.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
ev="${1:-}"; payload="${2:-}"; src="${3:-orchestrator}"; [ -n "$payload" ] || payload='{}'
case "$ev" in
  run_start|preflight|route|dispatch|gate|judge|guard|escalation|task_end|run_end|lesson|eval_delta) ;;
  *) log "emit: WARN unknown event '${ev}' — dropped"; exit 0 ;;
esac
command -v jq >/dev/null 2>&1 || { log "emit: WARN jq missing — dropped"; exit 0; }
bytes="$(printf '%s' "$payload" | wc -c | tr -d ' ')"                       # BYTES, not chars (UTF-8 safe)
[ "${bytes:-0}" -le 8192 ] || { log "emit: WARN '${ev}' payload >8KB — dropped"; exit 0; }
# EXACTLY ONE JSON object (rejects multi-document '{}{}' and non-objects like '[1,2]' / '123').
printf '%s' "$payload" | jq -es 'length==1 and (.[0]|type=="object")' >/dev/null 2>&1 \
  || { log "emit: WARN '${ev}' payload is not a single JSON object — dropped"; exit 0; }
run_id="${CCLL_RUN_ID:-unknown}"
sha="$(git -C "${CLAUDE_PROJECT_DIR}" rev-parse --short HEAD 2>/dev/null || echo none)"
# Envelope WINS ('. + {envelope}'): the payload can NEVER override schema/event/run_id/source/git_sha, so the
# event whitelist above is authoritative no matter who calls emit — a caller can't forge a 'lesson/promoted' row (G8).
row="$(printf '%s' "$payload" | jq -c --arg ts "$(date -u +%FT%TZ)" --arg rid "$run_id" --arg ev "$ev" --arg sha "$sha" --arg src "$src" \
  '. + {schema:1, ts:$ts, run_id:$rid, event:$ev, source:$src, git_sha:$sha}' 2>/dev/null)" \
  || { log "emit: WARN build failed — dropped"; exit 0; }
ledger_append "$row"
exit 0
