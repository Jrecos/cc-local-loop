#!/usr/bin/env bash
# READ-ONLY telemetry report over the event stream(s). NEVER injected into a loop prompt (G1) — for humans only.
# cost-per-accepted-change is a GAUGE, never an optimizer target (G6 — no script/skill/agent branches on it).
# Usage: metrics.sh [project-dir ...] [--json]   (defaults to $CLAUDE_PROJECT_DIR)
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
command -v jq >/dev/null 2>&1 || die "jq required"
fmt=table; dirs=()
for a in "$@"; do case "$a" in --json) fmt=json;; --format=*) fmt="${a#--format=}";; *) dirs+=("$a");; esac; done
[ "${#dirs[@]}" -gt 0 ] || dirs=("${CLAUDE_PROJECT_DIR}")
files=(); for d in "${dirs[@]}"; do f="$d/.cc-local-loop/ledger/events.jsonl"; [ -f "$f" ] && files+=("$f"); done
if [ "${#files[@]}" -eq 0 ]; then echo '{"note":"no telemetry yet"}'; exit 0; fi
# Parse line-by-line and DROP any torn/corrupt line (fromjson? // empty) so one bad row can't blank the whole
# report (H2). Append-only streams accumulate forever — a single truncated write must not be fatal.
agg="$(cat "${files[@]}" | jq -cR 'fromjson? // empty | objects' | jq -s '
  def cnt(f): [ .[] | select(f) ] | length;
  { events: length,
    tasks_total:    cnt(.event=="task_end"),
    tasks_accepted: cnt(.event=="task_end" and (((.outcome // "") | tostring) | test("accepted"))),
    escalations:    cnt(.event=="escalation"),
    gate_fail:      cnt(.event=="gate" and .status=="fail"),
    judge_approve:  cnt(.event=="judge" and .verdict=="APPROVE"),
    judge_reject:   cnt(.event=="judge" and .verdict=="REJECT"),
    lessons_quarantined: cnt(.event=="lesson" and .action=="quarantined"),
    lessons_promoted:    cnt(.event=="lesson" and .action=="promoted"),
    opus_tokens:    ([ .[] | select(.event=="run_end") | (.opus_tokens.in? // 0) + (.opus_tokens.out? // 0) ] | add // 0) }
  | .escalation_rate = (if .tasks_total>0 then ((.escalations/.tasks_total*100)|floor/100) else 0 end)
  | .cost_per_accepted_change = "Σ opus_tokens × price[offline] / tasks_accepted  (GAUGE, not a target — the frozen set decides)"
')" || die "metrics: aggregation failed (unexpected) — refusing to print an empty report"
if [ "$fmt" = json ]; then printf '%s\n' "$agg"; else printf '%s\n' "$agg" | jq -r 'to_entries[] | "  \(.key): \(.value)"'; fi
