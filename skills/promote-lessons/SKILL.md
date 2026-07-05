---
name: promote-lessons
description: >
  Promotes a quarantined cc-local-loop candidate lesson into the live lessons.md — but ONLY by opening a PR that
  carries non-regression evidence against the frozen calibration set, for a human to merge. Use when the user says
  "promote a lesson", "apply the candidates", "review candidates for promotion", or "update the loop's lessons".
  Human-started only; never auto-applies. The loop must never edit its own yardstick.
disable-model-invocation: true
---

# promote-lessons — human-gated promotion (PR only)

This is the GATE + PROMOTE stage. A candidate becomes live ONLY through a pull request that a human merges, and
ONLY if it does not regress the frozen calibration set. You draft the PR; you never merge it.

## Steps

1. **Pick a candidate** from `.cc-local-loop/candidates.jsonl` (status `quarantined`). Show the user its lesson,
   evidence, and the exact one-bullet patch it proposes to `references/lessons.md`.
2. **Gate it against the FROZEN yardstick.** Run the `grader` subagent (`${CLAUDE_PLUGIN_ROOT}/agents/grader.md`)
   via the eval harness (reuse the installed `skill-creator` harness — do not reimplement it):
   - baseline the current `lessons.md` @ HEAD, then the candidate, **same run, ≥5 reps**;
   - require **non-regression on the full calibration set** (delta ≥ 0 within stddev) **and** improvement on the
     specific seeded/observed failure that motivated the candidate (its RED case).
   - If it fails either, mark the candidate `rejected` (with the benchmark) and STOP.
3. **Enforce the cap.** `references/lessons.md` is capped (~15 bullets / ~2K tokens). If promoting would exceed it,
   the candidate must replace a stale/lower-value bullet — surface that trade to the user.
4. **Open a PR** (never push to a protected branch, never auto-merge):
   - branch, apply the one-bullet delta to `references/lessons.md` with provenance (`cand_id`, source runs),
   - attach `benchmark.json` (the non-regression + RED-case evidence),
   - record the promotion in `.cc-local-loop/promoted.jsonl` (`cand_id → PR#, eval_delta`),
   - **the PR must NOT touch `evals/calibration/**`, the gate scripts, or the harness** — a whitelist staging check
     aborts if it does (the loop may never grade its own homework).
5. Tell the user the PR is open and **awaits their merge**.

## Never

- Never edit `evals/calibration/**`, `scripts/harness/**`, gate thresholds, or protected globs. Expanding the
  calibration set is a **separate** human PR, never bundled with a promotion.
- Never promote without a passing benchmark. Never auto-merge. Human-authored / pinned lessons are never auto-pruned.
