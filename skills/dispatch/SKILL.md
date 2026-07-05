---
name: dispatch
description: >
  Launches the local-model executor for ONE cc-local-loop task inside OpenCode's permission-hardened harness. Use
  ONLY during an active run-loop session — at the loop's implement step, when re-dispatching an ADJUST payload, or
  after an executor crash. Not an entry point: if no loop is active and the user wants to implement something, route
  them to /cc-local-loop:run-loop. Always dispatched via scripts/dispatch.sh, never a hand-written command.
---

# dispatch — launch a local executor inside OpenCode's harness

Runs only inside an active loop (`dispatch.sh` refuses without the `.cc-local-loop/ACTIVE` marker). The implementer
runs **inside OpenCode** (its per-agent permission engine, tools, session) — not a raw `claude -p`. Always go
through the script so the roster check, cross-family assert, and scope injection are enforced:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" <impl_model> <task-id>   # e.g. dispatch.sh ornith-35b T012
```

## Load-bearing properties (the script owns the exact command — do not hand-roll it)

- **Fresh process, never `--attach`.** A fresh in-process server per dispatch is the ONLY path where per-task
  `OPENCODE_PERMISSION` is enforced — with `--attach`/`serve` the scope fails OPEN across the HTTP boundary.
- **Scope injection.** `OPENCODE_PERMISSION` = deny-by-default + the task's in-scope allows + protected globs, built
  with `jq` (always valid JSON) and assigned **unconditionally** (never inherited from the environment).
- **Roster + cross-family assert (fail-closed).** Refuses Opus/non-roster implementers; asserts
  `family(impl) ≠ family(judge)`; unknown model ⇒ ABORT.
- **`OPENCODE_DISABLE_CLAUDE_CODE=1`** so the local doer doesn't ingest Opus-targeted `CLAUDE.md`.
- The implementer has **no shell, no git** — the harness runs every command; the authoritative result is `git diff`.
- Fallback lane only (weekly canary, mechanical tasks): `claude -p` + `ANTHROPIC_BASE_URL`→node-ai with
  `CLAUDE_CODE_ATTRIBUTION_HEADER=0`. See `references/architecture.md`.

> **Scaffold (v0.2):** `dispatch.sh` refuses to run (`die`) until node-ai Option-B + an OpenCode `node-ai` provider
> are configured (§15.5). The roster/cross-family/scope checks already run before that guard.
