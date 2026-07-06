#!/usr/bin/env bash
# Two-level loop state. Two modes:
#   state.sh arm --feature <specs/NNN-x|auto> [--json]   → resolve feature, create data plane, write RUN_ID/ACTIVE
#   state.sh <phase> <iteration> <last_green_commit> <open_failures_csv> [blocked_csv]  → STATUS.md + loop_state.json
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
command -v jq >/dev/null 2>&1 || die "jq required"

# --- arm: resolve the active feature, create the data plane, write RUN_ID + ACTIVE ---
if [ "${1:-}" = "arm" ]; then
  shift; feat=""; want_json=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --feature)
        { [ "$#" -ge 2 ] && [ "${2#--}" = "$2" ]; } || die "arm: --feature requires a value"
        feat="$2"; shift 2;;
      --json) want_json=1; shift;;
      *) die "arm: unknown arg '$1'";;
    esac
  done
  if [ -z "$feat" ] || [ "$feat" = auto ]; then feat="$(bash "${DIR}/feature.sh" dir)"; fi
  # M3: reject absolute paths / traversal; require the feature dir to exist WITH tasks.md, under the project root.
  case "$feat" in /*|*..*) die "arm: illegal feature path '$feat' (no absolute paths or '..')";; esac
  featdir="${CLAUDE_PROJECT_DIR}/${feat}"
  [ -d "$featdir" ] || die "arm: feature dir not found: $feat"
  # N2: physical-path containment — a symlinked feature dir must not resolve OUTSIDE the project root.
  proot="$(cd "${CLAUDE_PROJECT_DIR}" && pwd -P)"; preal="$(cd "$featdir" && pwd -P)"
  case "$preal" in "$proot"/*) : ;; *) die "arm: feature '$feat' resolves outside the project root (symlink escape)";; esac
  [ -f "${featdir}/tasks.md" ] || die "arm: no tasks.md in $feat (run /speckit.tasks first)"
  data="${featdir}/ccloop"
  mkdir -p "${data}/ledger"
  # B3: keep the data plane OUT of git so gate.sh's untracked scan never scope-trips on the loop's own files.
  # N1: --git-path resolves the COMMON info/exclude that git actually READS — correct in the main repo, linked
  # worktrees, and .git-file submodules (--absolute-git-dir would point at a per-worktree dir git ignores).
  if excl="$(git -C "${CLAUDE_PROJECT_DIR}" rev-parse --git-path info/exclude 2>/dev/null)"; then
    case "$excl" in /*) : ;; *) excl="${CLAUDE_PROJECT_DIR}/${excl}";; esac
    mkdir -p "$(dirname "$excl")"
    if ! grep -q 'ccloop data plane' "$excl" 2>/dev/null; then
      { echo "# ccloop data plane (arm)"; echo "specs/*/ccloop/*"; echo "!specs/*/ccloop/promoted.jsonl"; } >> "$excl"
    fi
  fi
  rid="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  printf '%s\n' "$rid" > "${data}/RUN_ID"
  : > "${data}/ACTIVE"
  log "armed ${feat} (RUN_ID=${rid})"
  # N3: build the JSON with jq (never printf) so a quote in a dir name can't emit invalid JSON downstream.
  if [ "$want_json" -eq 1 ]; then jq -cn --arg f "$feat" --arg r "$rid" '{feature:$f,run_id:$r}'; fi
  exit 0
fi

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
