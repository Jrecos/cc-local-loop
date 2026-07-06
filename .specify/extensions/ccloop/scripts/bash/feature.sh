#!/usr/bin/env bash
# Resolve the active spec-kit feature dir + expose ccloop data-plane paths.
# Prefers spec-kit's own resolver; falls back to git-branch match, then newest specs/* with tasks.md.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh"

resolve_dir(){
  local root j pre
  root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  pre="$root/.specify/scripts/bash/check-prerequisites.sh"
  # 1) spec-kit resolver (authoritative)
  if [ -f "$pre" ]; then
    j="$(cd "$root" && bash "$pre" --json --require-tasks --include-tasks 2>/dev/null || true)"
    if [ -n "$j" ] && command -v jq >/dev/null 2>&1; then
      local d; d="$(printf '%s' "$j" | jq -r '.FEATURE_DIR // .feature_dir // empty' 2>/dev/null)"
      [ -n "$d" ] && { printf '%s\n' "${d#"$root"/}"; return 0; }
    fi
  fi
  # 2) git branch → specs/<branch>
  local br; br="$(cd "$root" && git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [ -n "$br" ] && [ -d "$root/specs/$br" ] && { printf 'specs/%s\n' "$br"; return 0; }
  # 3) newest specs/* containing tasks.md (portable; no GNU stat)
  local best="" f
  for f in "$root"/specs/*/tasks.md; do [ -f "$f" ] || continue; best="$f"; done
  [ -n "$best" ] && { local dd; dd="$(dirname "$best")"; printf '%s\n' "${dd#"$root"/}"; return 0; }
  die "no feature dir with tasks.md found (run /speckit.tasks first)"
}

case "${1:-dir}" in
  dir)  resolve_dir ;;
  data) printf '%s/ccloop\n' "$(resolve_dir)" ;;
  *)    die "usage: feature.sh {dir|data}" ;;
esac
