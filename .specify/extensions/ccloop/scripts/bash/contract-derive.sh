#!/usr/bin/env bash
# Derive the per-task DoD contract + seed progress.md from tasks.md. FAIL-CLOSED. Idempotent (never downgrades).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh"
TMPL="$HERE/../../templates"
FEAT="${CLAUDE_PROJECT_DIR}/${CCLOOP_FEATURE:?CCLOOP_FEATURE must be set by arm}"
TASKS="${FEAT}/tasks.md"
PROG="${DATA_DIR}/progress.md"; CONTRACT="${DATA_DIR}/contract.md"
[ -f "$TASKS" ] || die "no tasks.md at $TASKS"
mkdir -p "$DATA_DIR"

# Extract "T### <title>" from spec-kit task lines. Handles BOTH plain "- [ ] T001 [P] Title" and the
# superspec bold-ID form "- [x] **T001** [SUBAGENT] Title" (the format /speckit.tasks + superspec emit).
extract(){ awk '
  /^- \[[ xX]\] +\*{0,2}T[0-9]+/ {
    line=$0
    sub(/^- \[[ xX]\] +/,"",line)                 # drop checkbox
    gsub(/\*\*/,"",line)                           # strip bold markers around id/title
    split(line,a," "); id=a[1]                     # first token is now the bare task id
    title=line; sub(/^T[0-9]+ +/,"",title); sub(/^\[[Pp]\] */,"",title)
    gsub(/\|/,"/",title)                           # keep table cells intact
    printf "%s\t%s\n", id, title
  }' "$TASKS"; }

# M1: a non-empty tasks.md that yields 0 recognizable task lines is an error, not a silent empty (vacuous) run.
ntasks="$(extract | grep -c . || true)"
[ "${ntasks:-0}" -gt 0 ] || die "contract-derive: 0 tasks extracted from $TASKS (expected spec-kit lines like '- [ ] T001 ...')"
# contract.md: overwrite (derived, not stateful) from template + one row per task
cp "$TMPL/contract-template.md" "$CONTRACT"
extract | while IFS="$(printf '\t')" read -r id title; do
  printf '| %s | %s | tests pass + judge verifies expected outcomes | pending |\n' "$id" "$title" >> "$CONTRACT"
done

# progress.md: seed if absent; else ADD only new task IDs (never downgrade existing)
if [ ! -f "$PROG" ]; then cp "$TMPL/progress-template.md" "$PROG"; fi
extract | while IFS="$(printf '\t')" read -r id title; do
  grep -q "| $id " "$PROG" || printf '| %s | pending | %s |\n' "$id" "$title" >> "$PROG"
done
log "contract-derive: $(grep -c '^| T[0-9]' "$CONTRACT") task(s) -> $CONTRACT ; progress $PROG"
