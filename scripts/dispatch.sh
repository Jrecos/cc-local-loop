#!/usr/bin/env bash
# Dispatch a LOCAL-model executor INSIDE OpenCode's harness — fresh `opencode run` per task, NO --attach.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
IMPL="${1:?usage: dispatch.sh <impl_model> <task-id>}"; TASK="${2:?task-id required}"

# must be inside an active loop (run-loop writes the marker) — closes the trigger-suction bypass in CODE.
[ -f "${DATA_DIR}/ACTIVE" ] || die "no active loop (${DATA_DIR}/ACTIVE missing) — start via /cc-local-loop:run-loop"

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
