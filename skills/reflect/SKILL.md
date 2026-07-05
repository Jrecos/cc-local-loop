---
name: reflect
description: >
  Distills the cc-local-loop execution ledger into quarantined candidate lessons (never auto-applied). Use at
  feature-end, after a loop run with escalations/repeated failures, or when the user says "reflect on the loop",
  "qué aprendimos del loop", "distill lessons", "analyze the ledger", "postmortem del loop". Reads telemetry only;
  writes candidates to quarantine with provenance. No-ops safely when the ledger is empty. Never changes a live
  skill, rubric, or the calibration yardstick.
---

# reflect — turn execution feedback into candidate lessons (quarantine only)

DISTILL stage. Everything it writes lands in **quarantine**; it never touches a live skill, rubric, gate, or the
calibration set. Promotion is separate + human-gated (`cc-local-loop:promote-lessons`).

## Steps

0. **Guard.** If `${CLAUDE_PROJECT_DIR}/.cc-local-loop/ledger/runs.jsonl` is missing or has no structured rows since
   the last reflect, report "nothing to distill" and STOP — do not spend a subagent.
1. **Read the ledger** (telemetry — never injected anywhere else). Structured per-task rows carry
   `{run_id, ts, git_sha, task_id, outcome, gate_results, judge, retries, escalation}` (written by run-loop step 7;
   the Stop hook writes session stubs only). If the required fields are absent, **refuse** — do not mine stubs for
   "patterns."
2. **Find outcome-evidence patterns** (not vibes): same failing-gate signature across **≥3** tasks · an
   **escalation-then-pass** · **≥3 ADJUST rounds** on one task.
3. **Launch the `cc-local-loop:distiller` agent** (Task tool, isolated context). It RETURNS one additive delta
   bullet (never a rewrite). Priority: patch > amend > add-reference > new > skip.
4. **Append to quarantine** via `"${CLAUDE_PLUGIN_ROOT}/scripts/candidates-append.sh"` — one object:
   `{cand_id, ts, source_runs[], category, lesson, proposed_patch, evidence, created_by:"agent", status:"quarantined"}`.

## Hard rules

- **Telemetry ≠ memory.** Never inject ledger rows into a prompt or into `lessons.md`.
- One finding at a time, at feature-end. Local models never author lessons — the distiller runs on Opus.
- Operational, non-obvious, tool-specific imperatives only (architectural narration *hurts* — ETH Zurich).
- End by reporting how many candidates were quarantined and that **`cc-local-loop:promote-lessons` (human-gated)** is
  required to make any of them live.
