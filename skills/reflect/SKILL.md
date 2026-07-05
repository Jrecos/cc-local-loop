---
name: reflect
description: >
  Distills the cc-local-loop execution ledger into quarantined candidate lessons (never auto-applied). Use at
  feature-end, after a run with escalations or repeated failures, or when the user says "reflect", "what did we
  learn", "distill lessons", "review the loop's runs", or "improve the loop". Reads telemetry only; writes
  candidates to quarantine with provenance. Does NOT change any live skill, rubric, or the calibration set.
---

# reflect — turn execution feedback into candidate lessons (quarantine only)

This is the DISTILL stage of the feedback loop. It reads the raw ledger and proposes improvements — but everything
it writes lands in **quarantine**. It never touches a live skill, rubric, gate, or the calibration set. Promotion
is a separate, human-gated step (`cc-local-loop:promote-lessons`).

## Steps

1. **Read the ledger** (telemetry, never injected elsewhere): the target project's
   `.cc-local-loop/ledger/runs.jsonl`. Each row: `{run_id, ts, git_sha, task_id, outcome, gate_results, judge,
   retries, escalation, tokens, duration_s}`.
2. **Find outcome-evidence patterns** (not vibes) — only these qualify:
   - the same failing-gate signature across **≥3** tasks,
   - an **escalation-then-pass** (Opus rescued what a local couldn't), or
   - **≥3 ADJUST rounds** on one task.
3. **Dispatch the `distiller` subagent** (`${CLAUDE_PLUGIN_ROOT}/agents/distiller.md`) in an isolated context. It
   applies a strict priority: *patch an existing lesson > amend > add a reference > propose a new lesson > skip if
   one-off*. Output is an **additive delta bullet with an ID**, never a rewrite (rewrites cause context collapse).
4. **Append to quarantine:** `.cc-local-loop/candidates.jsonl`, one object each:
   `{cand_id, ts, source_runs[], category, lesson, proposed_patch, evidence, created_by:"agent", status:"quarantined"}`.
   Stamp provenance on every line.

## Hard rules

- **Telemetry ≠ memory.** Never inject ledger rows into a prompt or into `lessons.md`.
- **One finding at a time**, at feature-end. Local 35B models never author lessons — the distiller runs on Opus.
- Produce **operational, non-obvious, tool-specific** imperatives only. Architectural narration is exactly what the
  ETH Zurich study showed *hurts*; do not promote it.
- This skill ends by telling the user how many candidates were quarantined and that
  **`cc-local-loop:promote-lessons` is required (human-gated)** to make any of them live.
