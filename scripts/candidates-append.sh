#!/usr/bin/env bash
# Append ONE quarantined candidate lesson to the target project's candidates.jsonl (used by the reflect skill).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
obj="${1:?usage: candidates-append.sh '<json-candidate>'}"
command -v jq >/dev/null 2>&1 || die "jq required"
printf '%s' "$obj" | jq -e . >/dev/null || die "candidate is not valid JSON"
row="$(printf '%s' "$obj" | jq -c '. + {status:"quarantined", ts:(.ts // (now|todateiso8601)), created_by:(.created_by // "agent")}')"
mkdir -p "${DATA_DIR}"; printf '%s\n' "$row" >> "${DATA_DIR}/candidates.jsonl"
log "quarantined candidate → ${DATA_DIR}/candidates.jsonl"
