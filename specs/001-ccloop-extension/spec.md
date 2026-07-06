# Feature Specification: ccloop — cc-local-loop as a spec-kit extension

**Feature Branch**: `001-ccloop-extension`
**Created**: 2026-07-06
**Status**: Draft
**Input**: Repackage cc-local-loop (an Opus-orchestrated, local-model-executed dev loop) as a spec-kit 0.12.4 extension + workflow, extracting the agent-CLI abstraction (spec-kit-ralph), the loop/verdict model (spec-kit-loop), and the per-task DoD + progress model (aide).

**Design source**: `docs/superpowers/specs/2026-07-06-ccloop-speckit-extension-design.md` (Approach C, Fable-validated). Implementation blueprint: `docs/superpowers/plans/2026-07-06-ccloop-speckit-extension.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run the local-model implement loop over tasks.md (Priority: P1) 🎯 MVP

A developer who has produced `tasks.md` (via `/speckit.tasks`) installs ccloop and runs it. The loop reads `tasks.md` as a frozen work queue, dispatches each task to a local model, a cross-family judge gates each change, and the developer signs off at the end. They pay for Opus only to think/review; the volume runs on local hardware.

**Why this priority**: This is the reason the extension exists — turning `tasks.md` into implemented, judge-gated work on local models. Everything else supports it.

**Independent Test**: With a feature that has `tasks.md`, run `/speckit.ccloop.run`; the `ccloop` workflow registers and launches, `arm`/`freeze`/`derive` produce `specs/<feature>/ccloop/{contract.md,progress.md}`, the `do-while` loop iterates its gate structure, and the workflow pauses at the human done-gate. (Live model dispatch is `die`-guarded until the node-ai serving topology is deployed — the loop verifies its cage before entering it; nothing fakes green.)

**Acceptance Scenarios**:

1. **Given** a feature with `tasks.md`, **When** the developer runs `/speckit.ccloop.run`, **Then** the `ccloop` workflow is registered (idempotently) and launched, and `specs/<feature>/ccloop/` is created with a derived contract and a seeded `progress.md`.
2. **Given** a project with no `tasks.md`, **When** the developer runs `/speckit.ccloop.run`, **Then** it refuses and tells them to run `/speckit.tasks` first.
3. **Given** every task has reached `judge-pass`, **When** the workflow reaches the human done-gate, **Then** it shows `debt.md` and requires an explicit human approval before closing.

---

### User Story 2 - Guardrails hold under the loop (Priority: P2)

The safety invariants (G1–G9) that make a self-improving loop safe are enforced in code, not prose, throughout the extension.

**Why this priority**: The loop is only acceptable if it cannot corrupt the spec-kit artifacts or inject telemetry into implementer prompts. Without this the MVP is unsafe to run.

**Independent Test**: Mutating `tasks.md` makes `gate.sh` flag `scope:protected-path-touched` (G9); `build-context.sh` refuses to inject anything under `specs/*/ccloop/**` (G1); an implementer/judge sharing a model family is rejected by `assert_cross_family`.

**Acceptance Scenarios**:

1. **Given** the loop is running, **When** any step writes `tasks.md`, **Then** `gate.sh` fails closed (`tasks.md` ∈ `PROTECTED_PAT`).
2. **Given** context is built for an implementer, **When** `build-context.sh` runs, **Then** only `references/lessons.md` is eligible for injection and the `ccloop/` data plane is denied.
3. **Given** a judge status of `uncertain`, **When** the judge records its verdict, **Then** a row is opened in `debt.md` and the task is not marked passed.
4. **Given** the iteration cap is exhausted with open tasks, **When** the loop ends, **Then** `assert_closed` fails closed so the run never reaches the done-gate looking successful.

---

### User Story 3 - Observe and improve, human-gated (Priority: P3)

The developer inspects loop status and, over time, promotes distilled lessons — but only through a human-gated, capped, additive path.

**Why this priority**: Observability and improvement add durable value but are not required for a first correct run.

**Independent Test**: `/speckit.ccloop.status` prints counts + one next action without mutating anything; `/speckit.ccloop.doctor` prints the ENFORCED/PARTIAL/TODO matrix; `/speckit.ccloop.promote` refuses without passing `promote-check.sh`.

**Acceptance Scenarios**:

1. **Given** a run in progress, **When** the developer runs `/speckit.ccloop.status`, **Then** they get open/passed/uncertain counts and exactly one recommended next action, read-only.
2. **Given** a candidate lesson, **When** `/speckit.ccloop.promote` runs, **Then** `promote-check.sh` gates it (additive-only, cap, provenance, yardstick untouched) and only a human opens the PR.

### Edge Cases

- **Empty task list / first do-while pass**: the guaranteed first iteration must be a safe no-op (`dispatch --no-op-if-closed`), since the `do-while` body runs once before the condition is checked.
- **Iteration-cap exhaustion**: must fail closed via `assert_closed`, never present a false "all passed" to the human gate.
- **300s shell-step timeout**: dispatch, judge, and sandboxed tests can exceed it → they run detached with bounded poll steps.
- **Non-TTY run**: the human gate PAUSES; sign-off happens via `specify workflow resume <run_id>`.
- **Resume**: re-runs the whole `do-while` with a fresh engine cap → the durable bound lives in `guards.sh`; `progress.md`-keyed idempotency makes re-running safe.
- **Unknown model family**: `assert_cross_family` fails closed rather than guessing.

## Open Questions

| # | Question | Status | Resolution |
|---|----------|--------|------------|
| Q1 | Extension id | Resolved | `ccloop` → commands `speckit.ccloop.*` |
| Q2 | Distribution | Resolved | `specify extension add ccloop --from <repo-url>`; extension self-registers its bundled `workflow.yml` on first run |
| Q3 | Keep the standalone Claude Code plugin form? | Resolved | No — remove `.claude-plugin/` + marketplace; the repo becomes the extension/bundle source |
| Q4 | Heavy-work placement (300s cap) | Resolved | Detach+poll INSIDE the workflow (one resumable artifact) |
| Q5 | Live node-ai dispatch | Open | Deferred — `die`-guarded until the node-ai "Option-B" serving topology is deployed (follow-up plan) |

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The extension MUST install via `specify extension add ccloop --from <repo-url>` and register as `ccloop` with commands `speckit.ccloop.{run,status,reflect,promote,doctor}`.
- **FR-002**: `speckit.ccloop.run` MUST self-register the bundled `workflow.yml` (idempotently) and launch `specify workflow run ccloop` fire-and-forget.
- **FR-003**: The loop MUST read `tasks.md` as a read-only work queue and MUST NOT write it (G9); completion state MUST live in `specs/<feature>/ccloop/progress.md` keyed by task ID.
- **FR-004**: The workflow MUST use `do-while` (not `while`) with a literal `max_iterations`, a `condition` reading `steps.loop_status.output.data.open`, and a fail-closed `assert_closed` step before the human gate.
- **FR-005**: Every safety gate (`freeze`, `gate`, `judge`, `progress-lint`, `progress-status --assert-closed`, `done-gate`, `contract-derive`) MUST be a bash step that exits non-zero on any doubt (fail-closed).
- **FR-006**: The implementer's model family MUST never equal the judge's (`assert_cross_family`); Opus MUST never be a local implementer.
- **FR-007**: Only `references/lessons.md` MAY be injected into an implementer/judge prompt; the `ccloop/` data plane MUST be denied by `build-context.sh` (G1).
- **FR-008**: `progress.md` status transitions MUST be monotonic (`progress-lint.sh`), with the sole exception `judge-fail → dispatched` (retry); deletions and regressions MUST be refused.
- **FR-009**: A judge verdict of `uncertain` MUST open a `debt.md` row and MUST NOT mark the task passed.
- **FR-010**: Closure MUST require an explicit recorded human sign-off with no open blocking debt (`done-gate.sh`); an agent MUST NOT synthesize the sign-off.
- **FR-011**: Live model dispatch (`adapters.sh`/`dispatch.sh`/`judge.sh`) MUST remain `die`-guarded until the node-ai serving topology is deployed — nothing fakes a pass.
- **FR-012**: Every new script/behavior MUST add a probe to `tests/run-tests.sh`, which MUST stay green.

### Key Entities

- **contract.md**: derived per-task Definition of Done (`| Task | Criterion | How judge verifies | Status |`).
- **progress.md**: the mutable per-task state machine keyed by task ID; statuses `pending → dispatched → implemented → judge-pass|judge-fail|judge-uncertain → human-signed`.
- **debt.md**: open comprehension-debt rows + the human sign-off log.
- **ccloop workflow**: the `do-while` step-graph orchestrating the loop.
- **adapter**: an agent-CLI backend (`opencode|claude|codex|copilot`) selected by `get_agent_cli_kind`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `bash tests/run-tests.sh` passes 100% (existing probes + all new ccloop probes) after every task.
- **SC-002**: `specify extension add ccloop --from <repo>` then `/speckit.ccloop.run` produces `specs/<feature>/ccloop/{contract.md,progress.md}` and a launched (or validatable) `ccloop` workflow.
- **SC-003**: 100% of safety gates fail closed — every guardrail probe (G1, G9, cross-family, monotonic ladder, assert-closed, done-gate) is red before its implementing task and green after.
- **SC-004**: Zero writes to `tasks.md` by the loop across a full run (G9 probe).
- **SC-005**: The whole surface passes `bash -n` and `shellcheck -S warning` (advisory).

## Assumptions

- Target host is spec-kit **0.12.4+** (workflow engine + `--from` install + `do-while`/`shell output_format`/`gate show_file`).
- Developers run on macOS (bash 3.2/BSD) or Linux (GNU); scripts must be portable to both.
- The node-ai serving topology is NOT yet deployed; live dispatch stays `die`-guarded (follow-up).
- `tasks.md` is produced by `/speckit.tasks` and matched by the existing `PROTECTED_PAT`.

## Brainstorm Log

### Session 2026-07-06
**Focus**: Repackaging cc-local-loop as a spec-kit extension; extracting from ralph/loop/aide; 0.12.4 workflow+bundle primitives.
**Key insights**:
- 0.12.4's workflow engine makes fail-closed native (non-zero shell exit halts the run) and gives resumability for free.
- Approach C resolves the ralph `tasks.md`-mutation tension: keep `tasks.md` frozen, put run-state in a separate ID-keyed `progress.md` (G9).
- Fable validation confirmed viability and forced fixes: `while`→`do-while`, `.output.data.` paths, bundle-payload myth → `--from` install, post-loop `assert_closed`, literal `max_iterations`, detach+poll for the 300s cap.
**Decisions**: Q1 `ccloop`; Q2 `--from` install + self-registered workflow; Q3 remove plugin form; Q4 detach+poll inside the workflow.
