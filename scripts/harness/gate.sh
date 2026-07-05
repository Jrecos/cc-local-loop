#!/usr/bin/env bash
# Deterministic gate. FAILS CLOSED, never fakes green. Emits status JSON; exit 0 only if truly all-green.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/../lib/common.sh"
cd "${CLAUDE_PROJECT_DIR}" || die "no project dir"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repo"
base="${1:?usage: gate.sh <base-ref>  (no default — the base is the security boundary)}"
git rev-parse --verify -q "${base}^{commit}" >/dev/null || die "bad base ref: ${base}"
FROZEN="${DATA_DIR}/frozen.json"
status=pass; failing=()

# 1. SCOPE — committed range + index + worktree + untracked, all vs the protected set (abort before any test).
changed="$( { git diff --name-only "${base}"; git diff --name-only --cached; \
              git ls-files --others --exclude-standard; } 2>/dev/null | sort -u )" || die "git introspection failed"
if printf '%s\n' "$changed" | grep -Eq "$PROTECTED_PAT"; then status=fail; failing+=("scope:protected-path-touched"); fi

# 2. HASH-VERIFY — every frozen file byte-identical on disk (IMPLEMENTED).
if [ -f "$FROZEN" ] && command -v jq >/dev/null 2>&1; then
  while IFS=$'\t' read -r f want; do
    [ -n "$f" ] || continue
    if [ ! -f "$f" ]; then status=fail; failing+=("hash:missing:$f"); continue; fi
    [ "$(sha256 "$f")" = "$want" ] || { status=fail; failing+=("hash-mismatch:$f"); }
  done < <(jq -r '.hashes // {} | to_entries[] | "\(.key)\t\(.value)"' "$FROZEN")
else
  status=fail; failing+=("hash:no-frozen.json — run harness/freeze.sh first")
fi

# 3. LINT / TYPE / BUILD / TESTS / COVERAGE — UNIMPLEMENTED. Wire the project's PINNED runner here, and remove
#    this line. NEVER `npm run <script>` (game-able); call the binary directly, e.g.:
#      npx --no-install eslint .        || failing+=("lint")
#      npx --no-install tsc --noEmit    || failing+=("typecheck")
#      npx --no-install jest --ci       || failing+=("tests")
status=fail; failing+=("unimplemented:lint-type-build-tests-coverage")

fj=""; for x in "${failing[@]:-}"; do [ -z "$x" ] && continue; fj="${fj:+$fj,}\"$x\""; done
nchanged="$(printf '%s\n' "$changed" | grep -c . || true)"
printf '{"status":"%s","base":"%s","changedFiles":%s,"failing":[%s]}\n' "$status" "$base" "${nchanged:-0}" "$fj"
[ "$status" = pass ]
