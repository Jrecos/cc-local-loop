#!/usr/bin/env bash
# Dispatch a LOCAL-model executor INSIDE OpenCode's harness — fresh `opencode run` per task, NO --attach.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
IMPL="${1:?usage: dispatch.sh <impl_model> <task-id>}"; TASK="${2:?task-id required}"

# derive the judge by the cross-family invariant (Gemma impls are judged by Qwen judge-mode)
JUDGE="${CCLL_JUDGE_MODEL:-gemma-4-31b-it}"
[ "$(family_of "$IMPL")" = google ] && JUDGE="${CCLL_GEMMA_JUDGE:-qwen3.6-35b}"
assert_cross_family "$IMPL" "$JUDGE"
health_check || die "node-ai health failed (${NODE_AI_URL}) — refusing to dispatch"

# per-task scope: deny-by-default + in-scope allow-list + protected globs re-emitted LAST
# TODO(preflight): parse [scope:...] from tasks.md for ${TASK}; hardened default below:
: "${OPENCODE_PERMISSION:={\"edit\":{\"*\":\"deny\",\"**/*.{test,spec}.*\":\"deny\",\"**/specs/**\":\"deny\"},\"bash\":\"deny\",\"webfetch\":\"deny\"}}"
export OPENCODE_PERMISSION OPENCODE_DISABLE_CLAUDE_CODE=1

log "dispatch: impl=${IMPL} judge=${JUDGE} task=${TASK} (fresh opencode run, no --attach)"
# TODO(preflight): requires OpenCode configured with a node-ai provider + Option-B serving. Then:
#   opencode run --agent implementer --model "node-ai/${IMPL}" --auto --format json \
#     -f "task-${TASK}.md" "Implement task-${TASK}.md. Do not run commands." \
#     > "run-${TASK}.jsonl" 2> "run-${TASK}.err"
#   # authoritative change set = git diff, NOT the event stream.
die "dispatch is a scaffold — deploy node-ai Option-B + configure OpenCode, then remove this guard (§15.5)"
