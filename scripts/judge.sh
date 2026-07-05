#!/usr/bin/env bash
# The Gemma judge — raw two-pass /v1/chat/completions. No agent, no tools. FAILS CLOSED.
# Exit: 0 = verdict on stdout ; 2 = infra-reject (escalate). Callers MUST parse stdout, never trust exit 0 alone.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
IMPL="${1:?usage: judge.sh <impl_model> <judge_model> <base>}"; JUDGE="${2:?judge_model required}"; BASE="${3:?base ref required}"
[ -f "${DATA_DIR}/ACTIVE" ] || die "no active loop (${DATA_DIR}/ACTIVE missing) — the judge only runs inside a run-loop"
assert_cross_family "$IMPL" "$JUDGE"    # the family that implemented never judges its own output
if ! health_check; then echo '{"verdict":"REJECT","reason":"infra: node-ai health failed","escalate":true}'; exit 2; fi
# TODO(preflight): build context-pack (diff + FULL changed files + spec/AC + harness output); assert < 32K KV else
#   escalate to Opus (never truncate). Pass 1 free-form -> fenced adversarial tests; pass 2 grammar-JSON verdict.
#   Harness runs the tests in a SANDBOXED ephemeral worktree (env -i, no network, ulimit, timeout);
#   non-compiling => JUDGE_TEST_INVALID (discard + log, NOT a task gate-fail).
die "judge is a scaffold — deploy node-ai Option-B (Gemma-31B + E2B draft), then wire the two-pass call (§15.5)"
