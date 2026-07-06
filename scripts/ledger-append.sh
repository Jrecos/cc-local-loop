#!/usr/bin/env bash
# Stop hook: append a run_end event to the event stream. FAIL-SAFE — always exits 0. Only inside an active loop.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
{
  . "${DIR}/lib/common.sh"
  [ -f "${DATA_DIR}/ACTIVE" ] || exit 0
  if [ -t 0 ]; then payload='{}'; else payload="$(cat)"; fi          # never block waiting on stdin (manual run/misconfig)
  rid="$(cat "${DATA_DIR}/RUN_ID" 2>/dev/null || echo unknown)"       # join to run_start (CCLL_RUN_ID persisted at arm)
  if command -v jq >/dev/null 2>&1; then
    sid="$(printf '%s' "$payload" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
    row="$(jq -cn --arg r "${rid:-unknown}" --arg sid "${sid:-unknown}" --arg t "$(date -u +%FT%TZ)" \
            --arg s "$(git -C "${CLAUDE_PROJECT_DIR}" rev-parse --short HEAD 2>/dev/null || echo none)" \
            '{schema:1,ts:$t,run_id:$r,event:"run_end",git_sha:$s,session_id:$sid,source:"stop_hook"}')"
  else
    row="{\"schema\":1,\"ts\":\"$(date -u +%FT%TZ)\",\"run_id\":\"${rid:-unknown}\",\"event\":\"run_end\",\"source\":\"stop_hook\"}"
  fi
  ledger_append "$row"
} >/dev/null 2>&1
exit 0
