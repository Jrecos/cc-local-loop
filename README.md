# cc-local-loop

**An Opus-orchestrated autonomous dev loop that executes on local models.** Claude Code (Opus 4.8) is the entry point: it plans (spec-driven), dispatches executor agents that run **inside OpenCode's harness** on your **local models** (node-ai), and a **cross-family Gemma judge** gates every change. Opus reviews. You pay your Opus subscription only to *think and review*; the heavy volume runs **free** on your hardware.

> **Invariant:** `Opus 4.8 → local models → Opus 4.8`. The loop converges on a deterministic **Definition of Done** enforced in code, never by a model's opinion.

> **As of v0.5.0 this is a GitHub Spec Kit extension (`ccloop`), not a standalone Claude Code plugin.**
> Install: `specify extension add ccloop --from <repo-url>`, then `/speckit.ccloop.run` in a feature that has `tasks.md`.
> The implement loop is a spec-kit **workflow**; the data plane lives in `specs/<feature>/ccloop/`; `tasks.md` is the frozen
> work queue (G9). See `specs/001-ccloop-extension/quickstart.md` and `docs/superpowers/specs/2026-07-06-ccloop-speckit-extension-design.md`.
> Run `/speckit.ccloop.doctor` (or `bash .specify/extensions/ccloop/scripts/bash/doctor.sh`) for the live ENFORCED/PARTIAL/TODO matrix.

This is the packaged form of the design in `homelab/docs/ai-dev-orchestration-workflow.md` (v11) — **the combination of interconnected skills** that no single existing tool provided, now versioned and namespaced as a spec-kit extension that improves over time via PRs.

---

## Status: v0.5.0 — spec-kit extension (was: v0.4.0 hardened plugin scaffold)

The **structure, skills, hooks, and contracts are in place and the safety guarantees are enforced in code** — verified by a **71-probe** regression net (`tests/run-tests.sh`) after an expert review ([`docs/REVIEW-v0.1.md`](docs/REVIEW-v0.1.md)), a round of field-benchmark hardening (circuit breaker, `--network none` test sandbox, budgeted narrow context, two-level state, check-idempotency), and a v0.4 **observability-only telemetry layer** with a human-gated improvement cadence (`emit` · `metrics` · `eval-run` · `lessons-lint`, guardrails G1–G8 — see the CHANGELOG). The node-ai calls (`dispatch.sh` / `judge.sh`) and `gate.sh`'s test runner remain `die`-guarded until the node-ai **"Option-B" serving topology** is deployed (see *Preconditions*) — a loop that verifies its cage before entering it. Run `bash scripts/doctor.sh` for the live **ENFORCED / PARTIAL / TODO** matrix.

---

## What's inside (one plugin, several single-responsibility skills)

| Component | What it does |
|---|---|
| **skill `run-loop`** | The orchestrator Opus follows: `route → freeze → implement → commit → gate → judge → adjust → done`, with stop rules. Arms the loop (`.cc-local-loop/ACTIVE`). Human-invoked (`/cc-local-loop:run-loop`). |
| **skill `dispatch`** | How Opus dispatches a **fresh `opencode run` per task** (no `--attach`) so the local implementer runs inside OpenCode's permission-hardened harness. Runs only inside an active loop. |
| **skill `judge`** | How the **Gemma-31B judge** runs as a raw two-pass API call (no tools); the harness executes the adversarial tests it emits. Cross-family per the invariant. |
| **skill `reflect`** | Distills the execution **ledger** into **quarantined candidate lessons** (offline; never auto-applied; no-ops on an empty ledger). |
| **skill `promote-lessons`** | **Human-gated** promotion: opens a PR moving a candidate into `lessons.md` with non-regression evidence, gated by `promote-check.sh`. `disable-model-invocation` — only a human starts it. |
| **skill `metrics`** | **Read-only** report over the event stream (accepted changes, escalation rate, judge/gate rates, the lesson funnel, cost-per-accepted-change as a *gauge*). Output is for the human — **never injected** into a loop prompt (G1). |
| **skill `using-cc-local-loop`** | Orientation/router: explains the loop, routes the user to the right skill, shows status. Never dispatches or judges. |
| **hook `Stop`** | Appends a `run_end` event to the stream — **only inside an active loop**. Fail-safe (errors never block the session). |
| **scripts** | The deterministic muscle: `harness/{freeze,gate,guards}.sh` (guards = MAX_ITER + TIME + no-progress + oscillation + heartbeat), `dispatch.sh`, `judge.sh`, `preflight.sh`, `build-context.sh` (narrow, budgeted), `sandbox-run.sh` (`--network none` test isolation), `state.sh` (STATUS.md + loop_state.json), `check-idempotency.sh`, `emit.sh` (validated event writer), `metrics.sh` (read-only report), `eval-run.sh` (the improvement cadence — proposer-only), `lessons-lint.sh` (cap + provenance, fail-closed), `ledger-append.sh`, `candidates-append.sh`, `promote-check.sh`, `doctor.sh`. **Safety-critical logic lives here as code.** |
| **agents** | `distiller` (read-only; returns a candidate) and `grader` (eval; fails loud without `skill-creator`). |
| **references** | The judge `rubric.md`, the capped `lessons.md` (the ONE injected memory), and `architecture.md` (deep design + **E2E walkthrough**). |
| **evals/calibration** | The **frozen yardstick** — seeded-bug `seeds/*.diff` the system measures against but never edits (CODEOWNERS + CI enforced). |
| **tests / CI** | `tests/run-tests.sh` (the auditor probes as a regression net) + `.github/workflows/{ci,promotion-gate}.yml`. |

### The two planes

- **Code plane (this repo):** skills, hooks, scripts, frozen calibration, seed lessons — versioned, shared.
- **Data plane (the target project):** at runtime the loop writes `.cc-local-loop/{ACTIVE, RUN_ID, frozen.json, ledger/events.jsonl, candidates.jsonl, evals/}` into *the project it works on* — kept out of the repo (run-loop excludes the directory's contents via `.git/info/exclude`). The one exception is `promoted.jsonl`, deliberately re-included so a lesson-promotion PR can carry its audit trail.

---

## The model roster (node-ai)

- **Implementer pool** (routed per task by capability): `ornith-35b` (agentic/refactor/tests) · `qwen3.6-35b` (algorithmic/frontend/reasoning) · `gemma-4-26b-a4b` (precision/spec, small scope + tiebreak).
- **Judge:** `gemma-4-31b-it` (raw API, thinking, persistent).
- **Cross-family gate invariant:** the family that implemented a change never gates it. Qwen-family output → Gemma-31B judges; Gemma-26B output → Qwen judge-mode; numeric / architecture / security / tiebreaks → **escalate to Opus**. Enforced in `common.sh` (`assert_cross_family`, `assert_impl_allowed`).

---

## The self-improvement feedback loop (safe, 4 stages)

```
COLLECT  → the harness emits validated events via `emit.sh` into ONE stream (ledger/events.jsonl); the Stop hook
           adds run_end. Observability-only, NEVER injected into a prompt (G1). Read it with `cc-local-loop:metrics`.
MEASURE  → `eval-run.sh` (cron/Routine) re-runs the FROZEN calibration set on a cadence → eval_delta events. PROPOSER only.
DISTILL  → `reflect` (offline, read-only distiller) turns outcome-evidence + eval_delta into candidate lessons → QUARANTINE
GATE     → `grader` measures candidates against the FROZEN calibration set (non-regression required)
PROMOTE  → `promote-lessons` opens a PR (whitelist- + lessons-lint-gated by promote-check.sh) → YOU merge it
```

The **skill gets sharper over time; the model does not change.** Telemetry is measured and *proposes*; a human *promotes*. Promotion is always a human-merged PR. The loop can never edit its own gates, thresholds, or the calibration yardstick — enforced by `lessons-lint.sh` (cap/provenance, fail-closed) + `promote-check.sh` + CODEOWNERS + the `promotion-gate` CI job.

> **Why human-gated (not auto):** the ETH Zurich AGENTBENCH study ([arXiv 2602.11988](https://arxiv.org/abs/2602.11988)) showed LLM-generated context files *reduce* resolution rates (~-3%) while inflating cost (+20%). `lessons.md` is capped and human-reviewed; only concise, non-obvious, tool-specific operational lessons are promoted.

---

## Install

```
/plugin marketplace add Jrecos/cc-local-loop
/plugin install cc-local-loop@cc-local-loop
```

Local development against this repo: `claude --plugin-dir /path/to/cc-local-loop`.

## Configure

```bash
export NODE_AI_URL=http://<your-node-ai-host>:8080     # defaults to http://127.0.0.1:8080
# loop:    CCLL_MAX_ITER (6) · CCLL_TIME_BUDGET_S (3600) · CCLL_CONTEXT_BUDGET (8000 tok) · CCLL_IMPL_ROSTER · CCLL_JUDGE_MODEL
# sandbox: CCLL_SANDBOX_RUNTIME (auto|docker|podman) · CCLL_SANDBOX_IMAGE · CCLL_SANDBOX_TIMEOUT (120)
# lessons: CCLL_LESSONS_MAX (15 bullets) · CCLL_LESSONS_TOK (2000) · CCLL_CAND_MAX (50 quarantined candidates)
```

`promote-lessons` reuses the **`skill-creator`** plugin as its eval harness — install it before promoting lessons.

## Verify

```bash
bash scripts/doctor.sh        # what's ENFORCED-in-code vs TODO
bash scripts/metrics.sh       # read-only loop telemetry report (once you have runs)
bash tests/run-tests.sh       # the 71-probe regression net (the auditors' probes)
```

---

## Preconditions (before the first unattended run)

The loop **refuses to start** until these pass (mirrors the homelab design doc §15.5; preflight fails on the unimplemented ones unless `CCLL_ALLOW_SCAFFOLD=1`):

1. Deploy the node-ai **Option-B** `llama-swap.yaml` (sequential `--parallel 1`; judge persistent; implementers swap).
2. Pull SDD artifacts (`specs/**`, `tasks.md`, constitution) into the anti-tamper protected set (`PROTECTED_PAT`).
3. Freeze the calibration yardstick **first** (seeded-bug set) before enabling any self-improvement.
4. Preflight gate: deployed-config-hash == Option-B ∧ smoke-test green ∧ stop-counter verified ∧ clean git tree.
5. Fail-closed judge: unparseable / 5xx / device-lost / truncated-context ⇒ REJECT (infra) + Magistral cold-standby.
6. Ornith reasoning-template preflight (`/props` + multi-turn smoke test; non-thinking template until the fix lands).
7. Gemma-26B tool-calling preflight (`--jinja` + explicit schemas; agentic smoke test before it enters rotation).
8. `skill-creator` plugin installed (the eval harness `promote-lessons` reuses).

---

## License

MIT © 2026 Jhonatan Reco ([Jrecos](https://github.com/Jrecos)). See [LICENSE](LICENSE).
