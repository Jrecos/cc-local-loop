#!/usr/bin/env bash
# Stop hook: append a run outcome to the ledger. FAIL-SAFE — always exits 0, never blocks the loop.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
{
  . "${DIR}/lib/common.sh"
  payload="$(cat)"  # hook JSON on stdin (session_id, transcript_path, cwd, ...)
  sid="$(printf '%s' "$payload" | sed -n 's/.*"session_id" *: *"\([^"]*\)".*/\1/p' | head -1)"
  ts="$(date -u +%FT%TZ)"
  sha="$(git -C "${CLAUDE_PROJECT_DIR}" rev-parse --short HEAD 2>/dev/null || echo none)"
  ledger_append "{\"run_id\":\"${sid:-unknown}\",\"ts\":\"${ts}\",\"git_sha\":\"${sha}\",\"outcome\":\"recorded\",\"source\":\"stop-hook\"}"
} >/dev/null 2>&1
exit 0
