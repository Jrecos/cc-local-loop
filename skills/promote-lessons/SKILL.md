---
name: promote-lessons
description: >
  Promotes a quarantined cc-local-loop candidate lesson into the live lessons.md — ONLY by opening a PR that carries
  non-regression evidence against the frozen calibration set, for a human to merge. Use when the user says "promote
  a lesson", "review the quarantine", "approve/merge the lesson", "open the lesson PR". Human-started only; never
  auto-applies. Requires the skill-creator plugin (its eval harness). The loop must never edit its own yardstick.
disable-model-invocation: true
argument-hint: "[cand_id]"
---

# promote-lessons — human-gated promotion (PR only)

GATE + PROMOTE stage. A candidate becomes live ONLY through a PR a human merges, and only if it doesn't regress the
frozen calibration set. You draft the PR; you never merge it. **Requires the `skill-creator` plugin** (reused as the
eval harness); if it's absent, STOP and tell the user to install it.

## Steps

1. **Pick a candidate** from `.cc-local-loop/candidates.jsonl` (`status: quarantined`). Show its lesson, evidence,
   and the exact one-bullet patch it proposes to `references/lessons.md`.
2. **Gate against the FROZEN yardstick** — launch the `cc-local-loop:grader` agent (Task tool). It runs the
   skill-creator eval harness: baseline current `lessons.md` vs the candidate, **≥5 reps**, requiring non-regression
   on the full set **and** improvement on the candidate's RED case. Fail either ⇒ mark `rejected` + STOP.
3. **Enforce the cap** (~15 bullets / ~2K tokens). Over cap ⇒ the candidate must replace a stale/lower-value bullet;
   surface the trade to the user.
4. **Open a PR** (branch; never push to a protected branch, never auto-merge):
   - apply the one-bullet delta to `references/lessons.md` with provenance (`cand_id`, source runs); attach
     `benchmark.json`; record in `.cc-local-loop/promoted.jsonl`;
   - **run exactly this before opening the PR** (the whitelist gate — aborts if the diff strays into the yardstick):
     `"${CLAUDE_PLUGIN_ROOT}/scripts/promote-check.sh" <branch>`
5. Tell the user the PR is open and **awaits their merge**.

## Never

- Never edit `evals/calibration/**`, `scripts/harness/**`, gate thresholds, or protected globs. Expanding the
  calibration set is a **separate** human PR, never bundled with a promotion. Never promote without a passing
  benchmark. Never auto-merge. Human-authored / pinned lessons are never auto-pruned.
