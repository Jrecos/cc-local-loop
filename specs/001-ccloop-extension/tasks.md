---
description: "Task list for ccloop — cc-local-loop as a spec-kit extension"
---

# Tasks: ccloop — cc-local-loop as a spec-kit extension

**Input**: Design documents from `specs/001-ccloop-extension/` (spec.md, plan.md) + full blueprint `docs/superpowers/plans/2026-07-06-ccloop-speckit-extension.md`.

**Tests**: Included and REQUIRED — this project's regression net (`tests/run-tests.sh`) is the review contract (constitution). Every new script/behavior adds a probe in the same task.

**Organization**: by user story (US1 MVP → US2 guardrails → US3 observability), after shared Setup + Foundational phases.

## Format: `[ID] [P?] [Marker] [Story] Description`

- **[P]**: can run in parallel (different files, no dependencies)
- **[TDD]**: RED→GREEN→REFACTOR (write the failing probe first)
- **[REVIEW]**: pause for human review before proceeding
- **[SUBAGENT]**: safe to delegate to a fresh subagent
- **[Story]**: US1 / US2 / US3
- **Blueprint**: "Plan Task N" ⇒ full code + exact steps in `docs/superpowers/plans/2026-07-06-ccloop-speckit-extension.md`.

## Global Constraints (apply to every task)

- Portable bash (macOS 3.2/BSD + Linux/GNU): no `sed -i`, `date -d`, `realpath`, GNU-only flags.
- Fail-closed safety scripts `die` on doubt; telemetry scripts always `exit 0` (never `set -e`).
- `PROTECTED_PAT` single source of truth (`lib/common.sh`); `tasks.md` is protected (G9).
- Cross-family absolute; Opus never a local implementer. Only `references/lessons.md` injectable (G1).
- Data plane: `specs/<feature>/ccloop/`. spec-kit floor `>=0.12.4`.
- After every task: `bash tests/run-tests.sh` MUST pass. Commit trailer: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Extension skeleton + shared library so every later task has a home and the common helpers.

- [x] **T001** [SUBAGENT] Create the extension scaffold + manifests + install probe — `blueprint: Plan Task 1`
  - Create: `.specify/extensions/ccloop/{extension.yml, bundle.yml, README.md}`, `.specify/extensions/ccloop/commands/run.md` (placeholder header)
  - Test: add probe group 50 to `tests/run-tests.sh` (manifests parse, id `ccloop`, `speckit.ccloop.run` declared, floor `>=0.12.4`)
  - Done: `bash tests/run-tests.sh` group 50 all `ok`; `specify extension add ccloop --dev --from "$(pwd)"` lists `ccloop` (informational).

- [x] **T002** [SUBAGENT] Port `lib/common.sh` (feature-scoped `DATA_DIR`) + add `feature.sh` resolver — `blueprint: Plan Task 2`
  - Create: `.specify/extensions/ccloop/scripts/bash/lib/common.sh` (copy `scripts/lib/common.sh`; change only the data-plane block so `DATA_DIR=${CLAUDE_PROJECT_DIR}/${CCLOOP_FEATURE}/ccloop`), `.specify/extensions/ccloop/scripts/bash/feature.sh`
  - Test: probe group 51 (PROTECTED_PAT matches `tasks.md`, `family_of`, `assert_cross_family` ok, feature resolver echoes `specs/001-demo`)
  - Done: group 51 all `ok`.

**Checkpoint**: extension installs + shared lib is probe-green.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The fail-closed safety primitives the workflow depends on. ⚠️ No user story may begin until this phase is green. T003–T007 touch disjoint new files → parallelizable.

- [x] **T003** [P] [TDD] [SUBAGENT] `progress-status.sh` — JSON counts + `--assert-closed` — `blueprint: Plan Task 3`
  - Create: `.specify/extensions/ccloop/scripts/bash/progress-status.sh`; Test: probe group 52 (open count, total, assert-closed dies on open / passes when closed)

- [x] **T004** [P] [TDD] [SUBAGENT] `progress-lint.sh` — monotonic ladder + `record` — `blueprint: Plan Task 4`
  - Create: `.../progress-lint.sh`; Test: probe group 53 (forward ok, row rewritten, regression/unknown-status/unknown-task refused, `judge-fail→dispatched` retry allowed)

- [x] **T005** [P] [TDD] [SUBAGENT] `contract-derive.sh` — tasks.md → contract + seed progress (idempotent) — `blueprint: Plan Task 5`
  - Create: `.../contract-derive.sh`, `templates/{contract,progress}-template.md`; Test: probe group 54 (seeds T001, contract has T002, re-derive keeps `judge-pass`, no duplicate rows)

- [x] **T006** [P] [TDD] [SUBAGENT] `adapters.sh` — agent-CLI normalizer + die-guarded invoke — `blueprint: Plan Task 6`
  - Create: `.../adapters.sh`, `templates/ccloop-config.template.yml`; Test: probe group 55 (`opencode`/path→claude/case+ext→codex/unknown→unsupported; invoke die-guards, not exec)

- [x] **T007** [P] [TDD] [SUBAGENT] `done-gate.sh` — human sign-off closure — `blueprint: Plan Task 7`
  - Create: `.../done-gate.sh`; Test: probe group 56 (blocks on open blocking debt, passes when clear, flips `judge-pass`→`human-signed`, records sign-off row)

- [x] **T008** [REVIEW] Port the harness + engine scripts to the feature-scoped data plane; re-green existing probes — `blueprint: Plan Task 10 (Steps 1–3, 6–8)`
  - Create (port from `scripts/`): `harness/{freeze,gate,guards}.sh`, `dispatch.sh judge.sh preflight.sh build-context.sh sandbox-run.sh state.sh check-idempotency.sh emit.sh metrics.sh eval-run.sh lessons-lint.sh candidates-append.sh promote-check.sh reflect.sh`, `references/{rubric,lessons,architecture}.md`
  - Change: replace any literal `.cc-local-loop` with `${DATA_DIR}`; add `state.sh arm --feature <f> --json` (writes RUN_ID/ACTIVE, echoes `{"feature":...}`) with probe group 59; repoint existing probe groups 1–49 at the new script paths
  - Done: full `bash tests/run-tests.sh` green (existing + 50–59); `bash -n` clean across the surface. **[REVIEW]** — this is the largest port; a reviewer confirms behavior parity before US work.

**Checkpoint**: Foundation ready — user stories can begin.

---

## Phase 3: User Story 1 — Run the local-model implement loop (Priority: P1) 🎯 MVP

**Goal**: `/speckit.ccloop.run` registers + launches the `ccloop` workflow, which arms, freezes, derives the contract, loops through its gate structure, and pauses at the human done-gate.

**Independent Test**: In a feature with `tasks.md`, run `/speckit.ccloop.run`; `ccloop` workflow registers and launches; `specs/<feature>/ccloop/{contract.md,progress.md}` appear; the workflow validates (`specify workflow info ccloop`) and reaches the human gate (dispatch die-guarded).

- [x] **T009** [TDD] [SUBAGENT] [US1] `workflow/workflow.yml` — the corrected `do-while` loop + validation probe — `blueprint: Plan Task 8`
  - Create: `.specify/extensions/ccloop/workflow/workflow.yml` (do-while; `condition: steps.loop_status.output.data.open > 0`; literal `max_iterations`; `assert_closed`; human `gate` with `show_file`)
  - Test: probe group 57 (exists, id `ccloop`, uses `do-while`, correct `output.data` path, has `assert_closed`, has human `gate`, yaml parses)
  - Optional: `specify workflow add <path> && specify workflow info ccloop`

- [x] **T010** [SUBAGENT] [US1] Commands (`run` self-registers + launches) + `status/reflect/promote/doctor` + `doctor.sh` — `blueprint: Plan Task 9`
  - Modify: `commands/run.md`; Create: `commands/{status,reflect,promote,doctor}.md`, `scripts/bash/doctor.sh`
  - Test: probe group 58 (all command files exist, `run.md` self-registers + launches the workflow, `doctor.sh` prints the matrix)

- [x] **T011** [REVIEW] [US1] MVP acceptance — install → run → artifacts
  - Verify (manual, informational where the CLI is available): `specify extension add ccloop --from "$(pwd)"`; `/speckit.ccloop.run` on a feature with `tasks.md` registers+launches the workflow and creates `specs/<feature>/ccloop/{contract.md,progress.md}`; no-`tasks.md` case refuses. **[REVIEW]** sign-off that US1 acceptance scenarios 1–3 hold.

**Checkpoint**: US1 works end-to-end with live dispatch die-guarded (nothing fakes green).

---

## Phase 4: User Story 2 — Guardrails hold under the loop (Priority: P2)

**Goal**: G1/G9/cross-family/monotonic/assert-closed/uncertain→debt are enforced in code and probed.

**Independent Test**: mutate `tasks.md` → `gate.sh` flags `scope:protected-path-touched`; `build-context.sh` denies `specs/*/ccloop/**`; an `uncertain` verdict opens a `debt.md` row.

- [x] **T012** [P] [TDD] [US2] G9 — `tasks.md` immutability probe — `blueprint: Plan Task 10 Step 5`
  - Test: probe group 61 (gate flags a simulated `tasks.md` checkbox flip as `scope:protected-path-touched`)

- [x] **T013** [P] [TDD] [US2] G1 — `build-context.sh` denies the ccloop data plane — `blueprint: Plan Task 10 Step 4`
  - Modify: `build-context.sh` deny logic to include `specs/*/ccloop/**`; Test: probe group 60 (build-context denies ccloop/**; only `lessons.md` injectable)

- [ ] **T014** [TDD] [US2] Three-valued judge — `uncertain` opens debt, task not passed
  - Wire `judge.sh` verdict `uncertain` → append `debt.md` row + set task `judge-uncertain` via `progress-lint.sh record`; Test: probe (uncertain writes a debt row and does NOT reach `judge-pass`)

- [ ] **T015** [P] [TDD] [US2] Cross-family across adapters — reject same-family implementer+judge regardless of adapter
  - Test: probe (config with implementer.family == judge.family is rejected by `assert_cross_family` before any dispatch)

**Checkpoint**: All guardrail probes green; the loop is safe to run.

---

## Phase 5: User Story 3 — Observe & improve, human-gated (Priority: P3)

**Goal**: read-only status/doctor; human-gated, capped, additive promotion.

**Independent Test**: `/speckit.ccloop.status` prints counts + one next action, mutating nothing; `/speckit.ccloop.promote` refuses unless `promote-check.sh` passes.

- [x] **T016** [P] [US3] `status` read-only snapshot probe
  - Test: probe (`status` renders open/passed/uncertain + exactly one recommended next action; asserts no file mutation)

- [x] **T017** [P] [US3] `doctor` matrix probe (ENFORCED/PARTIAL/TODO reflects real state) — verifies `doctor.sh` output includes the node-ai TODO and adapters PARTIAL rows

- [x] **T018** [US3] Promotion gate probe — `promote-check.sh` refuses on a non-additive/yardstick-touching change; `reflect.sh run` writes only quarantined candidates (never `lessons.md`) — G3/G4

**Checkpoint**: Observability + human-gated improvement path proven.

---

## Phase 6: Polish & Cross-Cutting

- [x] **T019** [REVIEW] Remove the standalone Claude Code plugin form (Q3) — `blueprint: Plan Task 11`
  - Delete: `.claude-plugin/{plugin.json,marketplace.json}`; Modify: `README.md`, `CLAUDE.md`, `CHANGELOG.md` (point to the extension; add `0.5.0` entry). Do NOT remove until the suite is green. **[REVIEW]**.

- [x] **T020** [P] Full-surface lint — `bash -n` all extension scripts + `shellcheck -S warning` (advisory) + final `bash tests/run-tests.sh` green.

- [x] **T021** [P] Docs — update `references/architecture.md` + a `quickstart.md` in `specs/001-ccloop-extension/` describing `specify extension add ccloop --from <repo>` → `/speckit.ccloop.run`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (T001–T002)**: start immediately; T002 depends on T001 (needs the scaffold dir).
- **Foundational (T003–T008)**: depends on Setup. T003–T007 are `[P]` (disjoint new files). **T008 depends on T002** (ported scripts source the ported `common.sh`) and should land after T003–T007 so the re-green includes the new probes. BLOCKS all user stories.
- **US1 (T009–T011)**: depends on Foundational. T009→T010→T011 sequential.
- **US2 (T012–T015)**: depends on Foundational + T008 (harness ported). Independently testable; `[P]` within the phase.
- **US3 (T016–T018)**: depends on T010 (commands exist) + T008 (promote-check/reflect ported).
- **Polish (T019–T021)**: T019 depends on the whole suite green; T020/T021 `[P]`.

### Within a task

- Write the failing probe first (`[TDD]`), confirm RED, implement, confirm GREEN, commit.
- Never mark a task done with a red probe or a die-guard removed prematurely (live dispatch stays guarded — FR-011).

### Parallel Opportunities

- T003, T004, T005, T006, T007 — all `[P][SUBAGENT]`, disjoint files → dispatch together after T002.
- T012, T013, T015 — `[P]` guardrail probes.
- T016, T017 — `[P]`. T020, T021 — `[P]`.

## Parallel Example: Foundational

```bash
# After T002, dispatch the five foundational safety scripts together (fresh subagent each):
Task: "T003 progress-status.sh (Plan Task 3)"
Task: "T004 progress-lint.sh (Plan Task 4)"
Task: "T005 contract-derive.sh (Plan Task 5)"
Task: "T006 adapters.sh (Plan Task 6)"
Task: "T007 done-gate.sh (Plan Task 7)"
```

## Implementation Strategy

### MVP First (US1)

1. Phase 1 Setup → 2. Phase 2 Foundational (CRITICAL, blocks stories) → 3. Phase 3 US1 → **STOP & VALIDATE** (`/speckit.ccloop.run` registers+launches, artifacts created, dispatch die-guarded) → demo.

### Incremental Delivery

Foundation → US1 (MVP: the loop runs, guarded) → US2 (guardrails proven) → US3 (observability) → Polish (drop plugin form). Each story is independently testable and adds value without breaking the previous.

## Notes

- `[P]` = different files, no dependencies. `[SUBAGENT]` = safe to delegate. `[TDD]` = failing probe first. `[REVIEW]` = human gate.
- The regression net is the contract: `bash tests/run-tests.sh` green after every task; new behavior ⇒ new probe (FR-012, SC-001).
- Live node-ai dispatch (removing the `die`-guards + detach/poll) is a **separate follow-up plan** — out of scope here (spec Q5, FR-011).
- Full per-task code + exact commands live in `docs/superpowers/plans/2026-07-06-ccloop-speckit-extension.md`; this file is the spec-kit tracking + phasing view.
