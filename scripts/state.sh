#!/usr/bin/env bash
# Update the two-level loop state: STATUS.md (human morning-glance) + loop_state.json (machine logic).
# Usage: state.sh <phase> <iteration> <last_green_commit> <open_failures_csv> [blocked_csv]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
command -v jq >/dev/null 2>&1 || die "jq required"
phase="${1:?}"; iter="${2:-0}"; green="${3:-none}"; failures="${4:-}"; blocked="${5:-tests/,specs/,.github/,infra/}"
case "$iter" in ''|*[!0-9]*) iter=0;; esac
mkdir -p "${DATA_DIR}"
jq -n --arg p "$phase" --argjson i "$iter" --arg g "$green" --arg f "$failures" --arg b "$blocked" \
  '{phase:$p, iteration:$i, last_green_commit:$g,
    blocked_paths:($b|split(",")|map(select(length>0))),
    open_failures:($f|split(",")|map(select(length>0))),
    ts:(now|todateiso8601)}' > "${DATA_DIR}/loop_state.json"
{
  echo "# cc-local-loop — STATUS"; echo "_$(date -u +%FT%TZ)_"; echo
  echo "- phase: **${phase}** · iteration ${iter} · last green: \`${green}\`"
  echo "- open failures: ${failures:-none}"
  echo "- blocked (never touch without a human): ${blocked}"
} > "${DATA_DIR}/STATUS.md"
log "state → ${DATA_DIR}/{loop_state.json,STATUS.md}"
