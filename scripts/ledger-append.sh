#!/usr/bin/env bash
# Stop hook: append a run outcome to the ledger. FAIL-SAFE — always exits 0. Records ONLY inside an active loop.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
{
  . "${DIR}/lib/common.sh"
  [ -f "${DATA_DIR}/ACTIVE" ] || exit 0     # don't pollute unrelated projects
  payload="$(cat)"
  if command -v jq >/dev/null 2>&1; then
    sid="$(printf '%s' "$payload" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
    row="$(jq -cn --arg r "${sid:-unknown}" --arg t "$(date -u +%FT%TZ)" \
            --arg s "$(git -C "${CLAUDE_PROJECT_DIR}" rev-parse --short HEAD 2>/dev/null || echo none)" \
            '{run_id:$r,ts:$t,git_sha:$s,outcome:"recorded",source:"stop-hook"}')"
  else
    sid="$(printf '%s' "$payload" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    row="{\"run_id\":\"${sid:-unknown}\",\"ts\":\"$(date -u +%FT%TZ)\",\"outcome\":\"recorded\",\"source\":\"stop-hook\"}"
  fi
  ledger_append "$row"
} >/dev/null 2>&1
exit 0
