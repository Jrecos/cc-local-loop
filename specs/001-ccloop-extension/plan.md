# Implementation Plan: ccloop — cc-local-loop as a spec-kit extension

**Branch**: `001-ccloop-extension` | **Date**: 2026-07-06 | **Spec**: `specs/001-ccloop-extension/spec.md`

**Input**: Feature specification from `specs/001-ccloop-extension/spec.md`. Full design: `docs/superpowers/specs/2026-07-06-ccloop-speckit-extension-design.md`. Bite-sized blueprint (complete code per task): `docs/superpowers/plans/2026-07-06-ccloop-speckit-extension.md`.

## Summary

Repackage cc-local-loop as a spec-kit 0.12.4 extension (`ccloop`) whose implement loop is a native spec-kit **workflow**. Orchestration is declarative YAML (`do-while` / `shell` / `gate` steps); every safety gate is a bash `shell` step whose non-zero exit halts the run (fail-closed is native to the engine). `tasks.md` stays frozen and is read as the work queue; run-state lives in `specs/<feature>/ccloop/`. Live model dispatch stays `die`-guarded until the node-ai serving topology is deployed.

## Technical Context

**Language/Version**: Bash (portable to macOS bash 3.2 / BSD AND Linux/GNU); YAML (workflow + manifests); Markdown (commands).

**Primary Dependencies**: spec-kit CLI **0.12.4+** (`specify extension|workflow`), `jq`, `git`. Optional agent CLIs (opencode/claude/codex/copilot) as pluggable adapters. No compiler.

**Storage**: files only — code plane in `.specify/extensions/ccloop/`; data plane in `specs/<feature>/ccloop/` (`contract.md`, `progress.md`, `iterations.md`, `verdicts.md`, `debt.md`, `ledger/events.jsonl`, `frozen.json`, `RUN_ID`, `ACTIVE`, `loop_state.json`).

**Testing**: `tests/run-tests.sh` (bash probe harness); `bash -n`; `shellcheck -S warning` (advisory); `specify workflow`/`bundle validate` for manifests.

**Target Platform**: any spec-kit-supported project on macOS or Linux.

**Project Type**: spec-kit extension + workflow (bundle).

**Performance Goals**: N/A (human-paced loop). Each workflow `shell` step must complete < 300s (engine cap) → heavy steps detach + poll.

**Constraints**: portability (no `sed -i`/`date -d`/`realpath`/GNU-only flags); fail-closed vs fail-safe per script; `PROTECTED_PAT` single source of truth; cross-family absolute; G9 tasks.md immutability; `requires.speckit_version: ">=0.12.4"`.

**Scale/Scope**: ~7 new scripts + ~15 ported scripts + 1 workflow + 5 commands + 2 manifests; ~12 new probes on top of the existing 72.

## Constitution Check

*GATE: must pass before and after design.* Checked against `.specify/memory/constitution.md` (cc-local-loop v1.0.0):

- **Guardrails G1–G8 preserved + G9 added** — enforced in bash, probed. ✅
- **Safety logic in scripts, never prose** — the workflow YAML only orchestrates; gates are `shell` steps. ✅
- **Cross-family invariant absolute** — `assert_cross_family`; Opus never a local implementer. ✅
- **Fail-closed vs fail-safe respected per script** — safety scripts `die`; telemetry `exit 0`. ✅
- **Portability (macOS + Linux)** — no GNU-only constructs. ✅
- **Regression net is the contract** — new behavior ⇒ new probe; suite stays green. ✅
- **Frozen calibration un-editable in-loop** — `evals/calibration/**` in `PROTECTED_PAT`. ✅

No violations → Complexity Tracking empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-ccloop-extension/
├── spec.md              # feature spec (done)
├── plan.md              # this file
└── tasks.md             # superspec task breakdown (/speckit.superspec.tasks output)
```

### Source Code (repository root)

```text
.specify/extensions/ccloop/
├── extension.yml                 # manifest: commands, config, after_tasks hook
├── bundle.yml                    # ties extension + workflow, version-pinned
├── README.md
├── commands/
│   ├── run.md                    # self-registers + launches the workflow
│   ├── status.md  reflect.md  promote.md  doctor.md
├── scripts/bash/
│   ├── lib/common.sh             # PORT — PROTECTED_PAT, family_of, cross-family; DATA_DIR→specs/<f>/ccloop
│   ├── feature.sh                # NEW — resolve active feature dir
│   ├── progress-status.sh        # NEW — JSON counts + --assert-closed
│   ├── progress-lint.sh          # NEW — monotonic ladder + record
│   ├── contract-derive.sh        # NEW — tasks.md+plan.md → contract + seed progress
│   ├── adapters.sh               # NEW — get_agent_cli_kind + die-guarded invoke
│   ├── done-gate.sh              # NEW — human sign-off closure
│   ├── doctor.sh                 # NEW — ENFORCED/PARTIAL/TODO matrix
│   ├── dispatch.sh judge.sh preflight.sh build-context.sh sandbox-run.sh   # PORT
│   ├── state.sh check-idempotency.sh emit.sh metrics.sh eval-run.sh        # PORT
│   ├── lessons-lint.sh candidates-append.sh promote-check.sh reflect.sh    # PORT
│   └── harness/{freeze,gate,guards}.sh                                     # PORT
├── templates/{ccloop-config.template.yml, contract-template.md, progress-template.md}
├── references/{rubric.md, lessons.md, architecture.md}                     # PORT
└── workflow/workflow.yml         # NEW — the do-while loop (self-registered to .specify/workflows/ccloop/)

tests/run-tests.sh                # EXTEND — add ccloop probes (groups 50–61)
```

**Structure Decision**: single spec-kit extension packaged as a bundle; the workflow ships inside the extension and self-registers. Data plane is per-feature under `specs/<feature>/ccloop/` (keeps `tasks.md` frozen while giving the loop durable state — Approach C).

## Complexity Tracking

No constitution violations — none required.
