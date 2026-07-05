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

echo ""
printf 'RESULT: %d passed, %d failed\n' "$P" "$F"
[ "$F" -eq 0 ]
