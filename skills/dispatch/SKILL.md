---
name: dispatch
description: >
  Dispatches a local-model executor agent for cc-local-loop by launching a FRESH `opencode run` per task so the
  model runs inside OpenCode's permission-hardened harness. Use when the run-loop needs to implement a task on a
  local model (Ornith / Qwen / Gemma-26B on node-ai), when dispatching an executor, or when deciding how to bind a
  model per task. Covers the no-`--attach` rule, per-task scope injection, and the cross-family family-map assert.
---

# dispatch — launch a local executor inside OpenCode's harness

The implementer runs **inside OpenCode** (its per-agent permission engine, tools, session) — not a raw `claude -p`.
Always dispatch through the script so the family-map assert and scope injection are enforced:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" <impl_model> <task-id>
# e.g. dispatch.sh ornith-35b T012
```

## The mechanism (what the script does)

1. **Fresh process, NO `--attach`.** It runs `opencode run --agent implementer --model node-ai/<impl_model>
   --auto --format json -f task.md "…"`. A fresh in-process server per dispatch is the ONLY path where per-task
   `OPENCODE_PERMISSION` is actually enforced — with `--attach`/`serve` the scope silently crosses no HTTP boundary
   and **fails OPEN**. `--attach` is for interactive sessions only.
2. **Per-task scope injection.** It sets `OPENCODE_PERMISSION` to a deny-by-default map + the task's in-scope
   allow-list + the protected globs (tests/specs/CI/lockfiles) re-emitted last. The `implementer` agent's own
   config carries the same denies (defense in depth; `deny` survives `--auto`).
3. **Family-map assert (fail-closed).** Before dispatch it checks `family(impl) ≠ family(judge)` so a later judge
   cannot be same-family. Unknown/missing mapping ⇒ ABORT.
4. **`OPENCODE_DISABLE_CLAUDE_CODE=1`** so the local doer does not ingest Opus-targeted `CLAUDE.md`.

## Rules

- The authoritative result is the `git diff`, not the event stream. Read `--format json` only to detect crashes.
- The implementer has **no shell and no git** — the harness runs every command.
- Fallback lane (tested weekly canary, not primary): `claude -p` + `ANTHROPIC_BASE_URL`→node-ai with
  `CLAUDE_CODE_ATTRIBUTION_HEADER=0`. Degraded on reasoning models (drops thinking blocks). Only route mechanical
  tasks there. See `${CLAUDE_PLUGIN_ROOT}/references/architecture.md`.

> Note: requires the node-ai Option-B topology deployed and OpenCode configured with a `node-ai` provider. The
> script is `TODO(preflight)` until those pass — it refuses to run otherwise.
