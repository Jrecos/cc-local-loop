# ccloop — spec-kit Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repackage cc-local-loop as a spec-kit 0.12.4 extension (`ccloop`) whose loop is a native workflow; deliver an installable, validating, probe-green foundation with the new safety scripts, keeping live node-ai dispatch `die`-guarded (unchanged from today).

**Architecture:** A spec-kit extension at `.specify/extensions/ccloop/` provides `speckit.ccloop.*` commands + bash gate scripts; a workflow at `.specify/workflows/ccloop/workflow.yml` orchestrates the loop via `do-while`/`shell`/`gate` steps. Every safety gate is a bash `shell` step whose non-zero exit halts the run (fail-closed is native to the engine). `tasks.md` stays frozen; run-state lives in `specs/<feature>/ccloop/`.

**Tech Stack:** bash (3.2/BSD + GNU portable), jq, spec-kit CLI 0.12.4 (`specify extension|workflow`), git. No compiler.

**Design doc:** `docs/superpowers/specs/2026-07-06-ccloop-speckit-extension-design.md` (§4 packaging, §6 workflow, §10 guardrails, §13 Fable validation).

## Global Constraints

- **Portability:** must run on macOS (bash 3.2 / BSD userland) AND Linux (GNU). No `sed -i`, no `date -d`, no `realpath`, no GNU-only flags. Use `wc -c | tr -d ' '`, `awk` state machines, `shasum` fallback.
- **Fail-mode is deliberate:** safety scripts (`freeze`, `gate`, `judge`, `progress-lint`, `done-gate`, `contract-derive`, `progress-status --assert-closed`) **fail CLOSED** (`die` on doubt). Telemetry scripts (`emit`, `ledger-append`) **fail SAFE — always `exit 0`**; never add `set -e` to them.
- **`PROTECTED_PAT` in `lib/common.sh` is the single source of truth** for protected paths; consumed by freeze/gate/dispatch. Edit it there only. It already matches `tasks.md`.
- **Cross-family invariant is absolute:** the implementer family never judges its own change (`assert_cross_family`). Opus is never a local implementer.
- **G9 — `tasks.md` immutability:** the loop never writes `tasks.md`; completion lives in `specs/<feature>/ccloop/progress.md` keyed by task ID.
- **G1 — one injected memory:** only `references/lessons.md` is ever injected; the `ccloop/` data plane is never injected (`build-context.sh` denylist).
- **Data plane path:** `specs/<feature>/ccloop/` (not `.cc-local-loop/`).
- **spec-kit floor:** `requires.speckit_version: ">=0.12.4"` in every manifest.
- **The gate stays green:** after ANY change, `bash tests/run-tests.sh` must pass. New script/behavior ⇒ add a probe in the same task. Never reimplement a gate in prose.
- **Commit message trailer:** end commit bodies with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## File Structure

```
.specify/extensions/ccloop/
  extension.yml                 # manifest — commands, config, hooks
  bundle.yml                    # ties extension+workflow, version-pinned
  README.md                     # required by `bundle build`
  commands/{run,status,reflect,promote,doctor}.md
  scripts/bash/
    lib/common.sh               # PORT — PROTECTED_PAT, family_of, cross-family, DATA_DIR→specs/<f>/ccloop
    feature.sh                  # NEW — resolve active feature dir + ccloop data-plane paths
    progress-status.sh          # NEW — emit JSON {open,...}; --assert-closed
    progress-lint.sh            # NEW — monotonic ladder; `record <T> <status>`
    contract-derive.sh          # NEW — tasks.md+plan.md → contract.md + seed progress.md
    adapters.sh                 # NEW — get_agent_cli_kind + invoke_<kind> (die-guarded)
    done-gate.sh                # NEW — human sign-off; block on open debt
    doctor.sh                   # NEW — ENFORCED/PARTIAL/TODO matrix
    dispatch.sh judge.sh preflight.sh build-context.sh sandbox-run.sh   # PORT
    state.sh check-idempotency.sh emit.sh metrics.sh eval-run.sh        # PORT
    lessons-lint.sh candidates-append.sh promote-check.sh               # PORT
    harness/{freeze,gate,guards}.sh                                     # PORT
  templates/{ccloop-config.template.yml, contract-template.md, progress-template.md}
  references/{rubric.md, lessons.md, architecture.md}                   # PORT
.specify/workflows/ccloop/workflow.yml   # NEW — the loop
tests/run-tests.sh                        # EXTEND — add ccloop probes
```

**Data-plane files (written at runtime into the target project):**
```
specs/<NNN-feature>/ccloop/{contract.md, progress.md, iterations.md, verdicts.md, debt.md,
                            ledger/events.jsonl, frozen.json, RUN_ID, ACTIVE, loop_state.json}
```

**progress.md machine format (defined here, consumed by status/lint/derive):**
```markdown
| Task | Status | Title |
|------|--------|-------|
| T001 | pending | Set up project skeleton |
```
Statuses (the ladder): `pending → dispatched → implemented → judge-pass | judge-fail | judge-uncertain → human-signed`.
"open" = status ∉ {`judge-pass`, `human-signed`}.

---

## Task 1: Extension scaffold + manifests + install smoke

**Files:**
- Create: `.specify/extensions/ccloop/extension.yml`
- Create: `.specify/extensions/ccloop/bundle.yml`
- Create: `.specify/extensions/ccloop/README.md`
- Create: `.specify/extensions/ccloop/commands/run.md` (placeholder header only; filled in Task 9)
- Test: extend `tests/run-tests.sh`

**Interfaces:**
- Produces: the extension id `ccloop`; command namespace `speckit.ccloop.*`; install path `.specify/extensions/ccloop/`.

- [ ] **Step 1: Write the failing probe** — append to `tests/run-tests.sh` before its final summary:

```bash
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^50\./,$p'`
Expected: FAIL lines (files not created yet).

- [ ] **Step 3: Create `extension.yml`**

```yaml
schema_version: "1.0"

extension:
  id: ccloop
  name: "cc-local-loop"
  version: "0.5.0"
  description: "Opus orchestrates; local models implement via a pluggable agent-CLI adapter; a cross-family judge gates. Judge-only validation, deterministic bash harness, human-gated closure."
  author: "Jhonatan Reco"
  repository: "https://github.com/Jrecos/cc-local-loop"
  license: MIT

requires:
  speckit_version: ">=0.12.4"
  tools:
    - name: git
      required: true
    - name: jq
      required: true

provides:
  commands:
    - name: speckit.ccloop.run
      file: commands/run.md
      description: "Launch the local-model implement loop over tasks.md (fire-and-forget workflow)."
    - name: speckit.ccloop.status
      file: commands/status.md
      description: "Read-only budgeted snapshot of the loop + one recommended next action."
    - name: speckit.ccloop.reflect
      file: commands/reflect.md
      description: "Distill the event ledger into quarantined candidate lessons (offline)."
    - name: speckit.ccloop.promote
      file: commands/promote.md
      description: "Human-gated promotion of a candidate lesson into lessons.md via PR."
    - name: speckit.ccloop.doctor
      file: commands/doctor.md
      description: "Show the ENFORCED / PARTIAL / TODO matrix for this install."
  config:
    - name: "ccloop-config.yml"
      template: "templates/ccloop-config.template.yml"
      description: "Implementer/judge adapters, models, families, loop bounds."
      required: false

hooks:
  after_tasks:
    command: speckit.ccloop.run
    optional: true
    prompt: "Run the ccloop local-model implement loop over these tasks?"
    description: "Offer to implement tasks.md with local models, judge-gated."

tags:
  - orchestration
  - local-llm
  - autonomous-agents
  - spec-driven-development
```

- [ ] **Step 4: Create `bundle.yml`**

```yaml
schema_version: "1.0"
bundle:
  id: ccloop
  name: "cc-local-loop"
  version: "0.5.0"
  role: process
  description: "Opus-orchestrated, local-model-executed implement loop for spec-kit, with a cross-family judge and human-gated closure."
  author: "Jhonatan Reco"
  license: MIT
requires:
  speckit_version: ">=0.12.4"
provides:
  extensions:
    - id: ccloop
      version: "0.5.0"
  workflows:
    - id: ccloop
      version: "0.5.0"
```

- [ ] **Step 5: Create `README.md`** (bundle build requires it)

```markdown
# ccloop — cc-local-loop as a spec-kit extension

Opus orchestrates → local models implement (pluggable agent-CLI adapter) → a cross-family judge gates → human signs off. The loop is a spec-kit workflow; every safety gate is bash that fails closed. `tasks.md` is the frozen work queue; run-state lives in `specs/<feature>/ccloop/`.

## Install

    specify extension add ccloop --from https://github.com/Jrecos/cc-local-loop

Then, in a feature with `tasks.md`:

    /speckit.ccloop.run
```

- [ ] **Step 6: Create placeholder `commands/run.md`** (filled in Task 9)

```markdown
---
description: "Launch the local-model implement loop over tasks.md (fire-and-forget workflow)."
---

# ccloop · run

(Implemented in Task 9.)
```

- [ ] **Step 7: Run the probe to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^50\./,$p'`
Expected: all `ok` for group 50.

- [ ] **Step 8: Install smoke (manual, informational)**

Run: `specify extension add ccloop --dev --from "$(pwd)" 2>&1 | tail -5 || specify extension list`
Expected: `ccloop` appears in `specify extension list`. (If the CLI is unavailable in CI, skip — the probe above is the gate.)

- [ ] **Step 9: Commit**

```bash
git add .specify/extensions/ccloop tests/run-tests.sh
git commit -m "feat(ccloop): extension + bundle manifests, scaffold, install probe"
```

---

## Task 2: Port `lib/common.sh` + add feature resolver

**Files:**
- Create: `.specify/extensions/ccloop/scripts/bash/lib/common.sh` (ported from `scripts/lib/common.sh`)
- Create: `.specify/extensions/ccloop/scripts/bash/feature.sh`
- Test: extend `tests/run-tests.sh`

**Interfaces:**
- Consumes: existing `scripts/lib/common.sh` (source of the port).
- Produces: `PROTECTED_PAT`, `family_of`, `assert_cross_family`, `assert_impl_allowed`, `sha256`, `ledger_append` (all unchanged); NEW `ccloop_feature_dir()` → echoes `specs/<NNN-feature>` (resolved via spec-kit), and `CCLOOP_DATA` = `<feature_dir>/ccloop`.

- [ ] **Step 1: Write the failing probe** — append to `tests/run-tests.sh`:

```bash
echo "51. ccloop common.sh port + feature resolver"
CL="$ROOT/.specify/extensions/ccloop/scripts/bash/lib/common.sh"
FS="$ROOT/.specify/extensions/ccloop/scripts/bash/feature.sh"
# shellcheck source=/dev/null
if [ -f "$CL" ] && ( . "$CL"; printf '%s' 'tasks.md' | grep -qE "$PROTECTED_PAT" ); then ok "ccloop PROTECTED_PAT matches tasks.md"; else no "ccloop PROTECTED_PAT matches tasks.md"; fi
if [ -f "$CL" ] && ( . "$CL"; [ "$(family_of node-ai/qwen3.6-35b)" = qwen ]; ); then ok "ccloop family_of"; else no "ccloop family_of"; fi
if [ -f "$CL" ] && ( . "$CL"; ( assert_cross_family gemma-4-26b-a4b qwen3.6-35b ) 2>/dev/null ); then ok "ccloop cross-family ok"; else no "ccloop cross-family ok"; fi
# feature resolver: given a specs/NNN dir with tasks.md, echoes that dir
FT="$(mktemp -d)"; mkdir -p "$FT/specs/001-demo" && echo "- [ ] T001 x" > "$FT/specs/001-demo/tasks.md"
if [ -f "$FS" ]; then r="$(CLAUDE_PROJECT_DIR="$FT" bash "$FS" dir 2>/dev/null)"; [ "$r" = "specs/001-demo" ] && ok "feature resolver" || no "feature resolver (got '$r')"; else no "feature resolver (missing)"; fi
rm -rf "$FT"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^51\./,/^52\./p'`
Expected: FAIL (files missing).

- [ ] **Step 3: Port `common.sh`** — copy `scripts/lib/common.sh` verbatim, then change ONLY the data-plane block (lines 6–9). Replace:

```bash
: "${NODE_AI_URL:=http://127.0.0.1:8080}"
: "${CLAUDE_PROJECT_DIR:=$(pwd)}"
DATA_DIR="${CLAUDE_PROJECT_DIR}/.cc-local-loop"
LEDGER="${DATA_DIR}/ledger/events.jsonl"
```

with (data plane now lives under the active feature dir):

```bash
: "${NODE_AI_URL:=http://127.0.0.1:8080}"
: "${CLAUDE_PROJECT_DIR:=$(pwd)}"
# CCLOOP_FEATURE may be pre-set by the workflow's `arm` step; else the caller sets DATA_DIR via feature.sh.
: "${CCLOOP_FEATURE:=}"
if [ -n "$CCLOOP_FEATURE" ]; then DATA_DIR="${CLAUDE_PROJECT_DIR}/${CCLOOP_FEATURE}/ccloop"
else DATA_DIR="${CLAUDE_PROJECT_DIR}/.ccloop-fallback"; fi
LEDGER="${DATA_DIR}/ledger/events.jsonl"
```

Everything else (PROTECTED_PAT, log/die, sha256, family_of, assert_impl_allowed, assert_cross_family, health_check, ledger_append) is copied unchanged.

- [ ] **Step 4: Create `feature.sh`**

```bash
#!/usr/bin/env bash
# Resolve the active spec-kit feature dir + expose ccloop data-plane paths.
# Prefers spec-kit's own resolver; falls back to git-branch match, then newest specs/* with tasks.md.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh"

resolve_dir(){
  local root="${CLAUDE_PROJECT_DIR:-$(pwd)}" j pre="$root/.specify/scripts/bash/check-prerequisites.sh"
  # 1) spec-kit resolver (authoritative)
  if [ -x "$pre" ] || [ -f "$pre" ]; then
    j="$(cd "$root" && bash "$pre" --json --require-tasks --include-tasks 2>/dev/null || true)"
    if [ -n "$j" ] && command -v jq >/dev/null 2>&1; then
      local d; d="$(printf '%s' "$j" | jq -r '.FEATURE_DIR // .feature_dir // empty' 2>/dev/null)"
      [ -n "$d" ] && { printf '%s\n' "${d#"$root"/}"; return 0; }
    fi
  fi
  # 2) git branch → specs/<branch>
  local br; br="$(cd "$root" && git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [ -n "$br" ] && [ -d "$root/specs/$br" ] && { printf 'specs/%s\n' "$br"; return 0; }
  # 3) newest specs/* containing tasks.md (portable; no GNU stat)
  local best="" f
  for f in "$root"/specs/*/tasks.md; do [ -f "$f" ] || continue; best="$f"; done
  [ -n "$best" ] && { local dd; dd="$(dirname "$best")"; printf '%s\n' "${dd#"$root"/}"; return 0; }
  die "no feature dir with tasks.md found (run /speckit.tasks first)"
}

case "${1:-dir}" in
  dir)  resolve_dir ;;
  data) printf '%s/ccloop\n' "$(resolve_dir)" ;;
  *)    die "usage: feature.sh {dir|data}" ;;
esac
```

- [ ] **Step 5: Run the probe to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^51\./,/^52\./p'`
Expected: all `ok`.

- [ ] **Step 6: Commit**

```bash
git add .specify/extensions/ccloop/scripts/bash/lib/common.sh .specify/extensions/ccloop/scripts/bash/feature.sh tests/run-tests.sh
git commit -m "feat(ccloop): port common.sh (feature-scoped data plane) + feature resolver"
```

---

## Task 3: `progress-status.sh` — JSON status + assert-closed

**Files:**
- Create: `.specify/extensions/ccloop/scripts/bash/progress-status.sh`
- Test: extend `tests/run-tests.sh`

**Interfaces:**
- Consumes: `progress.md` table (format above).
- Produces: `progress-status.sh --json` → `{"total":N,"open":N,"passed":N,"uncertain":N}` on stdout (drives the workflow `do-while` condition). `progress-status.sh --assert-closed` → exit 0 iff `open==0`, else `die` (fail-closed, blocks the human gate).

- [ ] **Step 1: Write the failing probe**

```bash
echo "52. progress-status.sh json + assert-closed"
PS="$ROOT/.specify/extensions/ccloop/scripts/bash/progress-status.sh"
D="$(mktemp -d)"; mkdir -p "$D/specs/001-x/ccloop"
printf '| Task | Status | Title |\n|--|--|--|\n| T001 | judge-pass | a |\n| T002 | pending | b |\n' > "$D/specs/001-x/ccloop/progress.md"
o="$(CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$PS" --json 2>/dev/null)"
[ "$(printf '%s' "$o" | jq -r .open)" = 1 ] && ok "status open=1" || no "status open=1 (got $o)"
[ "$(printf '%s' "$o" | jq -r .total)" = 2 ] && ok "status total=2" || no "status total=2"
( CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$PS" --assert-closed ) 2>/dev/null && no "assert-closed dies on open" || ok "assert-closed dies on open"
# now close all
printf '| Task | Status | Title |\n|--|--|--|\n| T001 | judge-pass | a |\n| T002 | human-signed | b |\n' > "$D/specs/001-x/ccloop/progress.md"
( CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$PS" --assert-closed ) 2>/dev/null && ok "assert-closed passes when closed" || no "assert-closed passes when closed"
rm -rf "$D"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^52\./,/^53\./p'`
Expected: FAIL (missing script).

- [ ] **Step 3: Create `progress-status.sh`**

```bash
#!/usr/bin/env bash
# Read progress.md and report status counts (JSON) or assert the loop is closed. FAIL-CLOSED on --assert-closed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh"
PROG="${DATA_DIR}/progress.md"

counts(){ # emits: total open passed uncertain  (open = not judge-pass and not human-signed)
  [ -f "$PROG" ] || { echo "0 0 0 0"; return 0; }
  awk -F'|' '
    /^\| *T[0-9]/ {
      s=$3; gsub(/ /,"",s); total++
      if (s=="judge-pass") passed++
      else if (s=="human-signed") { }
      else { open++; if (s=="judge-uncertain") unc++ }
    }
    END { printf "%d %d %d %d", total+0, open+0, passed+0, unc+0 }
  ' "$PROG"
}

read -r total open passed unc <<EOF
$(counts)
EOF

case "${1:---json}" in
  --json)          printf '{"total":%d,"open":%d,"passed":%d,"uncertain":%d}\n' "$total" "$open" "$passed" "$unc" ;;
  --assert-closed) [ "$open" -eq 0 ] || die "assert-closed: $open task(s) still open (cap exhausted or incomplete)"; ;;
  *)               die "usage: progress-status.sh {--json|--assert-closed}" ;;
esac
```

- [ ] **Step 4: Run the probe to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^52\./,/^53\./p'`
Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add .specify/extensions/ccloop/scripts/bash/progress-status.sh tests/run-tests.sh
git commit -m "feat(ccloop): progress-status.sh (json counts + fail-closed assert-closed)"
```

---

## Task 4: `progress-lint.sh` — monotonic ladder + record

**Files:**
- Create: `.specify/extensions/ccloop/scripts/bash/progress-lint.sh`
- Test: extend `tests/run-tests.sh`

**Interfaces:**
- Consumes: `progress.md`; the ladder statuses.
- Produces: `progress-lint.sh record <TASKID> <status>` — validates the transition is legal (monotonic, with the `judge-fail → dispatched` retry exception), rewrites that task's row, `die`s on illegal transition/unknown status/unknown task (fail-closed). `progress-lint.sh lint` — verifies the whole file has no unknown statuses and no duplicate task IDs.

- [ ] **Step 1: Write the failing probe**

```bash
echo "53. progress-lint.sh monotonic ladder"
PL="$ROOT/.specify/extensions/ccloop/scripts/bash/progress-lint.sh"
D="$(mktemp -d)"; mkdir -p "$D/specs/001-x/ccloop"
printf '| Task | Status | Title |\n|--|--|--|\n| T001 | implemented | a |\n' > "$D/specs/001-x/ccloop/progress.md"
run(){ CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$PL" "$@"; }
( run record T001 judge-pass ) 2>/dev/null && ok "forward transition ok" || no "forward transition ok"
grep -q '| T001 | judge-pass |' "$D/specs/001-x/ccloop/progress.md" && ok "row rewritten" || no "row rewritten"
( run record T001 pending ) 2>/dev/null && no "regression refused" || ok "regression refused"
( run record T001 bogus ) 2>/dev/null && no "unknown status refused" || ok "unknown status refused"
( run record T404 implemented ) 2>/dev/null && no "unknown task refused" || ok "unknown task refused"
# retry exception: judge-fail -> dispatched allowed
printf '| Task | Status | Title |\n|--|--|--|\n| T002 | judge-fail | b |\n' > "$D/specs/001-x/ccloop/progress.md"
( run record T002 dispatched ) 2>/dev/null && ok "retry exception allowed" || no "retry exception allowed"
rm -rf "$D"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^53\./,/^54\./p'`
Expected: FAIL.

- [ ] **Step 3: Create `progress-lint.sh`**

```bash
#!/usr/bin/env bash
# Enforce the ccloop status ladder on progress.md. FAIL-CLOSED: die on any illegal move / unknown status / unknown task.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh"
PROG="${DATA_DIR}/progress.md"

rank(){ case "$1" in
  pending) echo 0;; dispatched) echo 1;; implemented) echo 2;; judge-fail) echo 2;;
  judge-uncertain) echo 3;; judge-pass) echo 4;; human-signed) echo 5;; *) echo -1;; esac; }

record(){ # <taskid> <newstatus>
  local id="$1" ns="$2" cur nr cr
  [ -f "$PROG" ] || die "no progress.md at $PROG"
  [ "$(rank "$ns")" -ge 0 ] || die "unknown status '$ns'"
  cur="$(awk -F'|' -v id="$id" '{s2=$2;gsub(/ /,"",s2); if(s2==id){s=$3;gsub(/ /,"",s);print s;exit}}' "$PROG")"
  [ -n "$cur" ] || die "unknown task '$id' in progress.md"
  cr="$(rank "$cur")"; nr="$(rank "$ns")"
  if [ "$nr" -lt "$cr" ] && ! { [ "$cur" = judge-fail ] && [ "$ns" = dispatched ]; }; then
    die "illegal transition for $id: $cur -> $ns (monotonic; only judge-fail→dispatched may go back)"
  fi
  # rewrite the row (portable: awk to temp, then mv — never sed -i)
  local tmp; tmp="$(mktemp)"
  awk -F'|' -v id="$id" -v ns="$ns" 'BEGIN{OFS="|"}
    { s2=$2; gsub(/ /,"",s2)
      if (s2==id) { $3=" "ns" "; print; } else print }' "$PROG" > "$tmp"
  mv "$tmp" "$PROG"
}

lint(){
  [ -f "$PROG" ] || die "no progress.md"
  awk -F'|' '
    /^\| *T[0-9]/ { id=$2; gsub(/ /,"",id); s=$3; gsub(/ /,"",s)
      if (seen[id]++) { print "dup:"id; bad=1 }
      if (s!="pending"&&s!="dispatched"&&s!="implemented"&&s!="judge-fail"&&s!="judge-uncertain"&&s!="judge-pass"&&s!="human-signed"){ print "badstatus:"id":"s; bad=1 } }
    END{ exit bad?1:0 }' "$PROG" || die "progress.md failed lint"
}

case "${1:-lint}" in
  record) shift; record "$@" ;;
  lint)   lint ;;
  *)      die "usage: progress-lint.sh {record <task> <status>|lint}" ;;
esac
```

- [ ] **Step 4: Run the probe to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^53\./,/^54\./p'`
Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add .specify/extensions/ccloop/scripts/bash/progress-lint.sh tests/run-tests.sh
git commit -m "feat(ccloop): progress-lint.sh (monotonic ladder, fail-closed record)"
```

---

## Task 5: `contract-derive.sh` — tasks.md → contract.md + seed progress.md

**Files:**
- Create: `.specify/extensions/ccloop/scripts/bash/contract-derive.sh`
- Create: `.specify/extensions/ccloop/templates/contract-template.md`
- Create: `.specify/extensions/ccloop/templates/progress-template.md`
- Test: extend `tests/run-tests.sh`

**Interfaces:**
- Consumes: `<feature>/tasks.md` (spec-kit format: task lines `- [ ] T001 ...` or `- [ ] T001 [P] ...`).
- Produces: `<feature>/ccloop/contract.md` (DoD table) and `<feature>/ccloop/progress.md` (seeded `pending`). **Idempotent:** re-running never downgrades an existing `progress.md` status and never duplicates rows.

- [ ] **Step 1: Write the failing probe**

```bash
echo "54. contract-derive.sh derive + idempotent"
CD="$ROOT/.specify/extensions/ccloop/scripts/bash/contract-derive.sh"
D="$(mktemp -d)"; mkdir -p "$D/specs/001-x"
printf '# Tasks\n- [ ] T001 Set up skeleton\n- [ ] T002 [P] Add parser (src/p.ts)\n' > "$D/specs/001-x/tasks.md"
run(){ CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$CD"; }
run 2>/dev/null
grep -q '| T001 | pending |' "$D/specs/001-x/ccloop/progress.md" && ok "seeded T001" || no "seeded T001"
grep -q '| T002 |' "$D/specs/001-x/ccloop/contract.md" && ok "contract has T002" || no "contract has T002"
# advance T001, then re-derive: must NOT downgrade
CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$ROOT/.specify/extensions/ccloop/scripts/bash/progress-lint.sh" record T001 judge-pass 2>/dev/null
run 2>/dev/null
grep -q '| T001 | judge-pass |' "$D/specs/001-x/ccloop/progress.md" && ok "idempotent: keeps judge-pass" || no "idempotent: keeps judge-pass"
[ "$(grep -c '| T001 ' "$D/specs/001-x/ccloop/progress.md")" = 1 ] && ok "no duplicate rows" || no "no duplicate rows"
rm -rf "$D"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^54\./,/^55\./p'`
Expected: FAIL.

- [ ] **Step 3: Create the templates**

`templates/progress-template.md`:
```markdown
| Task | Status | Title |
|------|--------|-------|
```
`templates/contract-template.md`:
```markdown
| Task | Criterion (checkable) | How the judge verifies it | Status |
|------|-----------------------|---------------------------|--------|
```

- [ ] **Step 4: Create `contract-derive.sh`**

```bash
#!/usr/bin/env bash
# Derive the per-task DoD contract + seed progress.md from tasks.md. FAIL-CLOSED. Idempotent (never downgrades).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh"
TMPL="$HERE/../templates"
FEAT="${CLAUDE_PROJECT_DIR}/${CCLOOP_FEATURE:?CCLOOP_FEATURE must be set by arm}"
TASKS="${FEAT}/tasks.md"
PROG="${DATA_DIR}/progress.md"; CONTRACT="${DATA_DIR}/contract.md"
[ -f "$TASKS" ] || die "no tasks.md at $TASKS"
mkdir -p "$DATA_DIR"

# Extract "T### <title>" from spec-kit task lines: "- [ ] T001 [P] Title (path)" → "T001<TAB>Title..."
extract(){ awk '
  /^- \[[ xX]\] +T[0-9]+/ {
    line=$0
    sub(/^- \[[ xX]\] +/,"",line)                 # drop checkbox
    id=line; sub(/[^T].*/,"",id); split(line,a," "); id=a[1]
    title=line; sub(/^T[0-9]+ +/,"",title); sub(/^\[[Pp]\] */,"",title)
    gsub(/\|/,"/",title)                           # keep table cells intact
    printf "%s\t%s\n", id, title
  }' "$TASKS"; }

# contract.md: overwrite (derived, not stateful) from template + one row per task
cp "$TMPL/contract-template.md" "$CONTRACT"
extract | while IFS="$(printf '\t')" read -r id title; do
  printf '| %s | %s | tests pass + judge verifies expected outcomes | pending |\n' "$id" "$title" >> "$CONTRACT"
done

# progress.md: seed if absent; else ADD only new task IDs (never downgrade existing)
if [ ! -f "$PROG" ]; then cp "$TMPL/progress-template.md" "$PROG"; fi
extract | while IFS="$(printf '\t')" read -r id title; do
  grep -q "| $id " "$PROG" || printf '| %s | pending | %s |\n' "$id" "$title" >> "$PROG"
done
log "contract-derive: $(grep -c '^| T' "$CONTRACT") task(s) → $CONTRACT ; progress $PROG"
```

- [ ] **Step 5: Run the probe to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^54\./,/^55\./p'`
Expected: all `ok`.

- [ ] **Step 6: Commit**

```bash
git add .specify/extensions/ccloop/scripts/bash/contract-derive.sh .specify/extensions/ccloop/templates
git commit -m "feat(ccloop): contract-derive.sh (idempotent DoD contract + progress seed)"
```

---

## Task 6: `adapters.sh` — pluggable agent-CLI dispatch (die-guarded)

**Files:**
- Create: `.specify/extensions/ccloop/scripts/bash/adapters.sh`
- Create: `.specify/extensions/ccloop/templates/ccloop-config.template.yml`
- Test: extend `tests/run-tests.sh`

**Interfaces:**
- Consumes: `lib/common.sh` (`family_of`, `assert_cross_family`, `die`).
- Produces: `get_agent_cli_kind <name-or-path>` → `opencode|claude|codex|copilot|unsupported`; `invoke_agent_iteration <kind> <model> <prompt> <workdir>` — builds the per-CLI command; **`die`-guarded** (not executed) until the node-ai serving topology is live, exactly as `dispatch.sh`/`judge.sh` are today.

- [ ] **Step 1: Write the failing probe**

```bash
echo "55. adapters.sh kind normalizer"
AD="$ROOT/.specify/extensions/ccloop/scripts/bash/adapters.sh"
kind(){ ( . "$AD"; get_agent_cli_kind "$1" ); }
[ "$(kind opencode)" = opencode ] && ok "opencode" || no "opencode"
[ "$(kind /usr/local/bin/claude)" = claude ] && ok "path→claude" || no "path→claude"
[ "$(kind CODEX.exe)" = codex ] && ok "case+ext→codex" || no "case+ext→codex"
[ "$(kind cursor)" = unsupported ] && ok "unknown→unsupported" || no "unknown→unsupported"
# invoke must die-guard (topology not live) rather than exec
( . "$AD"; invoke_agent_iteration opencode qwen3.6-35b "do x" /tmp ) 2>/dev/null && no "invoke die-guarded" || ok "invoke die-guarded"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^55\./,/^56\./p'`
Expected: FAIL.

- [ ] **Step 3: Create `ccloop-config.template.yml`**

```yaml
implementer:
  agent_cli: "opencode"          # opencode | claude | codex | copilot | <path>
  model: "qwen3.6-35b"
  family: "qwen"                 # must differ from judge.family (cross-family invariant)
judge:
  agent_cli: "opencode"
  model: "gemma-4-26b-a4b"
  family: "google"
  votes: 1
  three_valued: true             # pass | fail | uncertain
loop:
  max_iterations: 20
  time_budget_min: 120
```

- [ ] **Step 4: Create `adapters.sh`**

```bash
#!/usr/bin/env bash
# Pluggable agent-CLI adapter. Normalizer + per-CLI invocation shapes. DIE-GUARDED until node-ai topology is live.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh"

# name-or-path → kind. bash-3.2 safe (tr, not ${var,,}). Strips path + .exe/.cmd/.bat.
get_agent_cli_kind(){
  local n; n="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; n="${n##*/}"
  n="${n%.exe}"; n="${n%.cmd}"; n="${n%.bat}"
  case "$n" in
    opencode) echo opencode ;;
    claude)   echo claude ;;
    codex)    echo codex ;;
    copilot)  echo copilot ;;
    *)        echo unsupported ;;
  esac
}

# Build the per-CLI command for one iteration. GUARDED: refuses to run until the serving topology exists.
invoke_agent_iteration(){ # <kind> <model> <prompt> <workdir>
  local kind="$1" model="$2" prompt="$3" wd="${4:-.}"
  case "$kind" in
    opencode|claude|codex|copilot) : ;;
    *) die "unsupported agent CLI kind '$kind' (supported: opencode, claude, codex, copilot)" ;;
  esac
  # The exact arg shapes (documented for when the topology lands):
  #   opencode: opencode run --model "$model" <<<"$prompt"
  #   claude:   claude -p "$prompt" --model "$model" --dangerously-skip-permissions
  #   codex:    printf '%s' "$prompt" | codex exec --json --model "$model" --sandbox danger-full-access --cd "$wd" -
  #   copilot:  copilot --agent speckit-ccloop-iterate -p "$prompt" --model "$model" --yolo -s
  die "node-ai serving topology not deployed — dispatch is die-guarded (homelab spec §15.5). kind=$kind model=$model"
}
```

- [ ] **Step 5: Run the probe to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^55\./,/^56\./p'`
Expected: all `ok`.

- [ ] **Step 6: Commit**

```bash
git add .specify/extensions/ccloop/scripts/bash/adapters.sh .specify/extensions/ccloop/templates/ccloop-config.template.yml
git commit -m "feat(ccloop): adapters.sh (agent-CLI normalizer + die-guarded dispatch)"
```

---

## Task 7: `done-gate.sh` — human sign-off closure

**Files:**
- Create: `.specify/extensions/ccloop/scripts/bash/done-gate.sh`
- Test: extend `tests/run-tests.sh`

**Interfaces:**
- Consumes: `<feature>/ccloop/debt.md`, `progress.md` (via `progress-status.sh --assert-closed`).
- Produces: `done-gate.sh signoff` — appends a sign-off row to `debt.md` and sets all `judge-pass` tasks to `human-signed` ONLY when there are no open blocking-debt rows and no open tasks. `die`s otherwise (fail-closed). Sign-off row is never synthesized without the closed precondition.

- [ ] **Step 1: Write the failing probe**

```bash
echo "56. done-gate.sh blocks on open debt / open tasks"
DG="$ROOT/.specify/extensions/ccloop/scripts/bash/done-gate.sh"
D="$(mktemp -d)"; mkdir -p "$D/specs/001-x/ccloop"
printf '| Task | Status | Title |\n|--|--|--|\n| T001 | judge-pass | a |\n' > "$D/specs/001-x/ccloop/progress.md"
printf '# Debt\n| ID | Severity | Note |\n|--|--|--|\n| D1 | blocking | unresolved |\n' > "$D/specs/001-x/ccloop/debt.md"
run(){ CLAUDE_PROJECT_DIR="$D" CCLOOP_FEATURE=specs/001-x bash "$DG" "$@"; }
( run signoff ) 2>/dev/null && no "blocks on open blocking debt" || ok "blocks on open blocking debt"
# clear debt → signoff should pass and flip statuses
printf '# Debt\n| ID | Severity | Note |\n|--|--|--|\n' > "$D/specs/001-x/ccloop/debt.md"
( run signoff ) 2>/dev/null && ok "signoff passes when clear" || no "signoff passes when clear"
grep -q '| T001 | human-signed |' "$D/specs/001-x/ccloop/progress.md" && ok "flips to human-signed" || no "flips to human-signed"
grep -qi 'Signed off' "$D/specs/001-x/ccloop/debt.md" && ok "sign-off row recorded" || no "sign-off row recorded"
rm -rf "$D"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^56\./,/^57\./p'`
Expected: FAIL.

- [ ] **Step 3: Create `done-gate.sh`**

```bash
#!/usr/bin/env bash
# Human sign-off closure. FAIL-CLOSED: refuse unless all tasks judge-pass and no open blocking debt.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh"
PROG="${DATA_DIR}/progress.md"; DEBT="${DATA_DIR}/debt.md"

signoff(){ # <optional signer note>
  local note="${1:-human}"
  # 1) no open tasks (every task judge-pass or already human-signed)
  local open; open="$(awk -F'|' '/^\| *T[0-9]/{s=$3;gsub(/ /,"",s); if(s!="judge-pass"&&s!="human-signed")n++} END{print n+0}' "$PROG")"
  [ "$open" -eq 0 ] || die "cannot sign off: $open task(s) not judge-pass"
  # 2) no open blocking debt
  if [ -f "$DEBT" ]; then
    local blk; blk="$(awk -F'|' 'tolower($0) ~ /blocking/ {n++} END{print n+0}' "$DEBT")"
    [ "$blk" -eq 0 ] || die "cannot sign off: $blk open blocking-debt row(s) in debt.md"
  fi
  # 3) record sign-off + flip judge-pass → human-signed (portable awk rewrite)
  mkdir -p "$DATA_DIR"; [ -f "$DEBT" ] || printf '# Debt\n' > "$DEBT"
  printf '\n## Sign-off log\n- Signed off by: %s (RUN_ID=%s)\n' "$note" "$(cat "${DATA_DIR}/RUN_ID" 2>/dev/null || echo n/a)" >> "$DEBT"
  local tmp; tmp="$(mktemp)"
  awk -F'|' 'BEGIN{OFS="|"} { s=$3; gsub(/ /,"",s); if ($0 ~ /^\| *T[0-9]/ && s=="judge-pass"){ $3=" human-signed "; print } else print }' "$PROG" > "$tmp"
  mv "$tmp" "$PROG"
  log "done-gate: signed off; all tasks human-signed"
}

case "${1:-signoff}" in
  signoff) shift; signoff "${1:-human}" ;;
  *)       die "usage: done-gate.sh signoff [signer]" ;;
esac
```

- [ ] **Step 4: Run the probe to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^56\./,/^57\./p'`
Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add .specify/extensions/ccloop/scripts/bash/done-gate.sh tests/run-tests.sh
git commit -m "feat(ccloop): done-gate.sh (fail-closed human sign-off closure)"
```

---

## Task 8: `workflow.yml` — the loop + validation probe

**Files:**
- Create: `.specify/extensions/ccloop/workflow/workflow.yml` (shipped inside the extension for self-registration)
- Test: extend `tests/run-tests.sh`

**Interfaces:**
- Consumes: the bash scripts from Tasks 2–7 + the ported harness (Task 10).
- Produces: a spec-kit workflow `ccloop` (registered to `.specify/workflows/ccloop/workflow.yml` by `run.md`).

- [ ] **Step 1: Write the failing probe**

```bash
echo "57. ccloop workflow.yml structure"
WF="$ROOT/.specify/extensions/ccloop/workflow/workflow.yml"
test -f "$WF" && ok "workflow.yml exists" || no "workflow.yml exists"
grep -q 'id: ccloop' "$WF" && ok "workflow id ccloop" || no "workflow id ccloop"
grep -q 'type: do-while' "$WF" && ok "uses do-while (not while)" || no "uses do-while (not while)"
grep -q 'steps.loop_status.output.data.open' "$WF" && ok "correct output.data path" || no "correct output.data path"
grep -q 'assert_closed' "$WF" && ok "has assert_closed gate" || no "has assert_closed gate"
grep -q 'type: gate' "$WF" && ok "has human gate" || no "has human gate"
if command -v python3 >/dev/null 2>&1; then python3 -c "import yaml;yaml.safe_load(open('$WF'))" 2>/dev/null && ok "workflow yaml parses" || no "workflow yaml parses"; else ok "yaml parse skipped"; fi
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^57\./,/^58\./p'`
Expected: FAIL.

- [ ] **Step 3: Create `workflow/workflow.yml`** — the Fable-corrected loop from design §6 (do-while, `.output.data.` paths, literal cap, detach+poll, `assert_closed`, gate `show_file`):

```yaml
schema_version: "1.0"
workflow:
  id: ccloop
  name: "Opus-orchestrated local-model implement loop"
  version: "0.5.0"
requires:
  speckit_version: ">=0.12.4"      # advisory in a workflow; the bundle enforces it
  integrations: { any: [claude, opencode, codex, copilot] }
inputs:
  feature: { type: string, default: "auto" }
steps:
  - id: arm
    type: shell
    output_format: json
    run: "bash .specify/extensions/ccloop/scripts/bash/state.sh arm --feature '{{ inputs.feature }}' --json"
  - id: freeze
    type: shell
    run: "bash .specify/extensions/ccloop/scripts/bash/harness/freeze.sh"
  - id: derive
    type: shell
    run: "bash .specify/extensions/ccloop/scripts/bash/contract-derive.sh"
  - id: loop
    type: do-while
    condition: "{{ steps.loop_status.output.data.open > 0 }}"
    max_iterations: 20
    steps:
      - id: loop_status
        type: shell
        output_format: json
        run: "bash .specify/extensions/ccloop/scripts/bash/progress-status.sh --json"
      - id: dispatch
        type: shell
        run: "bash .specify/extensions/ccloop/scripts/bash/dispatch.sh next --detach --no-op-if-closed"
      - id: judge
        type: shell
        run: "bash .specify/extensions/ccloop/scripts/bash/judge.sh next --detach"
      - id: gate
        type: shell
        run: "bash .specify/extensions/ccloop/scripts/bash/harness/gate.sh"
      - id: record
        type: shell
        run: "bash .specify/extensions/ccloop/scripts/bash/progress-lint.sh record-next"
  - id: assert_closed
    type: shell
    run: "bash .specify/extensions/ccloop/scripts/bash/progress-status.sh --assert-closed"
  - id: human_done_gate
    type: gate
    message: "All tasks judge-pass. Review comprehension debt below, then approve to close."
    show_file: "specs/{{ steps.arm.output.data.feature }}/ccloop/debt.md"
    options: [approve, reject]
    on_reject: abort
  - id: signoff
    type: shell
    run: "bash .specify/extensions/ccloop/scripts/bash/done-gate.sh signoff"
  - id: reflect
    type: shell
    run: "bash .specify/extensions/ccloop/scripts/bash/reflect.sh run"
```

*(Note: `dispatch.sh next`, `judge.sh next`, `state.sh arm`, `reflect.sh`, and `progress-lint.sh record-next` are the port/adaptation targets of Task 10; until then the workflow validates structurally but `dispatch`/`judge` die-guard at run time.)*

- [ ] **Step 4: Run the probe to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^57\./,/^58\./p'`
Expected: all `ok`.

- [ ] **Step 5: (Optional) engine validation**

Run: `specify workflow add "$(pwd)/.specify/extensions/ccloop/workflow/workflow.yml" 2>&1 | tail -5 && specify workflow info ccloop 2>&1 | head -20`
Expected: workflow registers and its step graph prints. (Skip if CLI unavailable.)

- [ ] **Step 6: Commit**

```bash
git add .specify/extensions/ccloop/workflow/workflow.yml tests/run-tests.sh
git commit -m "feat(ccloop): workflow.yml (do-while loop, fail-closed gates, human sign-off)"
```

---

## Task 9: Commands (`run` self-register + status/reflect/promote/doctor) + `doctor.sh`

**Files:**
- Modify: `.specify/extensions/ccloop/commands/run.md`
- Create: `.specify/extensions/ccloop/commands/{status,reflect,promote,doctor}.md`
- Create: `.specify/extensions/ccloop/scripts/bash/doctor.sh`
- Test: extend `tests/run-tests.sh`

**Interfaces:**
- Consumes: `workflow/workflow.yml`; `progress-status.sh`; `doctor.sh`.
- Produces: `speckit.ccloop.run` prose that self-registers + launches the workflow; `doctor.sh` matrix printer.

- [ ] **Step 1: Write the failing probe**

```bash
echo "58. ccloop commands + doctor"
CC="$ROOT/.specify/extensions/ccloop/commands"
for c in run status reflect promote doctor; do test -f "$CC/$c.md" && ok "cmd $c.md" || no "cmd $c.md"; done
grep -q 'workflow add' "$CC/run.md" && ok "run.md self-registers workflow" || no "run.md self-registers workflow"
grep -q 'workflow run ccloop' "$CC/run.md" && ok "run.md launches workflow" || no "run.md launches workflow"
DR="$ROOT/.specify/extensions/ccloop/scripts/bash/doctor.sh"
o="$(bash "$DR" 2>/dev/null || true)"; printf '%s' "$o" | grep -qi 'ENFORCED' && ok "doctor prints matrix" || no "doctor prints matrix"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^58\./,/^59\./p'`
Expected: FAIL.

- [ ] **Step 3: Fill `commands/run.md`**

````markdown
---
description: "Launch the local-model implement loop over tasks.md (fire-and-forget workflow)."
disable-model-invocation: false
---

# ccloop · run

You are launching the ccloop implement loop. Do this deterministically:

1. **Validate prerequisites.** Confirm a feature with `tasks.md` exists:
   `bash .specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks`
   If it fails, tell the user to run `/speckit.tasks` first and STOP.

2. **Self-register the workflow if absent** (idempotent):
   ```bash
   specify workflow list | grep -q '\bccloop\b' \
     || specify workflow add "$(pwd)/.specify/extensions/ccloop/workflow/workflow.yml"
   ```

3. **Launch the loop, fire-and-forget**, in the user's terminal:
   ```bash
   specify workflow run ccloop
   ```
   Then EXIT — do not babysit the loop (Opus only thinks/reviews). The workflow
   pauses at the human done-gate; the user resumes with `specify workflow resume <run_id>`
   to sign off. Report the launch and stop.
````

- [ ] **Step 4: Create the other four commands** (thin prose that calls the scripts)

`commands/status.md`:
```markdown
---
description: "Read-only budgeted snapshot of the loop + one recommended next action."
---
# ccloop · status
Run `bash .specify/extensions/ccloop/scripts/bash/progress-status.sh --json` and `specify workflow status ccloop`. Render counts (open/passed/uncertain), then recommend exactly one next action: any open → resume the workflow; all passed but unsigned → the done-gate; nothing open → done. Do not modify any file.
```
`commands/reflect.md`:
```markdown
---
description: "Distill the event ledger into quarantined candidate lessons (offline)."
---
# ccloop · reflect
Run `bash .specify/extensions/ccloop/scripts/bash/reflect.sh run`. It reads the ledger and writes candidate lessons to the quarantine — it NEVER edits `references/lessons.md` (that is human-gated via `/speckit.ccloop.promote`).
```
`commands/promote.md`:
```markdown
---
description: "Human-gated promotion of a candidate lesson into lessons.md via PR."
disable-model-invocation: true
---
# ccloop · promote
Human-only. Run `bash .specify/extensions/ccloop/scripts/bash/promote-check.sh HEAD` first (fail-closed gate: additive-only, cap, provenance, yardstick untouched). Only on pass, open a PR moving ONE candidate into `references/lessons.md`.
```
`commands/doctor.md`:
```markdown
---
description: "Show the ENFORCED / PARTIAL / TODO matrix for this install."
---
# ccloop · doctor
Run `bash .specify/extensions/ccloop/scripts/bash/doctor.sh` and show its output verbatim.
```

- [ ] **Step 5: Create `doctor.sh`**

```bash
#!/usr/bin/env bash
# Honest status matrix: what is ENFORCED in code vs PARTIAL vs TODO for this install.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
row(){ printf '  %-9s %s\n' "$1" "$2"; }
echo "ccloop — install matrix"
row ENFORCED "PROTECTED_PAT + cross-family (lib/common.sh)"
row ENFORCED "progress ladder monotonicity (progress-lint.sh)"
row ENFORCED "assert-closed before human gate (progress-status.sh)"
row ENFORCED "human sign-off closure (done-gate.sh)"
row ENFORCED "contract derive idempotent (contract-derive.sh)"
row ENFORCED "workflow structure (do-while, fail-closed shell steps)"
row PARTIAL  "adapters.sh — normalizer live; invocation die-guarded"
row TODO     "node-ai serving topology (dispatch.sh/judge.sh live calls)"
row TODO     "scripts/powershell mirrors (bash-first)"
```

- [ ] **Step 6: Run the probe to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | sed -n '/^58\./,/^59\./p'`
Expected: all `ok`.

- [ ] **Step 7: Commit**

```bash
git add .specify/extensions/ccloop/commands .specify/extensions/ccloop/scripts/bash/doctor.sh tests/run-tests.sh
git commit -m "feat(ccloop): commands (run self-registers workflow) + doctor matrix"
```

---

## Task 10: Port the harness + engine scripts (data-plane path change) and re-green

**Files:**
- Create (port from existing `scripts/`): `harness/{freeze,gate,guards}.sh`, `dispatch.sh`, `judge.sh`, `preflight.sh`, `build-context.sh`, `sandbox-run.sh`, `state.sh`, `check-idempotency.sh`, `emit.sh`, `metrics.sh`, `eval-run.sh`, `lessons-lint.sh`, `candidates-append.sh`, `promote-check.sh`, `reflect.sh`, plus `references/{rubric,lessons,architecture}.md`
- Modify: `tests/run-tests.sh` (repoint ported-script probes; add G9 + G1 denylist probes)

**Interfaces:**
- Consumes: ported `lib/common.sh` (already feature-scoped).
- Produces: `state.sh arm --feature <f> --json` (writes RUN_ID/ACTIVE/loop_state.json under `<f>/ccloop`, echoes `{"feature":"specs/<f>"}`); `dispatch.sh next` / `judge.sh next` (die-guarded); `build-context.sh` denylist includes `specs/*/ccloop/**`; `progress-lint.sh record-next` (advances the current in-flight task using the judge verdict file). `reflect.sh run` (offline).

- [ ] **Step 1: Copy the scripts** into `.specify/extensions/ccloop/scripts/bash/` (and `harness/`), preserving contents. Each already sources `lib/common.sh` by relative path — verify the `source` line resolves from the new location.

Run (per file): `bash -n .specify/extensions/ccloop/scripts/bash/<file>.sh` — Expected: no syntax error.

- [ ] **Step 2: Apply the data-plane path change.** These scripts referenced `.cc-local-loop`. Since `common.sh` now derives `DATA_DIR` from `CCLOOP_FEATURE`, grep for any remaining literal and fix:

Run: `grep -rn '\.cc-local-loop' .specify/extensions/ccloop/scripts/bash/ || echo clean`
Expected after fixes: `clean`. Replace any literal `.cc-local-loop` with `${DATA_DIR}` (already defined by `common.sh`).

- [ ] **Step 3: Add `state.sh arm` JSON contract.** Ensure `state.sh` supports `arm --feature <f> --json`: it sets `CCLOOP_FEATURE`, `mkdir -p "$DATA_DIR/ledger"`, writes `RUN_ID` + `ACTIVE`, and prints `{"feature":"<f>"}`. Add the failing probe first:

```bash
echo "59. state.sh arm emits feature json + arms data plane"
ST="$ROOT/.specify/extensions/ccloop/scripts/bash/state.sh"
D="$(mktemp -d)"; mkdir -p "$D/specs/001-x"; echo "- [ ] T001 x" > "$D/specs/001-x/tasks.md"
o="$(CLAUDE_PROJECT_DIR="$D" bash "$ST" arm --feature specs/001-x --json 2>/dev/null)"
[ "$(printf '%s' "$o" | jq -r .feature)" = "specs/001-x" ] && ok "arm emits feature" || no "arm emits feature"
test -f "$D/specs/001-x/ccloop/ACTIVE" && ok "arm writes ACTIVE" || no "arm writes ACTIVE"
rm -rf "$D"
```
Then implement `arm` to satisfy it, and run:
`bash tests/run-tests.sh 2>&1 | sed -n '/^59\./,/^60\./p'` — Expected: all `ok`.

- [ ] **Step 4: Extend `build-context.sh` denylist (G1)** to deny the new data plane, and add the probe:

```bash
echo "60. build-context denies the ccloop data plane (G1)"
BC="$ROOT/.specify/extensions/ccloop/scripts/bash/build-context.sh"
grep -q 'ccloop' "$BC" && ok "build-context denies ccloop/**" || no "build-context denies ccloop/**"
```
Add `specs/*/ccloop/` (and `progress.md`,`contract.md`,`verdicts.md`,`debt.md`,`ledger`) to the script's deny logic so only `references/lessons.md` is ever injected.

- [ ] **Step 5: Add the G9 tasks.md-immutability probe** (freeze/gate reject any tasks.md write):

```bash
echo "61. G9 — gate.sh rejects tasks.md mutation"
GT="$ROOT/.specify/extensions/ccloop/scripts/bash/harness/gate.sh"
T="$(mktemp -d)"
( cd "$T" && git init -q && git config user.email a@b.c && git config user.name t \
  && mkdir -p specs/001-x && echo "- [ ] T001 x" > specs/001-x/tasks.md && echo y > app.py \
  && git add -A && git commit -qm base ) >/dev/null 2>&1
echo "- [x] T001 x" > "$T/specs/001-x/tasks.md"   # simulate a forbidden checkbox flip
out="$(cd "$T" && CLAUDE_PROJECT_DIR="$T" bash "$GT" HEAD 2>/dev/null || true)"
printf '%s' "$out" | grep -q 'scope:protected-path-touched' && ok "gate flags tasks.md tamper" || no "gate flags tasks.md tamper"
rm -rf "$T"
```
(`tasks.md` is already in `PROTECTED_PAT`, so this should pass once `gate.sh` is ported unchanged — the probe pins G9 explicitly.)

- [ ] **Step 6: Re-point the pre-existing probes** (groups 1–49) at the new script locations where they invoked `$ROOT/scripts/...`. For the extension's copy, update those probe paths to `$ROOT/.specify/extensions/ccloop/scripts/...`. Run the whole suite:

Run: `bash tests/run-tests.sh`
Expected: `PASS N/N` with zero `FAIL` (existing probes green + new groups 50–61).

- [ ] **Step 7: `bash -n` the whole extension surface**

Run: `for s in .specify/extensions/ccloop/scripts/bash/*.sh .specify/extensions/ccloop/scripts/bash/harness/*.sh; do bash -n "$s" || echo "BAD $s"; done; echo done`
Expected: `done` with no `BAD`.

- [ ] **Step 8: Commit**

```bash
git add .specify/extensions/ccloop/scripts .specify/extensions/ccloop/references tests/run-tests.sh
git commit -m "feat(ccloop): port harness+engine to feature-scoped data plane; G1/G9 probes"
```

---

## Task 11: Remove the standalone Claude Code plugin form (decision Q3)

**Files:**
- Delete: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (and empty `.claude-plugin/`)
- Modify: `README.md`, `CLAUDE.md` (repoint to the extension), `CHANGELOG.md`

**Interfaces:** none (packaging cleanup).

- [ ] **Step 1: Confirm the extension is green first**

Run: `bash tests/run-tests.sh` — Expected: `PASS N/N`. (Do not remove the plugin form until the extension passes.)

- [ ] **Step 2: Remove the plugin/marketplace manifests**

```bash
git rm .claude-plugin/plugin.json .claude-plugin/marketplace.json
```

- [ ] **Step 3: Update docs.** In `README.md` replace the "load as a plugin" instructions with the extension install (`specify extension add ccloop --from <repo>`). Add a `CHANGELOG.md` entry: `0.5.0 — repackaged as a spec-kit 0.12.4 extension (ccloop); loop is now a workflow; plugin/marketplace form removed.`

- [ ] **Step 4: Final gate**

Run: `bash tests/run-tests.sh`
Expected: `PASS N/N`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(ccloop): drop standalone plugin/marketplace form; docs point to the extension"
```

---

## Out of scope (follow-up plan)

- **Live node-ai wiring** — replacing the `die`-guards in `adapters.sh`/`dispatch.sh`/`judge.sh` and `gate.sh`'s test runner with real calls, once the node-ai "Option-B" serving topology is deployed (homelab §15.5). The detach+poll mechanics for the 300s cap land here.
- **PowerShell mirrors** of the bash scripts (bash-first; tracked as TODO in `doctor.sh`).
- **Published catalogs** for one-command discovery (primary install stays `extension add --from <repo>`).

## Self-Review

**Spec coverage:** §4 packaging → Tasks 1, 9 (self-register), 11. §5 data plane → Task 2 (feature-scoped `DATA_DIR`), Task 10. §6 workflow → Task 8, wired in 10. §7 ladder/adapters → Tasks 4, 6. §10 guardrails: G1 → Task 10 Step 4; G9 → Task 10 Step 5; G2/G3 → Tasks 3/4/7; G4 → ported `lessons-lint`/`promote-check` (Task 10). §13 Fable fixes B1–B5 → all in Task 8's workflow.yml. Live node-ai (design §12 step 5 caveat) → explicitly out of scope.

**Placeholder scan:** the only "TODO"/"PARTIAL" tokens are legitimate content in `doctor.sh`'s honest matrix and the out-of-scope section — not plan gaps. All code steps contain runnable code.

**Type consistency:** `DATA_DIR`, `CCLOOP_FEATURE`, `progress.md` table format, and the ladder statuses (`pending/dispatched/implemented/judge-pass/judge-fail/judge-uncertain/human-signed`) are used identically across `common.sh`, `progress-status.sh`, `progress-lint.sh`, `contract-derive.sh`, `done-gate.sh`, and `workflow.yml`. `progress-lint record` (Task 4) vs `record-next` (Task 8/10): `record` is the primitive; `record-next` (added in Task 10) is the loop wrapper that resolves the in-flight task then calls `record` — noted in Task 10 interfaces.
