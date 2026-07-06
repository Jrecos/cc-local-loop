# Frozen calibration set (the yardstick)

These seeded-bug cases are the **frozen yardstick** the self-improvement loop measures candidate lessons against.

**Rules (enforced by CODEOWNERS + the promote-lessons whitelist check):**
- The loop **never edits** these files. A lesson-promotion PR that touches `evals/calibration/**` is aborted.
- Expanding the set is a **separate human PR**, never bundled with a promotion (otherwise the loop grades its own homework — Goodhart).
- Grading reuses the installed `skill-creator` eval harness (baseline vs candidate, ≥5 reps, mean±stddev + delta).

Each case is a seeded-bug diff plus objective assertions the judge/loop must catch. Categories mirror the routing
rubric: `numeric`, `spec`, `architecture`, `security`, `clean` (a no-bug control — the judge must NOT false-positive).

`cases.json` below is a **seed** to expand once the loop runs; measure both catch-rate and false-positive-rate.
