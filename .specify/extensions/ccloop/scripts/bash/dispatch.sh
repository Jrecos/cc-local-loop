#!/usr/bin/env bash
# Dispatch a LOCAL-model executor INSIDE OpenCode's harness — fresh `opencode run` per task, NO --attach.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"

# `next` mode (the workflow's loop body): select the next OPEN task, mark it dispatched, then proceed to the
# (currently die-guarded) adapter invocation. --no-op-if-closed makes the guaranteed first do-while pass safe.
if [ "${1:-}" = "next" ]; then
  shift; noop_if_closed=0
  while [ "$#" -gt 0 ]; do case "$1" in --no-op-if-closed) noop_if_closed=1;; --detach) : ;; *) : ;; esac; shift; done
  NEXT_TASK="$(awk -F'|' '/^\| *T[0-9]/{s=$3;gsub(/ /,"",s); t=$2;gsub(/ /,"",t); if(s!="judge-pass"&&s!="human-signed"){print t; exit}}' "${DATA_DIR}/progress.md" 2>/dev/null || true)"
  if [ -z "$NEXT_TASK" ]; then
    [ "$noop_if_closed" -eq 1 ] && { log "dispatch: no open task — no-op"; exit 0; }
    die "dispatch: no open task to dispatch"
  fi
  bash "${DIR}/progress-lint.sh" record "$NEXT_TASK" dispatched >/dev/null 2>&1 || true
  set -- "${CCLL_IMPL_MODEL:-qwen3.6-35b}" "$NEXT_TASK"
fi

IMPL="${1:?usage: dispatch.sh <impl_model> <task-id>  |  dispatch.sh next [--detach] [--no-op-if-closed]}"; TASK="${2:?task-id required}"

# must be inside an active loop (arm writes the marker) — closes the trigger-suction bypass in CODE.
[ -f "${DATA_DIR}/ACTIVE" ] || die "no active loop (${DATA_DIR}/ACTIVE missing) — start via /speckit.ccloop.run"

assert_impl_allowed "$IMPL"                       # roster + Opus-refusal
JUDGE="${CCLL_JUDGE_MODEL:-gemma-4-31b-it}"
[ "$(family_of "$IMPL")" = google ] && JUDGE="${CCLL_GEMMA_JUDGE:-qwen3.6-35b}"   # cross-family for Gemma impls
assert_cross_family "$IMPL" "$JUDGE"
health_check || die "node-ai health failed (${NODE_AI_URL}) — refusing to dispatch"

# per-task scope: deny-by-default, built with jq so it is ALWAYS valid JSON; assigned UNCONDITIONALLY (no env inherit).
# TODO(preflight): parse [scope:...] from tasks.md for ${TASK} and inject per-task allows BEFORE the protected denies.
if command -v jq >/dev/null 2>&1; then
  OPENCODE_PERMISSION="$(jq -n '{edit:{"*":"deny","**/*.{test,spec}.*":"deny","**/specs/**":"deny","**/tasks.md":"deny"},bash:"deny",webfetch:"deny"}')"
  printf '%s' "$OPENCODE_PERMISSION" | jq -e . >/dev/null || die "OPENCODE_PERMISSION not valid JSON (fail-closed)"
else
  OPENCODE_PERMISSION='{"edit":{"*":"deny"},"bash":"deny","webfetch":"deny"}'
fi
export OPENCODE_PERMISSION OPENCODE_DISABLE_CLAUDE_CODE=1

log "dispatch: impl=${IMPL} judge=${JUDGE} task=${TASK} (fresh opencode run, no --attach)"
# TODO(preflight): requires OpenCode with a node-ai provider + Option-B serving. Then:
#   opencode run --agent implementer --model "node-ai/${IMPL}" --auto --format json \
#     -f "task-${TASK}.md" "Implement task-${TASK}.md. Honor references/lessons.md. Do not run commands." \
#     > "run-${TASK}.jsonl" 2> "run-${TASK}.err"   # authoritative change set = git diff, NOT the event stream
die "dispatch is a scaffold — deploy node-ai Option-B + configure OpenCode, then remove this guard (§15.5)"
