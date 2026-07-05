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

> **Scaffold status (v0.2):** `dispatch.sh`/`judge.sh` refuse to run until node-ai Option-B is deployed (§15.5), and
> `gate.sh` fails until its test runner is wired. Treat any "green" you can't trace to a script as unproven — this
> skill describes the intended loop; the *enforced* parts are exactly what the scripts do today.

## 0. Preflight + arm the loop

Run preflight FIRST; if it exits non-zero, STOP and report — dispatch nothing.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"                                  # refuses unless the cage is verified (§15.5)
mkdir -p "${CLAUDE_PROJECT_DIR}/.cc-local-loop" && : > "${CLAUDE_PROJECT_DIR}/.cc-local-loop/ACTIVE"
EX="$(git -C "${CLAUDE_PROJECT_DIR}" rev-parse --git-path info/exclude)"       # worktree-safe (.git may be a file)
grep -qxF '.cc-local-loop/' "$EX" 2>/dev/null || echo '.cc-local-loop/' >> "$EX"   # keep runtime state out of the repo
```

The `ACTIVE` marker is what lets `dispatch.sh` / `judge.sh` / the Stop hook run — without it they refuse. This is the
mechanical human-gate: side-effectful steps only run inside a loop you started.

## 1. Per-task loop (one task at a time; respect `[P]` markers + phase order)

1. **route** — pick `impl_model` from the pool by capability (table §3); derive the judge by the cross-family
   invariant. Numeric / architecture / security / tiebreak-disagreement → **escalate to Opus** (don't force a local).
2. **freeze** (once/feature) — `harness/freeze.sh` hash-pins the protected spine (tests, specs, lockfiles, CI, SDD).
3. **implement** — dispatch per `cc-local-loop:dispatch`. The dispatch payload **always includes**
   `${CLAUDE_PLUGIN_ROOT}/references/lessons.md` (the ONE injected memory) plus the task file.
3b. **commit** — the implementer has no git, so the harness commits its work so the gate/judge can see it:
   `git -C "${CLAUDE_PROJECT_DIR}" add -A && git -C "${CLAUDE_PROJECT_DIR}" commit -m "wip(<task-id>)"`. Without this
   the `<base>..HEAD` diff is empty and the judge returns `NO_CHANGE_NEEDED`.
4. **gate** — `harness/gate.sh <base>` (scope → hash-verify → runner). Model-free; on fail → step 6.
5. **judge** — `cc-local-loop:judge <impl_model> <judge_model> <base>`. **DONE = gate green AND judge APPROVE with
   no Critical/High violations.**
6. **guards** — on fail, `harness/guards.sh <task-id>` → CONTINUE (re-dispatch the SAME model + full ADJUST payload,
   §7 contract) or ESCALATE to Opus.
7. **ledger** — after each task reaches DONE/ESCALATE, append a **structured** row (task_id, gate result, judge
   verdict, retries, escalation, wall-time) so `reflect` can mine it — the Stop hook records session stubs only.

## 2. Stop rules

Enforced by `guards.sh` today: **per-task MAX_ITER = 6** and the **TIME budget** (primary trigger for unattended
runs). TODO (T2): no-progress (k=2), oscillation (last 4), token budget, gate-hash tripwire, crash detection.

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
