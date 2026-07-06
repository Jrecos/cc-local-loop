# ccloop — cc-local-loop as a spec-kit extension

Opus orchestrates → local models implement (pluggable agent-CLI adapter) → a cross-family judge gates → human signs off. The loop is a spec-kit workflow; every safety gate is bash that fails closed. `tasks.md` is the frozen work queue; run-state lives in `specs/<feature>/ccloop/`.

## Install

    specify extension add ccloop --from https://github.com/Jrecos/cc-local-loop

Then, in a feature with `tasks.md`:

    /speckit.ccloop.run

The `run` command self-registers the bundled workflow (idempotently) and launches it fire-and-forget. The workflow pauses at a human done-gate; sign off with `specify workflow resume <run_id>`.

## Safety

Guardrails G1–G9 are enforced in `scripts/bash/` (never in prose) and probed by the repo's regression net. `tasks.md` is never written by the loop (G9); only `references/lessons.md` is ever injected (G1); the implementer's model family never judges its own change (cross-family). Live model dispatch is `die`-guarded until the node-ai serving topology is deployed — nothing fakes green.
