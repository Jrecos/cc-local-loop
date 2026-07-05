#!/usr/bin/env bash
# Deterministic gate: scope -> hash-verify -> lint/type/build -> frozen tests -> coverage. Emits status JSON.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/../lib/common.sh"
cd "${CLAUDE_PROJECT_DIR}" || die "no project dir"
base="${1:-$(git rev-parse HEAD~1 2>/dev/null || echo HEAD)}"
status=pass; declare -a failing=()

# 1. scope gate — no protected path may appear in the diff (abort before running any test)
changed="$(git diff --name-only "${base}"..HEAD 2>/dev/null || true)"
if printf '%s\n' "$changed" | grep -Eq '(\.(test|spec)\.|/tests?/|/specs/|tasks\.md|constitution|/\.github/)'; then
  status=fail; failing+=("scope:protected-path-touched")
fi

# 2. hash-verify against frozen.json (protected files unchanged on disk)
# TODO(preflight): for each key in ${DATA_DIR}/frozen.json, compare sha256 on disk; mismatch => failing+=("hash:<file>")

# 3. lint / type / build / tests — run the FROZEN commands directly, NEVER `npm run <script>` (game-able).
# TODO(preflight): detect + wire the project's pinned runner. Example:
#   npm run -s lint      || { status=fail; failing+=("lint"); }
#   npm run -s typecheck || { status=fail; failing+=("typecheck"); }
#   npx --no-install jest --ci || { status=fail; failing+=("tests"); }

fj=""; for x in "${failing[@]:-}"; do [ -z "$x" ] && continue; fj="${fj:+$fj,}\"$x\""; done
nchanged="$(printf '%s\n' "$changed" | grep -c . )"
printf '{"status":"%s","base":"%s","changedFiles":%s,"failing":[%s]}\n' "$status" "$base" "${nchanged:-0}" "$fj"
[ "$status" = pass ]
