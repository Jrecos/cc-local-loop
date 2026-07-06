#!/usr/bin/env bash
# Hash-pin the anti-tamper spine (PROTECTED_PAT) + snapshot base SHA. FAILS CLOSED. Portable (macOS/Linux).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/../lib/common.sh"
cd "${CLAUDE_PROJECT_DIR}" || die "no project dir"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repo: ${CLAUDE_PROJECT_DIR}"
command -v jq >/dev/null 2>&1 || die "jq required"
mkdir -p "${DATA_DIR}"; FROZEN="${DATA_DIR}/frozen.json"
base="$(git rev-parse HEAD)"
tmp="$(mktemp)"; n=0
while IFS= read -r -d '' f; do
  [ -f "$f" ] || die "listed protected file missing on disk: $f"
  printf '%s\t%s\n' "$f" "$(sha256 "$f")" >> "$tmp"; n=$((n+1))
done < <(git -c core.quotePath=false ls-files -z | grep -zE "$PROTECTED_PAT" || true)
jq -Rn --arg base "$base" --arg ts "$(date -u +%FT%TZ)" '
  reduce inputs as $l ({}; ($l | split("\t")) as $p | .[$p[0]] = $p[1])
  | {base:$base, ts:$ts, hashes:.}' "$tmp" > "$FROZEN"
rm -f "$tmp"
[ "$n" -gt 0 ] || log "WARN: froze 0 protected files (no tests/specs/lockfiles matched)"
log "froze ${n} protected files @ ${base:0:12} → ${FROZEN}"
