---
name: using-cc-local-loop
description: >
  Explains and routes cc-local-loop: which skill to use, how the loop works, and the current loop/ledger status. Use
  when the user asks how cc-local-loop works, what state the loop or its lessons/candidates are in, how to set it up
  or resume it, or uses loop vocabulary (node-ai, OpenCode executor, cross-family judge, ledger, quarantine,
  "el loop local") outside an active run. Routes starting work to /cc-local-loop:run-loop — it never dispatches or
  judges by itself.
---

# using-cc-local-loop — orientation & router

cc-local-loop makes Opus orchestrate an autonomous dev loop that executes on LOCAL models (node-ai via OpenCode),
with a cross-family judge and a human-gated self-improvement loop. Use this skill to **route** — never to dispatch
or judge.

## Which skill

| The user wants… | Use |
|---|---|
| start / resume the loop on a task | **`/cc-local-loop:run-loop`** (human-started) |
| understand how dispatch / the judge work | read `cc-local-loop:dispatch` / `cc-local-loop:judge` (knowledge only) |
| distill lessons from past runs | `cc-local-loop:reflect` (→ quarantine) |
| promote a lesson (open a PR) | **`/cc-local-loop:promote-lessons`** (human-started) |
| the deep design + E2E walkthrough | `${CLAUDE_PLUGIN_ROOT}/references/architecture.md` |

## Status (read-only)

- Guarantee matrix (what's enforced-in-code vs TODO): `bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"`.
- Loop state (in the target project): `.cc-local-loop/{ACTIVE, frozen.json, ledger/runs.jsonl, candidates.jsonl}`.

## Do not

Do not run `dispatch.sh`/`judge.sh` yourself, and do not implement code — those only happen inside a `run-loop` the
user started (they refuse without the `.cc-local-loop/ACTIVE` marker). If the user wants to implement something,
point them at `/cc-local-loop:run-loop`.
