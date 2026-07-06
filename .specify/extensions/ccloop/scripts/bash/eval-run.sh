#!/usr/bin/env bash
# CADENCE unit (cron/Routine calls THIS, not a skill — skills aren't invocable in `claude -p` headless).
# Re-runs the FROZEN calibration set, snapshots results, computes the delta vs the previous snapshot, emits
# eval_delta events + a STATUS line. STOPS at quarantine — it NEVER calls promote-lessons and NEVER opens a PR (G3).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
command -v jq >/dev/null 2>&1 || die "jq required"
CASES="${DIR}/../../evals/calibration/cases.json"; [ -f "$CASES" ] || die "calibration cases not found"
EVDIR="${DATA_DIR}/evals"; mkdir -p "$EVDIR"
stamp="$(date -u +%FT%H%M%SZ)"; OUT="${EVDIR}/${stamp}.jsonl"          # per-run snapshot — no same-UTC-day clobber (M3)
# TODO(preflight): run each case through the grader/skill-creator harness for a REAL verdict. Until node-ai + the
# grader are wired, record 'pending' (honest scaffold — never fake a pass).
tmp="${OUT}.tmp"                                                       # temp+mv: a die must leave NO 0-byte snapshot
jq -c '.cases[] | {id, category, expected_verdict, result:"pending"}' "$CASES" > "$tmp" \
  || { rm -f "$tmp"; die "cases.json unreadable/malformed — refusing to write a partial snapshot (fail-closed)"; }
mv "$tmp" "$OUT"
log "eval snapshot → ${OUT} ($(wc -l < "$OUT" | tr -d ' ') cases, result=pending until grader wired)"
prev="$(ls -1 "$EVDIR"/*.jsonl 2>/dev/null | grep -vF "$OUT" | tail -1 || true)"
if [ -n "$prev" ] && [ -f "$prev" ]; then
  # --slurpfile reads EACH file into its OWN array ($new/$old). Plain `jq -s a b` flattens BOTH into one array —
  # that was the C1 dead-code bug (.[0]/.[1] became the first two *cases*, jq crashed, delta silently read 0).
  changed="$(jq -n -c --slurpfile new "$OUT" --slurpfile old "$prev" '
    ($new | map({(.id): .result}) | add // {}) as $n
    | ($old | map({(.id): .result}) | add // {}) as $o
    | [ $n | to_entries[] | select(.value != ($o[.key] // "n/a")) | {id:.key, from:($o[.key] // "n/a"), to:.value} ]')" \
    || { log "eval: WARN delta failed (corrupt snapshot?) — skipping delta this run"; changed='[]'; }
  n="$(printf '%s' "$changed" | jq 'length' 2>/dev/null || echo 0)"
  [ "${n:-0}" -gt 0 ] && "${DIR}/emit.sh" eval_delta "$(printf '%s' "$changed" | jq -c '{changed_count:length, sample:(.[:20])}')" harness
  log "eval delta vs $(basename "$prev"): ${n:-0} changed case(s)"
else
  log "eval: first snapshot (nothing to diff)"
fi
log "eval-run done — PROPOSER only: newly-passing/failing cases feed reflect (quarantine); promotion is human-gated."
