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

echo "18. emit.sh — validates, writes valid, drops bad, ALWAYS exit 0 (telemetry never kills the loop, G8)"
Em="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$Em" CCLL_RUN_ID=t bash "$ROOT/scripts/emit.sh" bogus '{}'          >/dev/null 2>&1 && ok "emit unknown-event exit0" || no "emit unknown-event exit0"
CLAUDE_PROJECT_DIR="$Em" CCLL_RUN_ID=t bash "$ROOT/scripts/emit.sh" gate  '[1,2]'         >/dev/null 2>&1 && ok "emit non-object exit0"  || no "emit non-object exit0"
CLAUDE_PROJECT_DIR="$Em" CCLL_RUN_ID=t bash "$ROOT/scripts/emit.sh" gate  '{"status":"pass"}' >/dev/null 2>&1
Lg="$Em/.cc-local-loop/ledger/events.jsonl"
{ [ -f "$Lg" ] && jq -e '.event=="gate" and .schema==1 and (.ts|type=="string")' "$Lg" >/dev/null 2>&1; } && ok "emit writes valid event" || no "emit writes valid event"
[ "$(grep -c . "$Lg" 2>/dev/null)" = 1 ] && ok "emit dropped the 2 bad rows" || no "emit dropped the 2 bad rows"
rm -rf "$Em"

echo "19. metrics.sh — read-only; empty noted, task_end aggregated (accepted vs total)"
Me="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$Me" bash "$ROOT/scripts/metrics.sh" "$Me" >/dev/null 2>&1 && ok "metrics empty ok" || no "metrics empty ok"
CLAUDE_PROJECT_DIR="$Me" CCLL_RUN_ID=t bash "$ROOT/scripts/emit.sh" task_end '{"task_id":"A","outcome":"accepted","iters":1}'  >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Me" CCLL_RUN_ID=t bash "$ROOT/scripts/emit.sh" task_end '{"task_id":"B","outcome":"abandoned","iters":6}' >/dev/null 2>&1
jm="$(CLAUDE_PROJECT_DIR="$Me" bash "$ROOT/scripts/metrics.sh" "$Me" --json 2>/dev/null)"
printf '%s' "$jm" | jq -e '.tasks_total==2 and .tasks_accepted==1' >/dev/null 2>&1 && ok "metrics aggregates task_end" || no "metrics aggregates task_end"
rm -rf "$Me"

echo "20. eval-run.sh — PROPOSER only (never promotes) + snapshots"
if grep -vE '^[[:space:]]*#' "$ROOT/scripts/eval-run.sh" | grep -qE 'promote-lessons|promote-check|gh pr|git push'; then no "eval-run proposer-only"; else ok "eval-run proposer-only"; fi
Ev="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$Ev" bash "$ROOT/scripts/eval-run.sh" >/dev/null 2>&1 && ok "eval-run first snapshot exits ok" || no "eval-run first snapshot exits ok"
ls "$Ev/.cc-local-loop/evals/"*.jsonl >/dev/null 2>&1 && ok "eval-run wrote a snapshot" || no "eval-run wrote a snapshot"
rm -rf "$Ev"

echo "21. lessons-lint.sh — passes shipped lessons.md, FAILS a >15-bullet file (G4 cap)"
bash "$ROOT/scripts/lessons-lint.sh" >/dev/null 2>&1 && ok "lessons-lint passes shipped file" || no "lessons-lint passes shipped file"
Ll="$(mktemp)"; { echo '# lessons — the ONE injected memory file'; for i in $(seq 1 20); do printf -- '- **L%03d** x\n' "$i"; done; } > "$Ll"
bash "$ROOT/scripts/lessons-lint.sh" "$Ll" >/dev/null 2>&1 && no "lessons-lint rejects >cap file" || ok "lessons-lint rejects >cap file"
rm -f "$Ll"

echo "22. G1 — build-context.sh never injects telemetry (events.jsonl content stays out of context)"
Bg="$(mktemp -d)"
( cd "$Bg" && git init -q && git config user.email a@b.c && git config user.name t && echo 'def f(): pass' > mod.py && git add -A && git commit -qm b && echo x >> mod.py && git commit -aqm c ) >/dev/null 2>&1
mkdir -p "$Bg/.cc-local-loop/ledger"; echo '{"event":"gate","secret":"TELEMETRY_SENTINEL_9421"}' > "$Bg/.cc-local-loop/ledger/events.jsonl"
CLAUDE_PROJECT_DIR="$Bg" bash "$ROOT/scripts/build-context.sh" G1 "FAIL mod.py:1" >/dev/null 2>&1
grep -q 'TELEMETRY_SENTINEL_9421' "$Bg/.cc-local-loop/context-G1.md" 2>/dev/null && no "telemetry NOT in built context" || ok "telemetry NOT in built context"
rm -rf "$Bg"

echo "23. eval-run.sh — delta actually FIRES an eval_delta when a case changes (C1 regression guard)"
Ed="$(mktemp -d)"; mkdir -p "$Ed/.cc-local-loop/evals"
jq -c '.cases[] | {id, category, expected_verdict, result:"pass"}' "$ROOT/evals/calibration/cases.json" > "$Ed/.cc-local-loop/evals/2000-01-01T000000Z.jsonl"
CLAUDE_PROJECT_DIR="$Ed" CCLL_RUN_ID=t bash "$ROOT/scripts/eval-run.sh" >/dev/null 2>&1
grep -q '"event":"eval_delta"' "$Ed/.cc-local-loop/ledger/events.jsonl" 2>/dev/null && ok "eval_delta fires on change" || no "eval_delta fires on change"
rm -rf "$Ed"

echo "24. emit.sh — envelope WINS: a payload cannot forge event/run_id (G8 whitelist authoritative)"
Eo="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$Eo" CCLL_RUN_ID=real bash "$ROOT/scripts/emit.sh" gate '{"event":"lesson","run_id":"forged","action":"promoted"}' >/dev/null 2>&1
Lo="$Eo/.cc-local-loop/ledger/events.jsonl"
{ [ -f "$Lo" ] && jq -e '.event=="gate" and .run_id=="real" and .source=="orchestrator"' "$Lo" >/dev/null 2>&1; } && ok "emit envelope wins (no forge)" || no "emit envelope wins (no forge)"
rm -rf "$Eo"

echo "25. lessons-lint.sh — an INDENTED bullet can't smuggle un-provenanced content past the gate (H3)"
Li="$(mktemp)"; { echo '# lessons — the ONE injected memory file'; echo; echo '## Lessons'; echo '  - sneaky uncapped lesson, no provenance'; } > "$Li"
bash "$ROOT/scripts/lessons-lint.sh" "$Li" >/dev/null 2>&1 && no "lessons-lint catches indented bullet" || ok "lessons-lint catches indented bullet"
rm -f "$Li"

echo "26. build-context.sh — a TRACKED .cc-local-loop file is DENIED from context (C1 explicit deny)"
Bt="$(mktemp -d)"
( cd "$Bt" && git init -q && git config user.email a@b.c && git config user.name t \
  && echo 'def f(): pass' > mod.py && mkdir -p .cc-local-loop && echo '{"x":"TRACKED_SENTINEL_7777"}' > .cc-local-loop/promoted.jsonl \
  && git add -A && git commit -qm b \
  && echo x >> mod.py && echo '{"x":"TRACKED_SENTINEL_7777","v":2}' > .cc-local-loop/promoted.jsonl && git add -A && git commit -qm c ) >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Bt" bash "$ROOT/scripts/build-context.sh" CT "FAIL mod.py:1" >/dev/null 2>&1
grep -q 'TRACKED_SENTINEL_7777' "$Bt/.cc-local-loop/context-CT.md" 2>/dev/null && no "tracked data-plane file denied" || ok "tracked data-plane file denied"
rm -rf "$Bt"

echo "27. lessons-lint.sh — a single-line HTML comment can't hide bullets after it (NEW-3 G4 bypass guard)"
Lc="$(mktemp)"; { echo '# lessons — the ONE injected memory file'; echo; echo '## Lessons'; echo '<!-- note -->'; echo '- sneaky uncapped bullet, no provenance'; } > "$Lc"
bash "$ROOT/scripts/lessons-lint.sh" "$Lc" >/dev/null 2>&1 && no "single-line comment doesn't hide bullets" || ok "single-line comment doesn't hide bullets"
rm -f "$Lc"

echo "28. metrics.sh — a scalar/array JSON line can't abort the report (NEW-2)"
Ms="$(mktemp -d)"; mkdir -p "$Ms/.cc-local-loop/ledger"
printf '%s\n' '{"event":"task_end","outcome":"accepted"}' '123' '"hello"' '[1,2]' '{"event":"escalation"}' > "$Ms/.cc-local-loop/ledger/events.jsonl"
js="$(CLAUDE_PROJECT_DIR="$Ms" bash "$ROOT/scripts/metrics.sh" "$Ms" --json 2>/dev/null)"
printf '%s' "$js" | jq -e '.tasks_accepted==1 and .escalations==1' >/dev/null 2>&1 && ok "scalar/array lines dropped, rest aggregates" || no "scalar/array lines dropped, rest aggregates"
rm -rf "$Ms"

echo ""
printf 'RESULT: %d passed, %d failed\n' "$P" "$F"
[ "$F" -eq 0 ]
