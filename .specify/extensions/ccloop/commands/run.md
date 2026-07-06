---
description: "Launch the local-model implement loop over tasks.md (fire-and-forget workflow)."
---

# ccloop · run

You are launching the ccloop implement loop. Do this deterministically:

1. **Validate prerequisites.** Confirm a feature with `tasks.md` exists:
   `bash .specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks`
   If it fails, tell the user to run `/speckit.tasks` first and STOP.

2. **Self-register the workflow if absent** (idempotent):
   ```bash
   specify workflow list | grep -q 'ccloop' \
     || specify workflow add "$(pwd)/.specify/extensions/ccloop/workflow/workflow.yml"
   ```

3. **Launch the loop, fire-and-forget**, in the user's terminal:
   ```bash
   specify workflow run ccloop
   ```
   Then EXIT — do not babysit the loop (Opus only thinks/reviews). The workflow
   pauses at the human done-gate; the user resumes with `specify workflow resume <run_id>`
   to sign off. Report the launch and stop.

Note: live model dispatch is `die`-guarded until the node-ai serving topology is deployed —
the workflow will arm, freeze, and derive the contract, then halt at the guarded dispatch
step. Nothing fakes green.
