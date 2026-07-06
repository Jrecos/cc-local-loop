---
description: "Read-only budgeted snapshot of the loop + one recommended next action."
---

# ccloop · status

Read-only. Run `bash .specify/extensions/ccloop/scripts/bash/progress-status.sh --json` and (if a run exists) `specify workflow status ccloop`. Render the counts (open / passed / uncertain / total), then recommend exactly ONE next action by these deterministic rules:

- any `open` tasks and a paused run → `specify workflow resume <run_id>`
- all tasks `judge-pass` but not yet signed → the human done-gate (resume to approve)
- nothing `open` and signed → done
- no run yet → `/speckit.ccloop.run`

Do NOT modify any file.
