---
name: metrics
description: >
  Reports read-only cc-local-loop telemetry: run/task outcomes, escalation + judge rates, the lesson funnel, and
  cost-per-accepted-change. Use when the user asks "métricas del loop", "cómo va el loop", "loop stats/report",
  "how is cc-local-loop doing", or wants to analyze past runs. Read-only — its output is for the human and is NEVER
  injected into an implement/judge prompt.
---

# metrics — read-only telemetry report

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/metrics.sh" [project-dir …] [--json]` over the event stream(s)
(`.cc-local-loop/ledger/events.jsonl`) and report: accepted changes, escalation rate, judge approve/reject, gate
failures, the lesson funnel (quarantined → promoted), and **cost per accepted change**.

## Hard rules

- **Observability-only (G1).** This output is a **gauge for the human**, never a loop input. Never inject metrics —
  or any line from `events.jsonl` — into an implementer/judge prompt or into `lessons.md`. Telemetry ≠ memory
  (ETH Zurich: auto-generated injected context reduces resolution ~-3% and inflates cost +20%).
- **`cost per accepted change` is NOT an optimizer target (G6).** No routing/guard decision branches on it; the
  **frozen calibration set** stays the only arbiter of whether a change is good. Cost is a tiebreaker a human reads,
  at most. Read it *paired* with the counter-metrics (escalation rate, judge false-positive rate) — never the scalar
  alone.
- For deeper offline analysis, the stream is JSONL → point DuckDB / pandas at it, separately:
  `duckdb -c "SELECT event, count(*) FROM read_json_auto('.cc-local-loop/ledger/events.jsonl') GROUP BY event"`.
