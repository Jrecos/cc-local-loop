#!/usr/bin/env bash
# Whitelist gate for a lesson-promotion PR: the diff may touch ONLY lessons.md (+ promoted.jsonl). FAILS CLOSED.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
base="${1:-origin/main}"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repo"
cd "$(git rev-parse --show-toplevel)" || die "cannot cd to repo root"   # pathspecs below must be repo-relative, not cwd-relative
git rev-parse --verify -q "${base}^{commit}" >/dev/null 2>&1 || die "bad/unresolvable base ref: ${base} (fail-closed)"
changed="$( { git diff --name-only "${base}...HEAD" 2>/dev/null; git diff --name-only; git diff --name-only --cached; } | sort -u | grep -v '^$' || true )"
[ -n "$changed" ] || die "no changes to promote"
bad="$(printf '%s\n' "$changed" | grep -vE '^(references/lessons\.md|(\.cc-local-loop|specs/[^/]+/ccloop)/promoted\.jsonl)$' || true)"
if [ -n "$bad" ]; then
  { echo "PR touches files outside the promotion whitelist:"; printf '%s\n' "$bad" | sed 's/^/  /'; } >&2
  die "a promotion PR must touch ONLY references/lessons.md (+ the ccloop promoted.jsonl) — never the yardstick/harness"
fi
# G5: a promotion is ADDITIVE (or a single amend/replace). A diff that deletes ≥2 existing **Lxxx** bullets is a
# wholesale rewrite — reject it (bulk pruning/re-authoring is a separate, explicit human PR, never bundled here).
# Count across committed + staged + worktree so a not-yet-committed bulk delete can't slip past the local check.
del="$( { git diff "${base}...HEAD" -- references/lessons.md; git diff -- references/lessons.md; git diff --cached -- references/lessons.md; } 2>/dev/null | grep -cE '^-.*\*\*L[0-9]+\*\*' || true)"
[ "${del:-0}" -le 1 ] || die "promotion deletes ${del} existing lesson bullets — promotions must be additive / single-amend (G5)"
bash "${DIR}/lessons-lint.sh" >/dev/null 2>&1 || die "post-promotion lessons.md fails lessons-lint (cap/provenance/shape)"
log "promotion whitelist OK ($(printf '%s\n' "$changed" | grep -c .) file(s))"
