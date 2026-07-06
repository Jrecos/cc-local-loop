#!/usr/bin/env bash
# Append ONE quarantined candidate lesson to the target project's candidates.jsonl (used by the reflect skill).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
obj="${1:?usage: candidates-append.sh '<json-candidate>'}"
command -v jq >/dev/null 2>&1 || die "jq required"
printf '%s' "$obj" | jq -e 'type=="object"' >/dev/null 2>&1 || die "candidate must be a single JSON object"
[ "$(printf '%s' "$obj" | wc -c | tr -d ' ')" -le 8192 ] || die "candidate >8KB — a lesson is one operational imperative, not an essay"
CF="${DATA_DIR}/candidates.jsonl"; maxc="${CCLL_CAND_MAX:-50}"
cnt="$(grep -c . "$CF" 2>/dev/null || true)"; cnt="${cnt:-0}"
[ "$cnt" -lt "$maxc" ] || die "candidates.jsonl at cap (${maxc}) — run promote-lessons or prune the quarantine before adding more (G7 budget)"
row="$(printf '%s' "$obj" | jq -c '. + {status:"quarantined", ts:(.ts // (now|todateiso8601)), created_by:(.created_by // "agent")}')"
mkdir -p "${DATA_DIR}"; printf '%s\n' "$row" >> "$CF"
log "quarantined candidate → ${DATA_DIR}/candidates.jsonl"
