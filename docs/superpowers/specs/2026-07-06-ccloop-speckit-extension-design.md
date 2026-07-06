# Design (DRAFT): `ccloop` — cc-local-loop as a spec-kit 0.12.4 bundle

**Status:** DRAFT for validation + user review. Not yet approved. Not an implementation license.
**Date:** 2026-07-06
**Target host:** GitHub Spec Kit **0.12.4** (workflow engine + bundle primitive era).
**Supersedes framing of:** the standalone Claude Code plugin form of `cc-local-loop`.

---

## 1. Problem & thesis

`cc-local-loop` today is a Claude Code *plugin* implementing the invariant **Opus 4.8 orchestrates → local models (via OpenCode on node-ai) implement → cross-family judge gates → Opus reviews**, converging on a **Definition of Done enforced in code**, with eight guardrails (G1–G8) enforced in bash and a 72-probe regression net.

We are **repackaging it as a first-class spec-kit extension/bundle** so it is versioned, namespaced, installable via `specify`, and wired into the SDD lifecycle. The user's hard requirement: **maximally compatible with the spec-kit plugin.**

The key realization from the 0.12.4 investigation: spec-kit now ships a **workflow engine** (built-in step types `init/shell/command/gate/while/do-while/if/switch/fan-out/fan-in`, with `specify workflow run|resume|status`) and a **bundle** packaging primitive. So the loop orchestration should be expressed as a **native workflow YAML**, with all *safety-critical* logic remaining in **bash `shell` steps that fail closed** — orchestration in YAML, gates in code.

## 2. Locked decisions (from brainstorming)

1. **Pure extension**, not dual-packaged — drop the `.claude-plugin/` + marketplace form.
2. **Own the implement phase** — the extension consumes `tasks.md` and executes each task on local models, judge-gated, Opus-reviewed.
3. **Pluggable agent-CLI adapters** (ralph-style) with **OpenCode + local models as default**; cross-family invariant maps onto configured adapters.
4. **Progress + feedback layer** from aide (per-task DoD + monotonic progress + trade-offs log); skip aide's vision/roadmap (spec.md/plan.md cover that).
5. **Approach C (hybrid):** `tasks.md` stays frozen/PROTECTED; run-state lives in a separate ID-keyed mutable ledger. (Resolves the ralph tension where the loop mutates `tasks.md`.)

## 3. What we extract from the three studied extensions

- **ralph →** `get_agent_cli_kind()` normalizer + `invoke_<kind>_iteration()` dispatcher; per-CLI arg table (opencode/claude/codex/copilot); two-axis abstraction (transport × prompt-delivery, inline-the-contract fallback); `*_EXPLICIT` config precedence; `is_agent_resolution_failure()` two-tier failure; completion-token-alone-on-a-line hardening; fire-and-forget launcher.
- **spec-kit-loop →** per-criterion status ladder (role-scoped transitions); done-criteria contract table with "how the checker verifies" column; three-valued verdict `pass|fail|uncertain→debt`; comprehension-debt ledger + human sign-off; budgeted/sliced `status` render + deterministic next-action; budget gate *before* orienting; independence gate as prompt-side defense-in-depth.
- **aide →** per-item Testing-Prereqs / Expected-Outcomes / Validation block (a DoD written *before* implementation); monotonic `progress.md`; in-item Decisions & Trade-offs log; file-existence-as-truth + inconsistency flagging.
- **Uniform anti-pattern (do NOT copy):** all three enforce guardrails in *prose only*. We own the runtime — every borrowed rule is re-enforced in `scripts/bash/` with a test probe, never left as skill/YAML prose. Especially: aide's `feedback-loop` self-editing of installed prompts is routed through our `candidates → promote-check → human PR` pipeline (G3/G4), never applied directly.

## 4. Packaging: a spec-kit **bundle** (manifest-of-references) + local-path install

> **Fable-validated correction (B3):** a 0.12.4 bundle is **NOT a self-contained zip**. `bundle install` reads only `bundle.yml` from the archive and then resolves each referenced component **by id** from the core_pack or a registered catalog — the zip's own `scripts/`, `workflow.yml`, etc. are never extracted (`bundler/services/primitives.py`, `commands/bundle/__init__.py`). So the bundle manifest is a *tie-together*, not a payload.
>
> **Distribution decision (LOCKED): install straight from the repo URL with one command:**
> ```
> specify extension add ccloop --from <repo-url>
> ```
> `--from <custom URL>` is a real 0.12.4 flag (`specify extension add --help`). The extension **ships its own `workflow.yml`** inside its dir (`.specify/extensions/ccloop/workflow/workflow.yml`); on the first `/speckit.ccloop.run`, the `run` command **self-registers** the workflow if absent — `specify workflow add .specify/extensions/ccloop/workflow/workflow.yml` (that command accepts "ID, URL, or local path") — then `specify workflow run ccloop`. So the user runs exactly one install command; the workflow registration is automatic and idempotent.
>
> A `bundle.yml` is still authored (versions/names the extension+workflow pair together, with the enforced `requires.speckit_version` floor) and can later back a published catalog, but the **primary supported install is `extension add … --from <repo>`.** The self-contained-`.zip` story is dropped.
>
> Bundle manifest required fields (strict, per `bundler/models/manifest.py`): `schema_version: "1.0"`; `bundle.{id,name,version,role,description,author,license}`; `requires.speckit_version: ">=0.12.4"`; `provides.{extensions,workflows}` refs must be **version-pinned semver**; `bundle build` also requires a `README.md`.

The component layout (installed to their canonical locations):

```
bundle.yml                        # bundle manifest → references the extension + workflow
.specify/extensions/ccloop/
  extension.yml                   # schema 1.0; requires speckit >=0.12.4; hooks (§9)
  commands/                       # speckit.ccloop.* agent prompts ($ARGUMENTS)
    run.md        # launcher — kicks `specify workflow run ccloop` fire-and-forget
    status.md     # read-only budgeted snapshot + one deterministic next action
    reflect.md    # distill ledger → quarantined candidate lessons (offline)
    promote.md    # human-gated lesson-promotion PR (disable-model-invocation)
    doctor.md     # ENFORCED / PARTIAL / TODO matrix
  scripts/bash/                   # the deterministic muscle (ported + new)
    lib/common.sh                 # PROTECTED_PAT, family_of, assert_cross_family, ledger_append, sha256
    adapters.sh                   # NEW — get_agent_cli_kind + invoke_<kind> (ralph)
    contract-derive.sh            # NEW — tasks.md + plan.md → per-task DoD contract (aide+loop)
    progress-status.sh            # NEW — emits JSON {open, passed, uncertain, ...} for the while-condition
    progress-lint.sh              # NEW — monotonic progress, fail-closed (aide, G4-style)
    done-gate.sh                  # NEW — human sign-off closure check (loop guard)
    dispatch.sh judge.sh preflight.sh build-context.sh sandbox-run.sh
    state.sh check-idempotency.sh emit.sh metrics.sh eval-run.sh
    lessons-lint.sh candidates-append.sh promote-check.sh
    harness/{freeze,gate,guards}.sh
  templates/{ccloop-config.template.yml, contract-template.md, progress-template.md}
  references/{rubric.md, lessons.md, architecture.md}
.specify/workflows/ccloop/
  workflow.yml                    # NEW — the loop orchestration (§6)
```

`scripts/powershell/` mirrors are deferred (bash-first; tracked as a PARTIAL/TODO in `doctor.sh`).

## 5. Data plane moves into the spec-kit feature dir

Instead of `.cc-local-loop/` in the target repo, run-state lives under spec-kit's own feature dir (mirrors spec-kit-loop's `specs/<feature>/loop/`):

```
specs/<NNN-feature>/
  spec.md  plan.md  tasks.md          # spec-kit core — tasks.md is FROZEN / matched by PROTECTED_PAT
  ccloop/                              # the per-feature data plane
    contract.md      # derived per-task DoD: | TaskID | Criterion | How judge verifies | Status |
    progress.md      # MUTABLE state machine, keyed by task ID (aide-monotonic)
    iterations.md    # append-only implementer records (loop)
    verdicts.md      # append-only judge verdicts pass|fail|uncertain (loop)
    debt.md          # uncertain/open-debt rows + human sign-off log (loop)
    ledger/events.jsonl   # observability telemetry — NEVER injected (G1)
    frozen.json  RUN_ID  ACTIVE  loop_state.json   # freeze pin + arming + schema-pinned state (G2)
```

**This is the crux of Approach C:** `tasks.md` is never written by the loop — completion lives in `progress.md` keyed by task ID. `PROTECTED_PAT` and every G-invariant survive intact, and the loop still gets a durable per-task state machine.

## 6. The loop as a spec-kit workflow (`workflow.yml`)

Orchestration is declarative YAML; **every safety gate is a bash `shell` step whose non-zero exit HALTS the workflow (fail-closed is native to the engine).** The `while` condition reads a JSON status published by a `shell` step (`output_format: json`).

```yaml
schema_version: "1.0"
workflow:
  id: ccloop
  name: "Opus-orchestrated local-model implement loop"
  version: "0.5.0"
requires:                                  # a workflow's own `requires` is ADVISORY only —
  speckit_version: ">=0.12.4"              # engine does NOT enforce it; the BUNDLE manifest does
  integrations: { any: [claude, opencode, codex, copilot] }
inputs:
  feature: { type: string, default: "auto" }   # resolved via check-prerequisites.sh
  # NOTE: no max_iterations input — the do-while cap must be a LITERAL int (templating is
  # rejected at validation). guards.sh owns the durable/tunable bound.
steps:
  - id: arm            # resolve feature, write RUN_ID/ACTIVE, cross-family preflight
    type: shell
    output_format: json                    # so steps.arm.output.data.feature resolves later
    run: "bash .specify/extensions/ccloop/scripts/bash/state.sh arm --feature '{{ inputs.feature }}' --json"
  - id: freeze         # hash-pin protected spine — fail-closed
    type: shell
    run: "bash .specify/extensions/ccloop/scripts/bash/harness/freeze.sh"
  - id: derive         # tasks.md + plan.md → contract.md + seed progress.md (all pending)
    type: shell
    run: "bash .specify/extensions/ccloop/scripts/bash/contract-derive.sh"
  - id: loop
    type: do-while     # NOT `while`: a `while` checks its condition BEFORE iter 1, when
                       # loop_status has never run → falsy → body never runs (silent no-op, B1).
                       # do-while runs the body once, then re-checks after each iteration.
    condition: "{{ steps.loop_status.output.data.open > 0 }}"   # note the .output.data path (B2)
    max_iterations: 20   # LITERAL int only (B5). Belt-and-suspenders vs guards.sh's durable cap.
    steps:
      - id: loop_status   # publishes {open, passed, uncertain, ...}; re-runs each iteration
        type: shell
        output_format: json
        run: "bash .specify/extensions/ccloop/scripts/bash/progress-status.sh --json"
      - id: dispatch      # detach-start + bounded poll — a direct dispatch WILL exceed 300s (R1).
        type: shell       # --no-op-if-closed makes the guaranteed first do-while pass safe on empty
        run: "bash .specify/extensions/ccloop/scripts/bash/dispatch.sh next --detach --no-op-if-closed"
      - id: judge         # cross-family judge + sandboxed tests; also detach+poll (tests can exceed 300s)
        type: shell
        run: "bash .specify/extensions/ccloop/scripts/bash/judge.sh next --detach"
      - id: gate          # freeze hash-verify + test runner — fail-closed (non-zero HALTS the run)
        type: shell
        run: "bash .specify/extensions/ccloop/scripts/bash/harness/gate.sh"
      - id: record        # progress-lint (monotonic) + status update keyed by task ID
        type: shell
        run: "bash .specify/extensions/ccloop/scripts/bash/progress-lint.sh record"
  - id: assert_closed     # FAIL-CLOSED: cap-exhaustion must NOT reach the gate looking successful (B4)
    type: shell
    run: "bash .specify/extensions/ccloop/scripts/bash/progress-status.sh --assert-closed"
  - id: human_done_gate   # the ONE human gate — shows debt.md; PAUSES if non-TTY → resume to sign off
    type: gate
    message: "All tasks judge-pass. Review comprehension debt below, then approve to close."
    show_file: "specs/{{ steps.arm.output.data.feature }}/ccloop/debt.md"
    options: [approve, reject]
    on_reject: abort
  - id: signoff           # records the human sign-off row (never fabricated by an agent) — G3
    type: shell
    run: "bash .specify/extensions/ccloop/scripts/bash/done-gate.sh signoff"
  - id: reflect           # offline distill → quarantined candidates (never auto-applied)
    type: shell
    run: "bash .specify/extensions/ccloop/scripts/bash/reflect.sh run"
```

Notes (Fable-validated against `workflows/engine.py`, `steps/*`, `expressions.py`):
- **Fail-closed is native:** a bash gate exiting non-zero → the `shell` step is FAILED → the whole run FAILS and returns (not just the loop). `continue_on_error: true` is the only opt-out and is validated to a literal bool — never set it on a safety step.
- **The engine really iterates + re-evaluates:** it runs the body once via `next_steps`, then up to `max_iterations-1` more times, re-running each nested step (incl. `loop_status`) under a namespaced id aliased back to the bare id, so the condition re-checks against fresh output.
- **Resumability caveat:** `specify workflow resume|status` work, but resume **re-runs the whole `do-while` from scratch with a fresh `max_iterations` budget** (nested-step resume uses `step_offset=-1`). The engine cap is therefore NOT durable across resumes — **`guards.sh` owns the durable MAX_ITER/TIME bound**; `progress.md`-keyed idempotency makes re-running safe for work already done.
- **Non-TTY gate → PAUSE:** an agent-launched run hits `human_done_gate`, goes PAUSED, and the human signs off via `specify workflow resume <run_id>` in a real terminal — the sign-off UX is built around resume, not an inline prompt.
- **300s cap is broad (R1):** it hits `dispatch`, `judge`, AND `gate.sh`'s test runner / `sandbox-run.sh`. Every step that can exceed 300s uses detach-start + bounded poll (each poll < 300s), or runs the heavy work outside the engine. `command`-type steps have no timeout but don't capture streamed stdout (so they can't feed the judge) — `shell`+detach is the chosen pattern.
- `run.md` (`speckit.ccloop.run`) validates prereqs then `specify workflow run ccloop` in a visible terminal and exits — Opus does not babysit (economics).
- **Hooks are agent-dispatched, not engine-dispatched:** `after_tasks`/`after_implement` fire via instructions the core command markdown gives the agent (best-effort) — fine for opt-in launch, and deliberately NOT in the safety chain.

## 7. Status ladder (schema-pinned in `state.sh`, G2; role-scoped)

Per task ID in `progress.md`:
```
pending → dispatched → implemented → judge-pass | judge-fail | judge-uncertain → human-signed
```
- **adapter/implementer** may only reach `implemented`.
- **cross-family judge** owns `judge-pass|fail|uncertain`; `judge-uncertain` opens a `debt.md` row (never vanishes).
- **human done-gate** owns `human-signed` / feature `done`.

`progress-lint.sh` enforces monotonicity (never regress a status; defer-not-delete; IDs must match `tasks.md`) — fail-closed, in the `lessons-lint.sh` mold.

## 8. Pluggable adapters (`adapters.sh`)

`get_agent_cli_kind()` normalizer (bash-3.2-safe `tr`; strip path/ext) → `opencode|claude|codex|copilot|unsupported`; dispatcher `invoke_<kind>_iteration(model, prompt, work_dir)` with per-CLI arg shapes (stdin vs `-p`, per-CLI permission flag), teed-stream + `PIPESTATUS` capture. Prompt-delivery: inline the iterate contract for print-mode CLIs; registered `speckit-ccloop-iterate` for copilot. **Default: `opencode` + local model.**

Cross-family invariant holds: `assert_cross_family(implementer.family, judge.family)` in `common.sh`; the family map extends to configured adapters/models; Opus is never a local implementer. Config precedence (ralph-style, `*_EXPLICIT`): defaults → `ccloop-config.yml` → `ccloop-config.local.yml` → `SPECKIT_CCLOOP_*` env → args.

## 9. Extension hooks (`extension.yml`)

- `after_tasks`: optional, prompt "Run the ccloop local-model implement loop?" → `speckit.ccloop.run`.
- `after_implement`: optional → `speckit.ccloop.status`.
- (No `before_*` mandatory hooks — the loop is opt-in.)

## 10. Guardrails: G1–G8 preserved + G9

Every borrowed rule re-enforced in bash (never YAML/skill prose). G1–G8 carry over with only path updates (`build-context.sh` denylist gains `specs/*/ccloop/**` so telemetry/state is never injected — G1). **New G9 — `tasks.md` immutability:** the loop never writes `tasks.md`; `freeze.sh`/`gate.sh` hash-verify it and `progress-lint.sh` keeps completion in `progress.md`. This is the guard that makes ralph's pattern safe here.

**Fail-closed maps natively:** a bash gate that exits non-zero makes its `shell` step FAIL, which halts the workflow. The judge, freeze, gate.sh, progress-lint, done-gate must therefore keep exiting non-zero on any doubt. The single `gate`-type step (human done-gate) is a human decision, appropriately model-free.

## 11. New test probes (the review contract)

New behavior ⇒ new probes, same PR. Additions: adapter normalizer (names/paths → kind; unsupported→exit 2) · cross-family rejection across adapters · `build-context` denies `specs/*/ccloop/**` · `progress-lint` rejects regression/deletion/ID-mismatch · `freeze`/`gate` reject any `tasks.md` mutation (G9) · `contract-derive` idempotent + monotonic · three-valued judge opens a debt row on uncertain · `done-gate` refuses closure without a sign-off row / with open blocking debt · completion-token only-on-a-line · config precedence chain · **`extension.yml` + `workflow.yml` + `bundle.yml` parse and validate** (`specify workflow` validation) · command-file existence + `speckit.ccloop.*` namespace match · **workflow shell steps stay within the 300s budget or are async (§13).**

## 12. Migration sequence

1. Scaffold bundle shell: `bundle.yml`, `extension.yml`, `workflow.yml`, dirs.
2. Port existing scripts with the `.cc-local-loop/` → `specs/<feature>/ccloop/` path change; green the existing 72 probes.
3. Add `adapters.sh`, `contract-derive.sh`, `progress-status.sh`, `progress-lint.sh`, `done-gate.sh` + their probes.
4. Wire `commands/` + hooks + `workflow.yml`; validate with `specify workflow` + `specify bundle validate`.
5. Update `doctor.sh` matrix + `README` + `references/architecture.md`; keep the node-ai calls `die`-guarded until the Option-B serving topology is live (nothing fakes green).

## 13. Validation outcomes (Fable, adjudicated against installed 0.12.4 source)

Overall: **viable-with-fixes.** Core safety thesis verified — non-zero shell exit fails the run (fail-closed native), the engine genuinely iterates the loop body and re-evaluates the condition, the human gate aborts on reject, and nothing in the engine writes `tasks.md` (Approach C / G9 intact).

| Risk | Verdict | Resolution folded into this doc |
|---|---|---|
| R1 — 300s shell timeout | **CONFIRMED** (`steps/shell:timeout=300`, no override; hits dispatch, judge, sandboxed tests too) | Detach-start + bounded poll for every heavy step (§6 notes). |
| R2 — while-condition over JSON | **CONFIRMED problem** — path wrong AND `while` no-ops | Use `do-while`; path is `steps.<id>.output.data.<field>`; `arm` gains `output_format: json` (§6). |
| R3 — command vs shell dispatch | **shell confirmed correct** (`command` steps only dispatch spec-kit commands, don't capture streamed stdout) | `shell`+detach chosen (§6, §8). |
| R4 — one bundle carries payloads | **REFUTED** — install resolves components by id from catalogs only | §4 rewritten: bundle = manifest-of-references; primary install = `extension add <path>` + `workflow add <path>`. |
| R5 — version floor | **UNKNOWN → pin `>=0.12.4`** (bundle `requires` is enforced; workflow `requires` is advisory) | §4/§6 pinned to `>=0.12.4`. |
| R6 — repo identity | process | See §14 open questions. |

**Blockers B1–B5 (all resolved in §4/§6):** B1 `while`→`do-while` + no-op-safe dispatch · B2 `.output.data.` paths + `arm` json · B3 bundle-payload myth → catalog/local-path install · B4 post-loop `assert_closed` fail-closed step · B5 literal `max_iterations`, guards.sh owns the durable cap.

## 14. Decisions (LOCKED by user, 2026-07-06)

- **Q1 · Extension id → `ccloop`** — commands `speckit.ccloop.*`.
- **Q2 · Distribution → install from the repo URL:** `specify extension add ccloop --from <repo-url>`; the extension self-registers its bundled `workflow.yml` on first run (see §4).
- **Q3 · Remove the plugin form → YES** — delete `.claude-plugin/` + marketplace; the repo becomes the extension/bundle source.
- **Q4 · Heavy-work placement → detach+poll INSIDE the workflow** — one resumable artifact via `specify workflow run|resume`; heavy steps (dispatch, judge, sandboxed tests) start detached with bounded poll steps under the 300s cap.
```
