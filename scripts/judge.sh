#!/usr/bin/env bash
# The Gemma judge — raw two-pass /v1/chat/completions. No agent, no tools. FAILS CLOSED.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
JUDGE="${1:?usage: judge.sh <judge_model> <base>}"; BASE="${2:?base ref required}"

# fail-closed: any infra problem => REJECT (never approve on error)
health_check || { echo '{"verdict":"REJECT","reason":"infra: node-ai health failed"}'; exit 0; }

# TODO(preflight): build the context-pack (diff + FULL post-image of changed files + spec/AC + harness test output),
#   assert it fits the judge 32K KV, else escalate to Opus (NEVER silently truncate).
# TODO(preflight): pass 1 = free-form thinking review -> emits adversarial tests as fenced blocks (harness extracts);
#            pass 2 = grammar-constrained JSON verdict only -> {verdict,score,violations,adversarial_tests}.
# TODO(preflight): harness runs emitted tests in an EPHEMERAL worktree; non-compiling => JUDGE_TEST_INVALID
#            (discard + log, NEVER a task gate-fail).
die "judge is a scaffold — deploy node-ai Option-B (Gemma-31B + E2B draft), then wire the two-pass call (§15.5)"
