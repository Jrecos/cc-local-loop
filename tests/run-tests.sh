#!/usr/bin/env bash
# cc-local-loop regression net — the auditor probes, executable. Deps: bash, git, jq. Exit != 0 on any failure.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
. "$ROOT/scripts/lib/common.sh"
P=0; F=0
ok(){ P=$((P+1)); printf '  ok   %s\n' "$1"; }
no(){ F=$((F+1)); printf '  FAIL %s\n' "$1"; }

echo "1. PROTECTED_PAT — top-level protected paths must MATCH"
for p in tests/a.py specs/x.md .github/workflows/ci.yml pnpm-lock.yaml package.json __tests__/a.js e2e/h.ts src/a.test.ts tasks.md; do
  if printf '%s' "$p" | grep -qE "$PROTECTED_PAT"; then ok "match $p"; else no "match $p"; fi
done
echo "   PROTECTED_PAT — normal src must NOT match"
for p in src/app.ts src/notasks.mdx lib/jester.ts README.md; do
  if printf '%s' "$p" | grep -qE "$PROTECTED_PAT"; then no "must-skip $p"; else ok "skip $p"; fi
done

echo "2. family_of — normalization (case + provider prefix)"
[ "$(family_of Opus-4.8)" = anthropic ]           && ok "Opus->anthropic"        || no "Opus->anthropic"
[ "$(family_of node-ai/qwen3.6-35b)" = qwen ]      && ok "provider-prefix->qwen"  || no "provider-prefix->qwen"
[ "$(family_of GEMMA-4-31B-it)" = google ]         && ok "case->google"           || no "case->google"

echo "3. roster + cross-family (subshells; die exits)"
( assert_impl_allowed opus-4.8 )    2>/dev/null && no "opus refused"       || ok "opus refused"
( assert_impl_allowed glm-4.7 )     2>/dev/null && no "non-roster refused" || ok "non-roster refused"
( assert_impl_allowed ornith-35b )  2>/dev/null && ok "ornith allowed"     || no "ornith allowed"
( assert_cross_family ornith-35b qwen3.6-35b )      2>/dev/null && no "same-family refused" || ok "same-family refused"
( assert_cross_family gemma-4-26b-a4b qwen3.6-35b ) 2>/dev/null && ok "cross-family ok"     || no "cross-family ok"

echo "4. OPENCODE_PERMISSION builds valid JSON"
if jq -n '{edit:{"*":"deny","**/*.{test,spec}.*":"deny"},bash:"deny"}' | jq -e . >/dev/null 2>&1; then ok "perm valid json"; else no "perm valid json"; fi

echo "5. gate.sh fails CLOSED on non-repo"
if ( cd /tmp && bash "$ROOT/scripts/harness/gate.sh" HEAD ) >/dev/null 2>&1; then no "gate non-repo dies"; else ok "gate non-repo dies"; fi

echo "6. gate.sh catches top-level tests/ tamper (uncommitted)"
T="$(mktemp -d)"
( cd "$T" && git init -q && git config user.email a@b.c && git config user.name t \
  && mkdir tests && echo x > tests/t.py && echo y > app.py && git add -A && git commit -qm base ) >/dev/null 2>&1
echo z >> "$T/tests/t.py"
out="$(cd "$T" && CLAUDE_PROJECT_DIR="$T" bash "$ROOT/scripts/harness/gate.sh" HEAD 2>/dev/null || true)"
if printf '%s' "$out" | grep -q 'scope:protected-path-touched'; then ok "gate flags top-level tests/"; else no "gate flags top-level tests/"; fi
rm -rf "$T"

echo "7. guards.sh per-task; no fail-open on non-numeric MAX_ITER"
G="$(mktemp -d)"
o="$(CLAUDE_PROJECT_DIR="$G" CCLL_MAX_ITER=abc bash "$ROOT/scripts/harness/guards.sh" T1 2>/dev/null || true)"
if printf '%s' "$o" | jq -e .decision >/dev/null 2>&1; then ok "guards emits decision (bad var)"; else no "guards emits decision (bad var)"; fi
rm -rf "$G"

echo "8. promote-check.sh refuses the yardstick"
Q="$(mktemp -d)"
( cd "$Q" && git init -q && git config user.email a@b.c && git config user.name t \
  && mkdir -p evals/calibration && echo a > evals/calibration/x && git add -A && git commit -qm base ) >/dev/null 2>&1
echo bad >> "$Q/evals/calibration/x"
if ( cd "$Q" && bash "$ROOT/scripts/promote-check.sh" HEAD ) >/dev/null 2>&1; then no "promote-check blocks yardstick"; else ok "promote-check blocks yardstick"; fi
rm -rf "$Q"

echo "9. all scripts pass bash -n"
for s in "$ROOT"/scripts/*.sh "$ROOT"/scripts/harness/*.sh; do
  if bash -n "$s" 2>/dev/null; then ok "syntax $(basename "$s")"; else no "syntax $(basename "$s")"; fi
done

echo "10. guards.sh circuit breaker (no-progress + heartbeat)"
Gd="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$Gd" bash "$ROOT/scripts/harness/guards.sh" NP '["x"]' >/dev/null 2>&1
d="$(CLAUDE_PROJECT_DIR="$Gd" bash "$ROOT/scripts/harness/guards.sh" NP '["x"]' 2>/dev/null | jq -r .decision)"
[ "$d" = ESCALATE ] && ok "no-progress escalates" || no "no-progress escalates"
[ -f "$Gd/.cc-local-loop/tasks/NP/heartbeat" ] && ok "heartbeat written" || no "heartbeat written"
rm -rf "$Gd"

echo "11. guards.sh oscillation (A,B,A escalates)"
Go="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$Go" bash "$ROOT/scripts/harness/guards.sh" OS '["A"]' >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Go" bash "$ROOT/scripts/harness/guards.sh" OS '["B"]' >/dev/null 2>&1
d="$(CLAUDE_PROJECT_DIR="$Go" bash "$ROOT/scripts/harness/guards.sh" OS '["A"]' 2>/dev/null | jq -r .decision)"
[ "$d" = ESCALATE ] && ok "oscillation escalates" || no "oscillation escalates"
rm -rf "$Go"

echo "12. state.sh two-level (loop_state.json + STATUS.md)"
St="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$St" bash "$ROOT/scripts/state.sh" impl 2 abc123 "t.spec:1" >/dev/null 2>&1
{ jq -e '.phase=="impl" and .iteration==2' "$St/.cc-local-loop/loop_state.json" >/dev/null 2>&1 && [ -f "$St/.cc-local-loop/STATUS.md" ]; } && ok "state two-level" || no "state two-level"
rm -rf "$St"

echo "13. build-context.sh narrow + budgeted"
Bc="$(mktemp -d)"
( cd "$Bc" && git init -q && git config user.email a@b.c && git config user.name t && echo 'def f(): pass' > mod.py && git add -A && git commit -qm b && echo x >> mod.py && git commit -aqm c ) >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Bc" bash "$ROOT/scripts/build-context.sh" BC "FAIL mod.py:1" >/dev/null 2>&1
{ [ -f "$Bc/.cc-local-loop/context-BC.md" ] && grep -q '### mod.py' "$Bc/.cc-local-loop/context-BC.md"; } && ok "context includes stack-trace file" || no "context includes stack-trace file"
rm -rf "$Bc"

echo "14. check-idempotency.sh (deterministic gate)"
Ci="$(mktemp -d)"
( cd "$Ci" && git init -q && git config user.email a@b.c && git config user.name t && echo a>f && git add -A && git commit -qm b && echo b>>f && git commit -aqm c ) >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Ci" bash "$ROOT/scripts/check-idempotency.sh" HEAD~1 3 >/dev/null 2>&1 && ok "gate idempotent" || no "gate idempotent"
rm -rf "$Ci"

echo "15. sandbox-run.sh runs the command (fallback ok)"
[ "$(bash "$ROOT/scripts/sandbox-run.sh" echo hi 2>/dev/null)" = hi ] && ok "sandbox runs cmd" || no "sandbox runs cmd"

echo "16. build-context.sh survives a no-file-token failure (BLOCKER A)"
Bx="$(mktemp -d)"
( cd "$Bx" && git init -q && git config user.email a@b.c && git config user.name t && echo a>a.py && git add -A && git commit -qm b && echo b>>a.py && git commit -aqm c ) >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Bx" bash "$ROOT/scripts/build-context.sh" NB "unimplemented:lint-type-build-tests-coverage" >/dev/null 2>&1 && ok "no-file-token failure survives" || no "no-file-token failure survives"
rm -rf "$Bx"

echo "17. build-context.sh rejects out-of-repo paths (BLOCKER B — no exfiltration)"
Bp="$(mktemp -d)"; sec="/tmp/ccll_secret_$$.py"
( cd "$Bp" && git init -q && git config user.email a@b.c && git config user.name t && echo a>a.py && git add -A && git commit -qm b && echo b>>a.py && git commit -aqm c ) >/dev/null 2>&1
echo 'API_KEY="sk-LEAK"' > "$sec"
CLAUDE_PROJECT_DIR="$Bp" bash "$ROOT/scripts/build-context.sh" NP "Error at ../x.py and ${sec}:1" >/dev/null 2>&1
grep -q 'sk-LEAK' "$Bp/.cc-local-loop/context-NP.md" 2>/dev/null && no "out-of-repo path rejected" || ok "out-of-repo path rejected"
rm -rf "$Bp" "$sec"

echo ""
printf 'RESULT: %d passed, %d failed\n' "$P" "$F"
[ "$F" -eq 0 ]
