---
name: run-loop
description: >
  Runs the cc-local-loop autonomous dev loop on ONE task: Opus routes, a local model implements via OpenCode,
  the harness gates, the Gemma judge validates, and it adjusts until a deterministic Definition of Done is met.
  Use when the user says "run the loop", "start the autonomous loop", "implement this task with the local models",
  "kick off cc-local-loop", or points at a tasks.md and wants it worked autonomously on node-ai. Human-started only.
disable-model-invocation: true
model: opus
---

# run-loop — the orchestrator (state machine)

You are the **loop controller**. You never write implementation code yourself. You route each task to a local
model, run deterministic gates, invoke the judge, and decide continue / escalate / done. All safety-critical logic
is in scripts under `${CLAUDE_PLUGIN_ROOT}/scripts/` — call them; do not reimplement them in prose.

## 0. Refuse to start unless preconditions pass

Run the preflight FIRST. If it exits non-zero, STOP and report — do not dispatch anything.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"    # node-ai health, config hash, stop-counter, clean git tree
```

## 1. Per-task loop

For each task (respect `[P]` parallel markers and phase order; **one task at a time**):

1. **route** — classify the task and pick `impl_model` from the pool by capability (see the rubric below); derive
   the judge by the **cross-family invariant** (never same-family). If the class is numeric / architecture /
   security / a tiebreak disagreement → **escalate to Opus** (you implement or judge directly), do not force a local.
2. **freeze** (once per feature) — `"${CLAUDE_PLUGIN_ROOT}/scripts/harness/freeze.sh"` hash-pins tests, lockfiles,
   coverage config, CI, and the SDD artifacts (`specs/**`, `tasks.md`, constitution). This is the anti-tamper spine.
3. **implement** — dispatch a FRESH `opencode run` per the `dispatch` skill (see `cc-local-loop:dispatch`). The
   implementer runs inside OpenCode's permission-hardened harness on the local model.
4. **gate** — `"${CLAUDE_PLUGIN_ROOT}/scripts/harness/gate.sh" <base>` runs scope-check → hash-verify → lint/type/
   build → frozen tests → diff-coverage. Deterministic, model-free. On fail → step 6.
5. **judge** — invoke `cc-local-loop:judge`. The Gemma judge (cross-family) returns a verdict + adversarial tests;
   the harness runs those tests. **DONE = gates green AND judge approves with no Critical/High violations.**
6. **adjust / guards** — on any fail, `"${CLAUDE_PLUGIN_ROOT}/scripts/harness/guards.sh"` decides CONTINUE (re-dispatch
   the SAME `impl_model` with the full ADJUST payload) or ESCALATE. Escalate to Opus when guards trip.

## 2. Stop rules (owned by the harness, never the model)

`guards.sh` escalates on: inner `MAX_ITER = 6` · no-progress (failing-gate signature unchanged for k=2) ·
oscillation (repeat in last 4 signatures) · **TIME budget exceeded (primary trigger for unattended runs)** ·
token/cost budget · gate-file hash mismatch (reward-hack tripwire) · OpenCode process crash.

## 3. Routing rubric (entry rung only; the judge is always cross-family)

| Task class | impl | judge |
|---|---|---|
| Terminal/CLI agentic, refactor, tests, repo bugs | **Ornith** | Gemma-31B |
| Algorithmic / from-scratch / frontend / reasoning | **Qwen** | Gemma-31B |
| Precision / spec-structure / small-scope (NON-numeric) | **Gemma-26B** | Qwen judge-mode |
| Numeric / architecture / security / tiebreak-disagreement | **Opus** | Opus |

Full rubric + escalation ladders: `${CLAUDE_PLUGIN_ROOT}/references/architecture.md`.

## 4. After the feature — collect feedback

The `Stop` hook already appended each run to the ledger. At feature-end, offer to run `cc-local-loop:reflect`
to distill candidate lessons (quarantined; never auto-applied). Promotion is a separate human-gated step
(`cc-local-loop:promote-lessons`).

## Contract you must honor

- The authoritative change set is `git diff <base>..HEAD`, not any model's summary.
- A model asserting "done" is **not** evidence. Only gates + judge decide.
- Never edit the harness, the gates, the protected globs, or the calibration set from inside the loop.
