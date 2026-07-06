#!/usr/bin/env bash
# cc-local-loop regression net — the auditor probes, executable. Deps: bash, git, jq. Exit != 0 on any failure.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
. "$ROOT/.specify/extensions/ccloop/scripts/bash/lib/common.sh"
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
if ( cd /tmp && bash "$ROOT/.specify/extensions/ccloop/scripts/bash/harness/gate.sh" HEAD ) >/dev/null 2>&1; then no "gate non-repo dies"; else ok "gate non-repo dies"; fi

echo "6. gate.sh catches top-level tests/ tamper (uncommitted)"
T="$(mktemp -d)"
( cd "$T" && git init -q && git config user.email a@b.c && git config user.name t \
  && mkdir tests && echo x > tests/t.py && echo y > app.py && git add -A && git commit -qm base ) >/dev/null 2>&1
echo z >> "$T/tests/t.py"
out="$(cd "$T" && CLAUDE_PROJECT_DIR="$T" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/harness/gate.sh" HEAD 2>/dev/null || true)"
if printf '%s' "$out" | grep -q 'scope:protected-path-touched'; then ok "gate flags top-level tests/"; else no "gate flags top-level tests/"; fi
rm -rf "$T"

echo "7. guards.sh per-task; no fail-open on non-numeric MAX_ITER"
G="$(mktemp -d)"
o="$(CLAUDE_PROJECT_DIR="$G" CCLL_MAX_ITER=abc bash "$ROOT/.specify/extensions/ccloop/scripts/bash/harness/guards.sh" T1 2>/dev/null || true)"
if printf '%s' "$o" | jq -e .decision >/dev/null 2>&1; then ok "guards emits decision (bad var)"; else no "guards emits decision (bad var)"; fi
rm -rf "$G"

echo "8. promote-check.sh refuses the yardstick"
Q="$(mktemp -d)"
( cd "$Q" && git init -q && git config user.email a@b.c && git config user.name t \
  && mkdir -p evals/calibration && echo a > evals/calibration/x && git add -A && git commit -qm base ) >/dev/null 2>&1
echo bad >> "$Q/evals/calibration/x"
if ( cd "$Q" && bash "$ROOT/.specify/extensions/ccloop/scripts/bash/promote-check.sh" HEAD ) >/dev/null 2>&1; then no "promote-check blocks yardstick"; else ok "promote-check blocks yardstick"; fi
rm -rf "$Q"

echo "9. all scripts pass bash -n"
for s in "$ROOT"/.specify/extensions/ccloop/scripts/bash/*.sh "$ROOT"/.specify/extensions/ccloop/scripts/bash/harness/*.sh; do
  if bash -n "$s" 2>/dev/null; then ok "syntax $(basename "$s")"; else no "syntax $(basename "$s")"; fi
done

echo "10. guards.sh circuit breaker (no-progress + heartbeat)"
Gd="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$Gd" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/harness/guards.sh" NP '["x"]' >/dev/null 2>&1
d="$(CLAUDE_PROJECT_DIR="$Gd" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/harness/guards.sh" NP '["x"]' 2>/dev/null | jq -r .decision)"
[ "$d" = ESCALATE ] && ok "no-progress escalates" || no "no-progress escalates"
[ -f "$Gd/.cc-local-loop/tasks/NP/heartbeat" ] && ok "heartbeat written" || no "heartbeat written"
rm -rf "$Gd"

echo "11. guards.sh oscillation (A,B,A escalates)"
Go="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$Go" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/harness/guards.sh" OS '["A"]' >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Go" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/harness/guards.sh" OS '["B"]' >/dev/null 2>&1
d="$(CLAUDE_PROJECT_DIR="$Go" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/harness/guards.sh" OS '["A"]' 2>/dev/null | jq -r .decision)"
[ "$d" = ESCALATE ] && ok "oscillation escalates" || no "oscillation escalates"
rm -rf "$Go"

echo "12. state.sh two-level (loop_state.json + STATUS.md)"
St="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$St" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/state.sh" impl 2 abc123 "t.spec:1" >/dev/null 2>&1
{ jq -e '.phase=="impl" and .iteration==2' "$St/.cc-local-loop/loop_state.json" >/dev/null 2>&1 && [ -f "$St/.cc-local-loop/STATUS.md" ]; } && ok "state two-level" || no "state two-level"
rm -rf "$St"

echo "13. build-context.sh narrow + budgeted"
Bc="$(mktemp -d)"
( cd "$Bc" && git init -q && git config user.email a@b.c && git config user.name t && echo 'def f(): pass' > mod.py && git add -A && git commit -qm b && echo x >> mod.py && git commit -aqm c ) >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Bc" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/build-context.sh" BC "FAIL mod.py:1" >/dev/null 2>&1
{ [ -f "$Bc/.cc-local-loop/context-BC.md" ] && grep -q '### mod.py' "$Bc/.cc-local-loop/context-BC.md"; } && ok "context includes stack-trace file" || no "context includes stack-trace file"
rm -rf "$Bc"

echo "14. check-idempotency.sh (deterministic gate)"
Ci="$(mktemp -d)"
( cd "$Ci" && git init -q && git config user.email a@b.c && git config user.name t && echo a>f && git add -A && git commit -qm b && echo b>>f && git commit -aqm c ) >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Ci" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/check-idempotency.sh" HEAD~1 3 >/dev/null 2>&1 && ok "gate idempotent" || no "gate idempotent"
rm -rf "$Ci"

echo "15. sandbox-run.sh runs the command (fallback ok)"
[ "$(bash "$ROOT/.specify/extensions/ccloop/scripts/bash/sandbox-run.sh" echo hi 2>/dev/null)" = hi ] && ok "sandbox runs cmd" || no "sandbox runs cmd"

echo "15b. sandbox-run.sh forced-fallback (no live runtime) still runs cmd — macOS portability"
[ "$(CCLL_SANDBOX_RUNTIME=none bash "$ROOT/.specify/extensions/ccloop/scripts/bash/sandbox-run.sh" echo hi 2>/dev/null)" = hi ] && ok "sandbox fallback runs cmd (no timeout/gtimeout)" || no "sandbox fallback runs cmd"

echo "16. build-context.sh survives a no-file-token failure (BLOCKER A)"
Bx="$(mktemp -d)"
( cd "$Bx" && git init -q && git config user.email a@b.c && git config user.name t && echo a>a.py && git add -A && git commit -qm b && echo b>>a.py && git commit -aqm c ) >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Bx" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/build-context.sh" NB "unimplemented:lint-type-build-tests-coverage" >/dev/null 2>&1 && ok "no-file-token failure survives" || no "no-file-token failure survives"
rm -rf "$Bx"

echo "17. build-context.sh rejects out-of-repo paths (BLOCKER B — no exfiltration)"
Bp="$(mktemp -d)"; sec="/tmp/ccll_secret_$$.py"
( cd "$Bp" && git init -q && git config user.email a@b.c && git config user.name t && echo a>a.py && git add -A && git commit -qm b && echo b>>a.py && git commit -aqm c ) >/dev/null 2>&1
echo 'API_KEY="sk-LEAK"' > "$sec"
CLAUDE_PROJECT_DIR="$Bp" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/build-context.sh" NP "Error at ../x.py and ${sec}:1" >/dev/null 2>&1
grep -q 'sk-LEAK' "$Bp/.cc-local-loop/context-NP.md" 2>/dev/null && no "out-of-repo path rejected" || ok "out-of-repo path rejected"
rm -rf "$Bp" "$sec"

echo "18. emit.sh — validates, writes valid, drops bad, ALWAYS exit 0 (telemetry never kills the loop, G8)"
Em="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$Em" CCLL_RUN_ID=t bash "$ROOT/.specify/extensions/ccloop/scripts/bash/emit.sh" bogus '{}'          >/dev/null 2>&1 && ok "emit unknown-event exit0" || no "emit unknown-event exit0"
CLAUDE_PROJECT_DIR="$Em" CCLL_RUN_ID=t bash "$ROOT/.specify/extensions/ccloop/scripts/bash/emit.sh" gate  '[1,2]'         >/dev/null 2>&1 && ok "emit non-object exit0"  || no "emit non-object exit0"
CLAUDE_PROJECT_DIR="$Em" CCLL_RUN_ID=t bash "$ROOT/.specify/extensions/ccloop/scripts/bash/emit.sh" gate  '{"status":"pass"}' >/dev/null 2>&1
Lg="$Em/.cc-local-loop/ledger/events.jsonl"
{ [ -f "$Lg" ] && jq -e '.event=="gate" and .schema==1 and (.ts|type=="string")' "$Lg" >/dev/null 2>&1; } && ok "emit writes valid event" || no "emit writes valid event"
[ "$(grep -c . "$Lg" 2>/dev/null)" = 1 ] && ok "emit dropped the 2 bad rows" || no "emit dropped the 2 bad rows"
rm -rf "$Em"

echo "19. metrics.sh — read-only; empty noted, task_end aggregated (accepted vs total)"
Me="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$Me" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/metrics.sh" "$Me" >/dev/null 2>&1 && ok "metrics empty ok" || no "metrics empty ok"
CLAUDE_PROJECT_DIR="$Me" CCLL_RUN_ID=t bash "$ROOT/.specify/extensions/ccloop/scripts/bash/emit.sh" task_end '{"task_id":"A","outcome":"accepted","iters":1}'  >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Me" CCLL_RUN_ID=t bash "$ROOT/.specify/extensions/ccloop/scripts/bash/emit.sh" task_end '{"task_id":"B","outcome":"abandoned","iters":6}' >/dev/null 2>&1
jm="$(CLAUDE_PROJECT_DIR="$Me" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/metrics.sh" "$Me" --json 2>/dev/null)"
printf '%s' "$jm" | jq -e '.tasks_total==2 and .tasks_accepted==1' >/dev/null 2>&1 && ok "metrics aggregates task_end" || no "metrics aggregates task_end"
rm -rf "$Me"

echo "20. eval-run.sh — PROPOSER only (never promotes) + snapshots"
if grep -vE '^[[:space:]]*#' "$ROOT/.specify/extensions/ccloop/scripts/bash/eval-run.sh" | grep -qE 'promote-lessons|promote-check|gh pr|git push'; then no "eval-run proposer-only"; else ok "eval-run proposer-only"; fi
Ev="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$Ev" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/eval-run.sh" >/dev/null 2>&1 && ok "eval-run first snapshot exits ok" || no "eval-run first snapshot exits ok"
ls "$Ev/.cc-local-loop/evals/"*.jsonl >/dev/null 2>&1 && ok "eval-run wrote a snapshot" || no "eval-run wrote a snapshot"
rm -rf "$Ev"

echo "21. lessons-lint.sh — passes shipped lessons.md, FAILS a >15-bullet file (G4 cap)"
bash "$ROOT/.specify/extensions/ccloop/scripts/bash/lessons-lint.sh" >/dev/null 2>&1 && ok "lessons-lint passes shipped file" || no "lessons-lint passes shipped file"
Ll="$(mktemp)"; { echo '# lessons — the ONE injected memory file'; for i in $(seq 1 20); do printf -- '- **L%03d** x\n' "$i"; done; } > "$Ll"
bash "$ROOT/.specify/extensions/ccloop/scripts/bash/lessons-lint.sh" "$Ll" >/dev/null 2>&1 && no "lessons-lint rejects >cap file" || ok "lessons-lint rejects >cap file"
rm -f "$Ll"

echo "22. G1 — build-context.sh never injects telemetry (events.jsonl content stays out of context)"
Bg="$(mktemp -d)"
( cd "$Bg" && git init -q && git config user.email a@b.c && git config user.name t && echo 'def f(): pass' > mod.py && git add -A && git commit -qm b && echo x >> mod.py && git commit -aqm c ) >/dev/null 2>&1
mkdir -p "$Bg/.cc-local-loop/ledger"; echo '{"event":"gate","secret":"TELEMETRY_SENTINEL_9421"}' > "$Bg/.cc-local-loop/ledger/events.jsonl"
CLAUDE_PROJECT_DIR="$Bg" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/build-context.sh" G1 "FAIL mod.py:1" >/dev/null 2>&1
grep -q 'TELEMETRY_SENTINEL_9421' "$Bg/.cc-local-loop/context-G1.md" 2>/dev/null && no "telemetry NOT in built context" || ok "telemetry NOT in built context"
rm -rf "$Bg"

echo "23. eval-run.sh — delta actually FIRES an eval_delta when a case changes (C1 regression guard)"
Ed="$(mktemp -d)"; mkdir -p "$Ed/.cc-local-loop/evals"
jq -c '.cases[] | {id, category, expected_verdict, result:"pass"}' "$ROOT/.specify/extensions/ccloop/evals/calibration/cases.json" > "$Ed/.cc-local-loop/evals/2000-01-01T000000Z.jsonl"
CLAUDE_PROJECT_DIR="$Ed" CCLL_RUN_ID=t bash "$ROOT/.specify/extensions/ccloop/scripts/bash/eval-run.sh" >/dev/null 2>&1
grep -q '"event":"eval_delta"' "$Ed/.cc-local-loop/ledger/events.jsonl" 2>/dev/null && ok "eval_delta fires on change" || no "eval_delta fires on change"
rm -rf "$Ed"

echo "24. emit.sh — envelope WINS: a payload cannot forge event/run_id (G8 whitelist authoritative)"
Eo="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$Eo" CCLL_RUN_ID=real bash "$ROOT/.specify/extensions/ccloop/scripts/bash/emit.sh" gate '{"event":"lesson","run_id":"forged","action":"promoted"}' >/dev/null 2>&1
Lo="$Eo/.cc-local-loop/ledger/events.jsonl"
{ [ -f "$Lo" ] && jq -e '.event=="gate" and .run_id=="real" and .source=="orchestrator"' "$Lo" >/dev/null 2>&1; } && ok "emit envelope wins (no forge)" || no "emit envelope wins (no forge)"
rm -rf "$Eo"

echo "25. lessons-lint.sh — an INDENTED bullet can't smuggle un-provenanced content past the gate (H3)"
Li="$(mktemp)"; { echo '# lessons — the ONE injected memory file'; echo; echo '## Lessons'; echo '  - sneaky uncapped lesson, no provenance'; } > "$Li"
bash "$ROOT/.specify/extensions/ccloop/scripts/bash/lessons-lint.sh" "$Li" >/dev/null 2>&1 && no "lessons-lint catches indented bullet" || ok "lessons-lint catches indented bullet"
rm -f "$Li"

echo "26. build-context.sh — a TRACKED .cc-local-loop file is DENIED from context (C1 explicit deny)"
Bt="$(mktemp -d)"
( cd "$Bt" && git init -q && git config user.email a@b.c && git config user.name t \
  && echo 'def f(): pass' > mod.py && mkdir -p .cc-local-loop && echo '{"x":"TRACKED_SENTINEL_7777"}' > .cc-local-loop/promoted.jsonl \
  && git add -A && git commit -qm b \
  && echo x >> mod.py && echo '{"x":"TRACKED_SENTINEL_7777","v":2}' > .cc-local-loop/promoted.jsonl && git add -A && git commit -qm c ) >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Bt" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/build-context.sh" CT "FAIL mod.py:1" >/dev/null 2>&1
grep -q 'TRACKED_SENTINEL_7777' "$Bt/.cc-local-loop/context-CT.md" 2>/dev/null && no "tracked data-plane file denied" || ok "tracked data-plane file denied"
rm -rf "$Bt"

echo "27. lessons-lint.sh — a single-line HTML comment can't hide bullets after it (NEW-3 G4 bypass guard)"
Lc="$(mktemp)"; { echo '# lessons — the ONE injected memory file'; echo; echo '## Lessons'; echo '<!-- note -->'; echo '- sneaky uncapped bullet, no provenance'; } > "$Lc"
bash "$ROOT/.specify/extensions/ccloop/scripts/bash/lessons-lint.sh" "$Lc" >/dev/null 2>&1 && no "single-line comment doesn't hide bullets" || ok "single-line comment doesn't hide bullets"
rm -f "$Lc"

echo "28. metrics.sh — a scalar/array JSON line can't abort the report (NEW-2)"
Ms="$(mktemp -d)"; mkdir -p "$Ms/.cc-local-loop/ledger"
printf '%s\n' '{"event":"task_end","outcome":"accepted"}' '123' '"hello"' '[1,2]' '{"event":"escalation"}' > "$Ms/.cc-local-loop/ledger/events.jsonl"
js="$(CLAUDE_PROJECT_DIR="$Ms" bash "$ROOT/.specify/extensions/ccloop/scripts/bash/metrics.sh" "$Ms" --json 2>/dev/null)"
printf '%s' "$js" | jq -e '.tasks_accepted==1 and .escalations==1' >/dev/null 2>&1 && ok "scalar/array lines dropped, rest aggregates" || no "scalar/array lines dropped, rest aggregates"
rm -rf "$Ms"

echo "50. ccloop manifests parse + namespace matches"
CX="$ROOT/.specify/extensions/ccloop"
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import yaml,sys; yaml.safe_load(open('$CX/extension.yml')); yaml.safe_load(open('$CX/bundle.yml'))" 2>/dev/null \
    && ok "ccloop yaml parses" || no "ccloop yaml parses"
else ok "ccloop yaml parses (python3 absent — skipped)"; fi
grep -q 'id: ccloop' "$CX/extension.yml" && ok "extension id ccloop" || no "extension id ccloop"
grep -q 'speckit.ccloop.run' "$CX/extension.yml" && ok "run command declared" || no "run command declared"
grep -q '>=0.12.4' "$CX/extension.yml" && ok "speckit floor 0.12.4" || no "speckit floor 0.12.4"
test -f "$CX/commands/run.md" && ok "run.md exists" || no "run.md exists"

echo "51. ccloop common.sh port + feature resolver"
CL="$CX/scripts/bash/lib/common.sh"
FS="$CX/scripts/bash/feature.sh"
# shellcheck source=/dev/null
if [ -f "$CL" ] && ( . "$CL"; printf '%s' 'tasks.md' | grep -qE "$PROTECTED_PAT" ); then ok "ccloop PROTECTED_PAT matches tasks.md"; else no "ccloop PROTECTED_PAT matches tasks.md"; fi
if [ -f "$CL" ] && ( . "$CL"; [ "$(family_of node-ai/qwen3.6-35b)" = qwen ]; ); then ok "ccloop family_of"; else no "ccloop family_of"; fi
if [ -f "$CL" ] && ( . "$CL"; ( assert_cross_family gemma-4-26b-a4b qwen3.6-35b ) 2>/dev/null ); then ok "ccloop cross-family ok"; else no "ccloop cross-family ok"; fi
FT="$(mktemp -d)"; mkdir -p "$FT/specs/001-demo" && echo "- [ ] T001 x" > "$FT/specs/001-demo/tasks.md"
if [ -f "$FS" ]; then r="$(CLAUDE_PROJECT_DIR="$FT" bash "$FS" dir 2>/dev/null)"; [ "$r" = "specs/001-demo" ] && ok "feature resolver" || no "feature resolver (got '$r')"; else no "feature resolver (missing)"; fi
rm -rf "$FT"

echo "52. progress-status.sh json + assert-closed"
PS="$CX/scripts/bash/progress-status.sh"
D="$(mktemp -d)"; mkdir -p "$D/specs/001-x/ccloop"
printf '| Task | Status | Title |\n|--|--|--|\n| T001 | judge-pass | a |\n| T002 | pending | b |\n' > "$D/specs/001-x/ccloop/progress.md"
o="$(CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$PS" --json 2>/dev/null)"
[ "$(printf '%s' "$o" | jq -r .open)" = 1 ] && ok "status open=1" || no "status open=1 (got $o)"
[ "$(printf '%s' "$o" | jq -r .total)" = 2 ] && ok "status total=2" || no "status total=2"
( CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$PS" --assert-closed ) 2>/dev/null && no "assert-closed dies on open" || ok "assert-closed dies on open"
printf '| Task | Status | Title |\n|--|--|--|\n| T001 | judge-pass | a |\n| T002 | human-signed | b |\n' > "$D/specs/001-x/ccloop/progress.md"
( CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$PS" --assert-closed ) 2>/dev/null && ok "assert-closed passes when closed" || no "assert-closed passes when closed"
rm -rf "$D"

echo "53. progress-lint.sh monotonic ladder"
PL="$CX/scripts/bash/progress-lint.sh"
D="$(mktemp -d)"; mkdir -p "$D/specs/001-x/ccloop"
printf '| Task | Status | Title |\n|--|--|--|\n| T001 | implemented | a |\n' > "$D/specs/001-x/ccloop/progress.md"
plrun(){ CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$PL" "$@"; }
( plrun record T001 judge-pass ) 2>/dev/null && ok "forward transition ok" || no "forward transition ok"
grep -q '| T001 | judge-pass |' "$D/specs/001-x/ccloop/progress.md" && ok "row rewritten" || no "row rewritten"
( plrun record T001 pending ) 2>/dev/null && no "regression refused" || ok "regression refused"
( plrun record T001 bogus ) 2>/dev/null && no "unknown status refused" || ok "unknown status refused"
( plrun record T404 implemented ) 2>/dev/null && no "unknown task refused" || ok "unknown task refused"
printf '| Task | Status | Title |\n|--|--|--|\n| T002 | judge-fail | b |\n' > "$D/specs/001-x/ccloop/progress.md"
( plrun record T002 dispatched ) 2>/dev/null && ok "retry exception allowed" || no "retry exception allowed"
rm -rf "$D"

echo "54. contract-derive.sh derive + idempotent"
CD="$CX/scripts/bash/contract-derive.sh"
D="$(mktemp -d)"; mkdir -p "$D/specs/001-x"
printf '# Tasks\n- [ ] T001 Set up skeleton\n- [ ] T002 [P] Add parser (src/p.ts)\n' > "$D/specs/001-x/tasks.md"
cdrun(){ CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$CD"; }
cdrun 2>/dev/null
grep -q '| T001 | pending |' "$D/specs/001-x/ccloop/progress.md" && ok "seeded T001" || no "seeded T001"
grep -q '| T002 |' "$D/specs/001-x/ccloop/contract.md" && ok "contract has T002" || no "contract has T002"
CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$PL" record T001 judge-pass 2>/dev/null
cdrun 2>/dev/null
grep -q '| T001 | judge-pass |' "$D/specs/001-x/ccloop/progress.md" && ok "idempotent: keeps judge-pass" || no "idempotent: keeps judge-pass"
[ "$(grep -c '| T001 ' "$D/specs/001-x/ccloop/progress.md")" = 1 ] && ok "no duplicate rows" || no "no duplicate rows"
rm -rf "$D"

echo "55. adapters.sh kind normalizer"
AD="$CX/scripts/bash/adapters.sh"
akind(){ ( . "$AD"; get_agent_cli_kind "$1" ); }
[ "$(akind opencode)" = opencode ] && ok "opencode" || no "opencode"
[ "$(akind /usr/local/bin/claude)" = claude ] && ok "path->claude" || no "path->claude"
[ "$(akind CODEX.exe)" = codex ] && ok "case+ext->codex" || no "case+ext->codex"
[ "$(akind cursor)" = unsupported ] && ok "unknown->unsupported" || no "unknown->unsupported"
( . "$AD"; invoke_agent_iteration opencode qwen3.6-35b "do x" /tmp ) 2>/dev/null && no "invoke die-guarded" || ok "invoke die-guarded"

echo "56. done-gate.sh blocks on open debt / open tasks"
DG="$CX/scripts/bash/done-gate.sh"
D="$(mktemp -d)"; mkdir -p "$D/specs/001-x/ccloop"
printf '| Task | Status | Title |\n|--|--|--|\n| T001 | judge-pass | a |\n' > "$D/specs/001-x/ccloop/progress.md"
printf '# Debt\n| ID | Severity | Note |\n|--|--|--|\n| D1 | blocking | unresolved |\n' > "$D/specs/001-x/ccloop/debt.md"
dgrun(){ CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$DG" "$@"; }
( dgrun signoff ) 2>/dev/null && no "blocks on open blocking debt" || ok "blocks on open blocking debt"
printf '# Debt\n| ID | Severity | Note |\n|--|--|--|\n' > "$D/specs/001-x/ccloop/debt.md"
( dgrun signoff ) 2>/dev/null && ok "signoff passes when clear" || no "signoff passes when clear"
grep -q '| T001 | human-signed |' "$D/specs/001-x/ccloop/progress.md" && ok "flips to human-signed" || no "flips to human-signed"
grep -qi 'Signed off' "$D/specs/001-x/ccloop/debt.md" && ok "sign-off row recorded" || no "sign-off row recorded"
rm -rf "$D"

echo "59. state.sh arm emits feature json + arms data plane"
ST="$CX/scripts/bash/state.sh"
D="$(mktemp -d)"; mkdir -p "$D/specs/001-x"; echo "- [ ] T001 x" > "$D/specs/001-x/tasks.md"
o="$(CLAUDE_PROJECT_DIR="$D" bash "$ST" arm --feature specs/001-x --json 2>/dev/null)"
[ "$(printf '%s' "$o" | jq -r .feature 2>/dev/null)" = "specs/001-x" ] && ok "arm emits feature" || no "arm emits feature (got $o)"
test -f "$D/specs/001-x/ccloop/ACTIVE" && ok "arm writes ACTIVE" || no "arm writes ACTIVE"
test -f "$D/specs/001-x/ccloop/RUN_ID" && ok "arm writes RUN_ID" || no "arm writes RUN_ID"
rm -rf "$D"

echo "60. build-context.sh (ccloop) denies the ccloop data plane (G1)"
BC="$CX/scripts/bash/build-context.sh"
grep -q 'ccloop/\*' "$BC" && ok "build-context denies ccloop/**" || no "build-context denies ccloop/**"

echo "61. G9 — ccloop gate.sh rejects tasks.md mutation"
GT="$CX/scripts/bash/harness/gate.sh"
Tg="$(mktemp -d)"
( cd "$Tg" && git init -q && git config user.email a@b.c && git config user.name t \
  && mkdir -p specs/001-x && echo "- [ ] T001 x" > specs/001-x/tasks.md && echo y > app.py \
  && git add -A && git commit -qm base ) >/dev/null 2>&1
echo "- [x] T001 x" > "$Tg/specs/001-x/tasks.md"
outg="$(cd "$Tg" && CLAUDE_PROJECT_DIR="$Tg" bash "$GT" HEAD 2>/dev/null || true)"
printf '%s' "$outg" | grep -q 'scope:protected-path-touched' && ok "gate flags tasks.md tamper" || no "gate flags tasks.md tamper"
rm -rf "$Tg"

echo "62. ccloop workflow.yml structure"
WF="$CX/workflow/workflow.yml"
test -f "$WF" && ok "workflow.yml exists" || no "workflow.yml exists"
grep -q 'id: ccloop' "$WF" && ok "workflow id ccloop" || no "workflow id ccloop"
grep -q 'type: do-while' "$WF" && ok "uses do-while (not while)" || no "uses do-while (not while)"
grep -q 'steps.loop_status.output.data.open' "$WF" && ok "correct output.data path" || no "correct output.data path"
grep -q 'assert_closed' "$WF" && ok "has assert_closed" || no "has assert_closed"
grep -q 'type: gate' "$WF" && ok "has human gate" || no "has human gate"
if command -v python3 >/dev/null 2>&1; then python3 -c "import yaml;yaml.safe_load(open('$WF'))" 2>/dev/null && ok "workflow yaml parses" || no "workflow yaml parses"; else ok "workflow yaml parse skipped"; fi

echo "63. ccloop commands + doctor"
CCd="$CX/commands"
for c in run status reflect promote doctor; do test -f "$CCd/$c.md" && ok "cmd $c.md" || no "cmd $c.md"; done
grep -q 'workflow add' "$CCd/run.md" && ok "run.md self-registers workflow" || no "run.md self-registers workflow"
grep -q 'workflow run ccloop' "$CCd/run.md" && ok "run.md launches workflow" || no "run.md launches workflow"
DR="$CX/scripts/bash/doctor.sh"
odr="$(bash "$DR" 2>/dev/null || true)"
printf '%s' "$odr" | grep -qi 'ENFORCED' && ok "doctor prints matrix" || no "doctor prints matrix"
printf '%s' "$odr" | grep -qi 'ccloop' && ok "doctor is ccloop-specific" || no "doctor is ccloop-specific"
printf '%s' "$odr" | grep -q 'node-ai dispatch' && ok "doctor honest about node-ai TODO" || no "doctor honest about node-ai TODO"

echo "64. promote-check.sh (ccloop) blocks yardstick + reflect.sh fail-safe"
PC="$CX/scripts/bash/promote-check.sh"
Qd="$(mktemp -d)"
( cd "$Qd" && git init -q && git config user.email a@b.c && git config user.name t \
  && mkdir -p evals/calibration && echo a > evals/calibration/x && git add -A && git commit -qm base ) >/dev/null 2>&1
echo bad >> "$Qd/evals/calibration/x"
( cd "$Qd" && bash "$PC" HEAD ) >/dev/null 2>&1 && no "promote-check blocks yardstick" || ok "promote-check blocks yardstick"
rm -rf "$Qd"
RF="$CX/scripts/bash/reflect.sh"
( bash "$RF" run ) >/dev/null 2>&1 && ok "reflect exits 0 (fail-safe)" || no "reflect exits 0 (fail-safe)"

echo "65. B3 — gate.sh does NOT scope-trip on the armed ccloop data plane"
Tb="$(mktemp -d)"
( cd "$Tb" && git init -q && git config user.email a@b.c && git config user.name t \
  && mkdir -p specs/001-x && printf -- '- [ ] T001 x\n' > specs/001-x/tasks.md && echo y > app.py \
  && git add -A && git commit -qm base ) >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Tb" bash "$CX/scripts/bash/state.sh" arm --feature specs/001-x --json >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Tb" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/contract-derive.sh" >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Tb" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/harness/freeze.sh" >/dev/null 2>&1
outb="$(cd "$Tb" && CLAUDE_PROJECT_DIR="$Tb" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/harness/gate.sh" HEAD 2>/dev/null || true)"
printf '%s' "$outb" | grep -q 'scope:protected-path-touched' && no "gate self-trips on ccloop data plane (B3)" || ok "gate does NOT scope-trip on ccloop data plane (B3)"
grep -q 'ccloop data plane' "$Tb/.git/info/exclude" 2>/dev/null && ok "arm wrote .git/info/exclude (B3)" || no "arm wrote .git/info/exclude"
rm -rf "$Tb"

echo "66. M1 — assert-closed fail-closed on empty; contract-derive dies on 0 parseable tasks"
Tm="$(mktemp -d)"; mkdir -p "$Tm/specs/001-x/ccloop"
printf '| Task | Status | Title |\n|--|--|--|\n' > "$Tm/specs/001-x/ccloop/progress.md"
( CLAUDE_PROJECT_DIR="$Tm" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/progress-status.sh" --assert-closed ) 2>/dev/null && no "assert-closed refuses empty" || ok "assert-closed refuses empty (M1)"
printf '# Tasks\n- [ ] prose bullet with no task id\n- some heading\n' > "$Tm/specs/001-x/tasks.md"
( CLAUDE_PROJECT_DIR="$Tm" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/contract-derive.sh" ) 2>/dev/null && no "contract-derive dies on 0 tasks" || ok "contract-derive dies on 0 tasks (M1)"
# but the superspec bold-ID form MUST be handled (this repo's own tasks.md uses it)
rm -f "$Tm/specs/001-x/ccloop/progress.md"
printf '# Tasks\n- [x] **T001** [SUBAGENT] Scaffold the thing\n- [ ] **T002** [P] [US1] Parser (src/p.ts)\n' > "$Tm/specs/001-x/tasks.md"
( CLAUDE_PROJECT_DIR="$Tm" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/contract-derive.sh" ) >/dev/null 2>&1
grep -q '| T001 |' "$Tm/specs/001-x/ccloop/progress.md" 2>/dev/null && grep -q '| T002 |' "$Tm/specs/001-x/ccloop/progress.md" 2>/dev/null && ok "contract-derive handles superspec bold-ID form" || no "contract-derive handles bold-ID form"
rm -rf "$Tm"

echo "67. M2 — progress-lint record refuses fabricating human-signed"
Tp="$(mktemp -d)"; mkdir -p "$Tp/specs/001-x/ccloop"
printf '| Task | Status | Title |\n|--|--|--|\n| T001 | pending | a |\n' > "$Tp/specs/001-x/ccloop/progress.md"
( CLAUDE_PROJECT_DIR="$Tp" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/progress-lint.sh" record T001 human-signed ) 2>/dev/null && no "record refuses human-signed" || ok "record refuses human-signed (M2)"
grep -q '| T001 | pending |' "$Tp/specs/001-x/ccloop/progress.md" && ok "row unchanged after refusal" || no "row unchanged after refusal"
rm -rf "$Tp"

echo "68. M3 — state.sh arm rejects traversal + nonexistent feature (no out-of-project write)"
Ta="$(mktemp -d)"; ( cd "$Ta" && git init -q ) >/dev/null 2>&1; mkdir -p "$Ta/specs/001-x"; echo "- [ ] T001 x" > "$Ta/specs/001-x/tasks.md"
esc="/tmp/ccll-esc-$$"; rm -rf "$esc"
( CLAUDE_PROJECT_DIR="$Ta" bash "$CX/scripts/bash/state.sh" arm --feature "../../../../../../../../..$esc" ) 2>/dev/null && no "arm rejects traversal" || ok "arm rejects traversal (M3)"
test -e "$esc/ccloop" && no "no out-of-project write" || ok "no out-of-project write (M3)"
( CLAUDE_PROJECT_DIR="$Ta" bash "$CX/scripts/bash/state.sh" arm --feature specs/999-ghost ) 2>/dev/null && no "arm rejects nonexistent" || ok "arm rejects nonexistent (M3)"
rm -rf "$Ta" "$esc"

echo "69. B1 — dispatch next: no-op when closed, node-ai guard when open; record-next known"
Td="$(mktemp -d)"; mkdir -p "$Td/specs/001-x/ccloop"; : > "$Td/specs/001-x/ccloop/ACTIVE"
printf '| Task | Status | Title |\n|--|--|--|\n| T001 | judge-pass | a |\n' > "$Td/specs/001-x/ccloop/progress.md"
( CLAUDE_PROJECT_DIR="$Td" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/dispatch.sh" next --detach --no-op-if-closed ) >/dev/null 2>&1 && ok "dispatch next no-op when closed (B1)" || no "dispatch next no-op when closed"
printf '| Task | Status | Title |\n|--|--|--|\n| T001 | pending | a |\n' > "$Td/specs/001-x/ccloop/progress.md"
dm="$( CLAUDE_PROJECT_DIR="$Td" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/dispatch.sh" next --detach --no-op-if-closed 2>&1 )"
printf '%s' "$dm" | grep -qiE 'node-ai|scaffold|option-b' && ok "dispatch next dies at node-ai guard when open (B1)" || no "dispatch next node-ai guard"
rn="$( CLAUDE_PROJECT_DIR="$Td" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/progress-lint.sh" record-next 2>&1 )"
printf '%s' "$rn" | grep -q 'usage: progress-lint' && no "record-next unknown subcommand" || ok "record-next is a known subcommand (B1)"
rm -rf "$Td"

echo "70. G1 (real) — a tracked+changed specs/*/ccloop file is DENIED from build-context"
Bt2="$(mktemp -d)"
( cd "$Bt2" && git init -q && git config user.email a@b.c && git config user.name t \
  && echo 'def f(): pass' > mod.py && mkdir -p specs/001-x/ccloop && echo '{"x":"CCLOOP_SENTINEL_5150"}' > specs/001-x/ccloop/promoted.jsonl \
  && git add -A && git commit -qm b \
  && echo x >> mod.py && echo '{"x":"CCLOOP_SENTINEL_5150","v":2}' > specs/001-x/ccloop/promoted.jsonl && git add -A && git commit -qm c ) >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Bt2" bash "$CX/scripts/bash/build-context.sh" CT "FAIL mod.py:1" >/dev/null 2>&1
grep -rq 'CCLOOP_SENTINEL_5150' "$Bt2/.cc-local-loop/" 2>/dev/null && no "ccloop data-plane file denied (G1)" || ok "ccloop data-plane file denied from context (G1)"
rm -rf "$Bt2"

echo "71. B1 — workflow arg-contracts: judge next + gate HEAD don't arg-die"
Tw="$(mktemp -d)"
( cd "$Tw" && git init -q && git config user.email a@b.c && git config user.name t && echo y>app.py && mkdir -p specs/001-x && echo '- [ ] T001 x'>specs/001-x/tasks.md && git add -A && git commit -qm b ) >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$Tw" bash "$CX/scripts/bash/state.sh" arm --feature specs/001-x --json >/dev/null 2>&1
jm="$( CLAUDE_PROJECT_DIR="$Tw" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/judge.sh" next --detach 2>&1 )"
printf '%s' "$jm" | grep -qiE 'base ref required|judge_model required' && no "judge next arg-dies" || ok "judge next reaches guard, no arg-die (B1)"
gm="$( cd "$Tw" && CLAUDE_PROJECT_DIR="$Tw" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/harness/gate.sh" HEAD 2>&1 )"
printf '%s' "$gm" | grep -q 'usage: gate.sh' && no "gate HEAD arg-dies" || ok "gate HEAD accepts base ref (B1)"
rm -rf "$Tw"

echo "72. N1 — arm's exclude works inside a linked git worktree (B3 holds for worktrees)"
Twt="$(mktemp -d)"
( cd "$Twt" && git init -q && git config user.email a@b.c && git config user.name t \
  && mkdir -p specs/001-x && echo '- [ ] T001 x' > specs/001-x/tasks.md && echo y > app.py \
  && git add -A && git commit -qm b && git worktree add -q wt >/dev/null 2>&1 ) >/dev/null 2>&1
WT="$Twt/wt"
if [ -d "$WT" ]; then
  CLAUDE_PROJECT_DIR="$WT" bash "$CX/scripts/bash/state.sh" arm --feature specs/001-x --json >/dev/null 2>&1
  CLAUDE_PROJECT_DIR="$WT" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/contract-derive.sh" >/dev/null 2>&1
  CLAUDE_PROJECT_DIR="$WT" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/harness/freeze.sh" >/dev/null 2>&1
  ow="$( cd "$WT" && CLAUDE_PROJECT_DIR="$WT" CCLOOP_FEATURE=specs/001-x bash "$CX/scripts/bash/harness/gate.sh" HEAD 2>/dev/null || true )"
  printf '%s' "$ow" | grep -q 'scope:protected-path-touched' && no "worktree: gate self-trips (N1)" || ok "worktree: gate does NOT scope-trip (N1)"
  ( cd "$Twt" && git worktree remove --force wt >/dev/null 2>&1 )
else ok "worktree: skipped (git worktree unavailable)"; fi
rm -rf "$Twt"

echo "73. N2 — arm rejects a symlinked feature that escapes the project root"
Ts="$(mktemp -d)"; Tout="$(mktemp -d)"
( cd "$Ts" && git init -q ) >/dev/null 2>&1
mkdir -p "$Tout/target"; echo '- [ ] T001 x' > "$Tout/target/tasks.md"; mkdir -p "$Ts/specs"; ln -s "$Tout/target" "$Ts/specs/012-link" 2>/dev/null
( CLAUDE_PROJECT_DIR="$Ts" bash "$CX/scripts/bash/state.sh" arm --feature specs/012-link ) 2>/dev/null && no "arm rejects symlink escape" || ok "arm rejects symlink escape (N2)"
test -e "$Tout/target/ccloop" && no "no write to symlink target" || ok "no write to symlink target (N2)"
rm -rf "$Ts" "$Tout"

echo "74. N3 — arm --json is jq-valid (not printf-built)"
Tj="$(mktemp -d)"; ( cd "$Tj" && git init -q ) >/dev/null 2>&1; mkdir -p "$Tj/specs/001-x"; echo '- [ ] T001 x' > "$Tj/specs/001-x/tasks.md"
oj="$( CLAUDE_PROJECT_DIR="$Tj" bash "$CX/scripts/bash/state.sh" arm --feature specs/001-x --json 2>/dev/null )"
printf '%s' "$oj" | jq -e '.feature=="specs/001-x" and (.run_id|length>0)' >/dev/null 2>&1 && ok "arm --json valid jq (N3)" || no "arm --json valid jq"
rm -rf "$Tj"

echo ""
printf 'RESULT: %d passed, %d failed\n' "$P" "$F"
[ "$F" -eq 0 ]
