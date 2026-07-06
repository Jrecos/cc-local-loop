---
name: run-loop
description: >
  Runs (or resumes) the cc-local-loop autonomous dev loop on ONE task from tasks.md: a local model implements on
  node-ai, deterministic gates and a cross-family judge decide DONE. Use when the user says "run the loop",
  "start/resume the autonomous loop", "kick off cc-local-loop", "corre el loop", "sigue con el loop", or points at a
  tasks.md to work autonomously. Human-started only.
disable-model-invocation: true
model: opus
argument-hint: "[tasks.md path | task-id]"
---

# run-loop — the orchestrator (state machine)

You are the **loop controller**. You never write implementation code yourself. All safety-critical logic is in
scripts under `${CLAUDE_PLUGIN_ROOT}/scripts/` — call them; never reimplement them in prose.

> **Scaffold status (v0.3):** `dispatch.sh`/`judge.sh` refuse to run until node-ai Option-B is deployed (§15.5), and
> `gate.sh` fails until its test runner is wired. Treat any "green" you can't trace to a script as unproven — this
> skill describes the intended loop; the *enforced* parts are exactly what the scripts do today.

## 0. Preflight + arm the loop

Run preflight FIRST; if it exits non-zero, STOP and report — dispatch nothing.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"                                  # refuses unless the cage is verified (§15.5)
mkdir -p "${CLAUDE_PROJECT_DIR}/.cc-local-loop" && : > "${CLAUDE_PROJECT_DIR}/.cc-local-loop/ACTIVE"
EX="$(git -C "${CLAUDE_PROJECT_DIR}" rev-parse --git-path info/exclude)"       # worktree-safe (.git may be a file)
grep -qxF '.cc-local-loop/' "$EX" 2>/dev/null || echo '.cc-local-loop/' >> "$EX"   # keep runtime state out of the repo
"${CLAUDE_PLUGIN_ROOT}/scripts/state.sh" arming 0 "$(git -C "${CLAUDE_PROJECT_DIR}" rev-parse --short HEAD)" ""  # STATUS.md + loop_state.json
```

The `ACTIVE` marker is what lets `dispatch.sh` / `judge.sh` / the Stop hook run — without it they refuse. This is the
mechanical human-gate: side-effectful steps only run inside a loop you started.

## 1. Per-task loop (one task at a time; respect `[P]` markers + phase order)

1. **route** — pick `impl_model` from the pool by capability (table §3); derive the judge by the cross-family
   invariant. Numeric / architecture / security / tiebreak-disagreement → **escalate to Opus** (don't force a local).
2. **freeze** (once/feature) — `harness/freeze.sh` hash-pins the protected spine (tests, specs, lockfiles, CI, SDD).
2b. **check the check** (once/feature) — `"${CLAUDE_PLUGIN_ROOT}/scripts/check-idempotency.sh" <base>` runs the gate
   3× on one state and aborts if the output isn't identical. A flaky check breaks the stop condition — fix it first.
3. **implement** — build a NARROW context first:
   `"${CLAUDE_PLUGIN_ROOT}/scripts/build-context.sh" <task-id> "<failing-gate output>"` → {state + the one open
   failure + only its stack-trace / last-diff files, capped by a token budget}. Then dispatch per
   `cc-local-loop:dispatch`; the payload = that context + `references/lessons.md` (the ONE injected memory) + the task.
3b. **commit** — the implementer has no git, so the harness commits its work so the gate/judge can see it:
   `git -C "${CLAUDE_PROJECT_DIR}" add -A && git -C "${CLAUDE_PROJECT_DIR}" commit -m "wip(<task-id>)"`. Without this
   the `<base>..HEAD` diff is empty and the judge returns `NO_CHANGE_NEEDED`.
4. **gate** — `harness/gate.sh <base>` (scope → hash-verify → runner). Model-free; on fail → step 6.
5. **judge** — `cc-local-loop:judge <impl_model> <judge_model> <base>`. **DONE = gate green AND judge APPROVE with
   no Critical/High violations.**
6. **guards** — on fail, `harness/guards.sh <task-id> "<the gate's sorted failing[] JSON>"` → CONTINUE (re-dispatch
   the SAME model with a freshly built narrow context) or ESCALATE. Passing the failing signature arms the
   no-progress + oscillation circuit breakers; guards also writes a liveness heartbeat each iteration.
7. **ledger + state** — after each task reaches DONE/ESCALATE, append a **structured** row (task_id, gate result,
   judge verdict, retries, escalation, wall-time) via `ledger-append.sh` and refresh `state.sh` — so `reflect` can
   mine the ledger and you can read `STATUS.md` at a glance. The Stop hook records session stubs only.

## 2. Stop rules

Enforced by `guards.sh`: **per-task MAX_ITER = 6**, the **TIME budget** (primary for unattended runs), **no-progress**
(identical failing signature ×2), **oscillation** (a signature repeating within the last 4), and a **liveness
heartbeat** (silent-death detector). Still TODO: token budget, gate-hash tripwire, crash detection.

## 3. Routing table (entry rung only; the judge is always cross-family)

| Task class | impl | judge |
|---|---|---|
| Terminal/CLI agentic, refactor, tests, repo bugs | **Ornith** | Gemma-31B |
| Algorithmic / from-scratch / frontend / reasoning | **Qwen** | Gemma-31B |
| Precision / spec-structure / small-scope (NON-numeric) | **Gemma-26B** | Qwen judge-mode |
| Numeric / architecture / security / tiebreak-disagreement | **Opus** | Opus |

Full rubric + escalation ladders: `${CLAUDE_PLUGIN_ROOT}/references/architecture.md`.

## 4. Feature end

Disarm the loop: `rm -f "${CLAUDE_PROJECT_DIR}/.cc-local-loop/ACTIVE"`. Then offer `cc-local-loop:reflect` (distill
candidate lessons → quarantine; never auto-applied). Promotion is separate + human-gated
(`cc-local-loop:promote-lessons`).

## Contract

- Authoritative change set = `git diff <base>..HEAD` (populated by the step-3b harness commit), not any model's
  summary. A model asserting "done" is not evidence.
- Never edit the harness, gates, protected globs, or the calibration set from inside the loop.
