# ccloop — quickstart

## Install

```bash
specify extension add ccloop --from https://github.com/Jrecos/cc-local-loop
```

The extension installs to `.specify/extensions/ccloop/` and ships its own workflow, which `run` self-registers on first use.

## Use

In a project that already has a feature with `tasks.md` (i.e. after `/speckit.specify` → `/speckit.plan` → `/speckit.tasks`):

```
/speckit.ccloop.run
```

This registers (idempotently) and launches the `ccloop` workflow:

```
arm → freeze → derive-contract → do-while{ status → dispatch → judge → gate → record } → assert_closed → human done-gate → signoff → reflect
```

- `tasks.md` is read-only (frozen); run-state lives in `specs/<feature>/ccloop/` (`contract.md`, `progress.md`, `debt.md`, ...).
- The workflow **pauses** at the human done-gate. Sign off with:
  ```bash
  specify workflow resume <run_id>
  ```

## Other commands

- `/speckit.ccloop.status` — read-only snapshot + one recommended next action.
- `/speckit.ccloop.doctor` — the ENFORCED / PARTIAL / TODO matrix for this install.
- `/speckit.ccloop.reflect` — offline; quarantines candidate lessons (never edits `lessons.md`).
- `/speckit.ccloop.promote` — human-only; gated PR to add ONE lesson to `references/lessons.md`.

## Current status (v0.5.0)

Installable, workflow-validating, all safety gates enforced in bash and probe-tested. **Live model dispatch is `die`-guarded** until the node-ai serving topology is deployed — the loop arms, freezes, and derives the contract, then halts at the guarded dispatch step. Nothing fakes green. Run `/speckit.ccloop.doctor` for the live matrix.
