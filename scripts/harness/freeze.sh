#!/usr/bin/env bash
# Hash-pin the anti-tamper spine (tests, lockfiles, CI, coverage config, SDD artifacts) + snapshot base SHA.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/../lib/common.sh"
cd "${CLAUDE_PROJECT_DIR}" || die "no project dir"
mkdir -p "${DATA_DIR}"; FROZEN="${DATA_DIR}/frozen.json"
base="$(git rev-parse HEAD 2>/dev/null || echo none)"
# Protected patterns (refine per project). Hash-pinned so the implementer cannot edit them undetected.
PAT='(\.(test|spec)\.|/tests?/|/__tests__/|/e2e/|(package|pnpm-lock|yarn|Cargo|poetry|uv)[^/]*(json|lock|toml)|/\.github/|jest|vitest|codecov|pyproject|setup\.cfg|tox|/specs/|tasks\.md|constitution)'
n=0; body=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  h="$(sha256sum "$f" | cut -d' ' -f1)"
  body="${body:+$body,}\"$f\":\"$h\""; n=$((n+1))
done < <(git ls-files | grep -E "$PAT" || true)
printf '{"base":"%s","ts":"%s","hashes":{%s}}\n' "$base" "$(date -u +%FT%TZ)" "$body" > "$FROZEN"
log "froze ${n} protected files @ ${base:0:12} → ${FROZEN}"
