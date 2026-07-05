#!/usr/bin/env bash
# Whitelist gate for a lesson-promotion PR: the diff may touch ONLY lessons.md (+ promoted.jsonl). FAILS CLOSED.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
base="${1:-origin/main}"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repo"
git rev-parse --verify -q "${base}^{commit}" >/dev/null 2>&1 || die "bad/unresolvable base ref: ${base} (fail-closed)"
changed="$( { git diff --name-only "${base}...HEAD" 2>/dev/null; git diff --name-only; git diff --name-only --cached; } | sort -u | grep -v '^$' || true )"
[ -n "$changed" ] || die "no changes to promote"
bad="$(printf '%s\n' "$changed" | grep -vE '^(references/lessons\.md|\.cc-local-loop/promoted\.jsonl)$' || true)"
if [ -n "$bad" ]; then
  { echo "PR touches files outside the promotion whitelist:"; printf '  %s\n' $bad; } >&2
  die "a promotion PR must touch ONLY references/lessons.md (+ .cc-local-loop/promoted.jsonl) — never the yardstick/harness"
fi
log "promotion whitelist OK ($(printf '%s\n' "$changed" | grep -c .) file(s))"
