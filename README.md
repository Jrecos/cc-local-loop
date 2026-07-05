# cc-local-loop

**An Opus-orchestrated autonomous dev loop that executes on local models.** Claude Code (Opus 4.8) is the entry point: it plans (spec-driven), dispatches executor agents that run **inside OpenCode's harness** on your **local models** (node-ai), and a **cross-family Gemma judge** gates every change. Opus reviews. You pay your Opus subscription only to *think and review*; the heavy volume runs **free** on your hardware.

> **Invariant:** `Opus 4.8 → local models → Opus 4.8`. The loop converges on a deterministic **Definition of Done** enforced in code, never by a model's opinion.

This plugin is the packaged form of the design in [`homelab/docs/ai-dev-orchestration-workflow.md`](https://github.com/Jrecos) (v11). It is **the combination of interconnected skills** that no single existing tool provided — bundled as one Claude Code plugin so it is versioned, namespaced, and improves over time via PRs.

---

## Status: v0.1.0 — scaffold

The **structure, skills, hooks, and contracts are in place**. The executable loop depends on the node-ai **"Option-B" serving topology** being deployed first (see *Preconditions* below). Scripts that call node-ai / OpenCode are marked `TODO(preflight)` and fail loud until their preconditions pass — by design (a loop that verifies its cage before entering it).

---

## What's inside (one plugin, several single-responsibility skills)

| Component | What it does |
|---|---|
| **skill `run-loop`** | The orchestrator / state machine Opus follows: `route → freeze → implement → gate → judge → adjust → done`, with stop rules. Human-invoked (`/cc-local-loop:run-loop`). |
| **skill `dispatch`** | How Opus dispatches a **fresh `opencode run` per task** (no `--attach`) so the local implementer runs inside OpenCode's permission-hardened harness. |
| **skill `judge`** | How the **Gemma-31B judge** runs as a raw two-pass API call (no tools); the harness executes the adversarial tests it emits. Cross-family per the invariant. |
| **skill `reflect`** | Distills the execution **ledger** into **quarantined candidate lessons** (offline, never auto-applied). |
| **skill `promote-lessons`** | **Human-gated** promotion: opens a PR moving a candidate into `lessons.md`, carrying non-regression evidence against the frozen calibration set. `disable-model-invocation` — only a human starts it. |
| **hook `Stop`** | Deterministically appends each run's outcome to the ledger. Fail-safe (errors never block the loop). |
| **scripts** | The deterministic muscle: `harness/{freeze,gate,guards}.sh`, `dispatch.sh`, `judge.sh`, `preflight.sh`, `ledger-append.sh`. **Safety-critical logic lives here as code, not in skill prose.** |
| **agents** | `distiller` (reflect) and `grader` (eval) subagents, run in isolated contexts. |
| **references** | The judge `rubric.md`, the capped `lessons.md` (the ONE injected memory), and `architecture.md`. |
| **evals/calibration** | The **frozen yardstick** — seeded-bug cases the system measures against but never edits. |

### The two planes

- **Code plane (this repo):** skills, hooks, scripts, frozen calibration, seed lessons — versioned, shared.
- **Data plane (the target project):** at runtime the loop writes `.cc-local-loop/ledger/runs.jsonl` and `.cc-local-loop/candidates.jsonl` into *the project it is working on* — never committed here (see `.gitignore`).

---

## The model roster (node-ai)

- **Implementer pool** (routed per task by capability): `ornith-35b` (agentic/refactor/tests) · `qwen3.6-35b` (algorithmic/frontend/reasoning) · `gemma-4-26b-a4b` (precision/spec, small scope + tiebreak).
- **Judge:** `gemma-4-31b-it` (raw API, thinking, persistent).
- **Cross-family gate invariant:** the family that implemented a change never gates it. Qwen-family output → Gemma-31B judges; Gemma-26B output → Qwen judge-mode; numeric / architecture / security / tiebreaks → **escalate to Opus**.

---

## The self-improvement feedback loop (safe, 4 stages)

```
COLLECT  → hook appends every run to the ledger (raw telemetry, NEVER injected into a prompt)
DISTILL  → `reflect` (offline subagent) turns outcome-evidence into candidate lessons → QUARANTINE
GATE     → measure candidates against the FROZEN calibration set (non-regression required)
PROMOTE  → `promote-lessons` opens a PR with evidence → YOU merge it
```

The **skill gets sharper over time; the model does not change.** Promotion is always a human-merged PR. The loop never edits its own gates, thresholds, or the calibration yardstick.

> **Why human-gated (not auto):** the ETH Zurich AGENTBENCH study ([arXiv 2602.11988](https://arxiv.org/abs/2602.11988)) showed LLM-generated context files *reduce* resolution rates (~-3%) while inflating cost (+20%). Unbounded self-editing is net-negative. `lessons.md` is capped and human-reviewed; only concise, non-obvious, tool-specific operational lessons are promoted.

---

## Install

```
/plugin marketplace add Jrecos/cc-local-loop
/plugin install cc-local-loop@cc-local-loop
```

Or, for local development against this repo:

```
claude --plugin-dir /path/to/cc-local-loop
```

---

## Preconditions (before the first unattended run)

The loop **refuses to start** until these pass (7 keys — mirrors the homelab design doc §15.5):

1. Deploy the node-ai **Option-B** `llama-swap.yaml` (sequential `--parallel 1`; judge persistent; implementers swap).
2. Pull SDD artifacts (`specs/**`, `tasks.md`, constitution) into the anti-tamper protected set.
3. Freeze the calibration yardstick **first** (seeded-bug set) before enabling any self-improvement.
4. Preflight gate: deployed-config-hash == Option-B ∧ smoke-test green ∧ stop-counter verified ∧ clean git tree.
5. Fail-closed judge: unparseable / 5xx / device-lost / truncated-context ⇒ REJECT (infra) + Magistral cold-standby.
6. Ornith reasoning-template preflight (`/props` + multi-turn smoke test; non-thinking template until the fix lands).
7. Gemma-26B tool-calling preflight (`--jinja` + explicit schemas; agentic smoke test before it enters rotation).

---

## License

MIT © 2026 Jhonatan Reco ([Jrecos](https://github.com/Jrecos)). See [LICENSE](LICENSE).
