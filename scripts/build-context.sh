#!/usr/bin/env bash
# Assemble a NARROW iteration context: {state, the open failure, only TRACKED repo files from its stack-trace +
# last diff}, capped by an explicit token budget. Keeps each iteration light (ETH-Zurich: less context = better).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
TASK="${1:?usage: build-context.sh <task-id> \"<failure-text>\"}"; FAILURE="${2:-}"
BUDGET="${CCLL_CONTEXT_BUDGET:-8000}"; case "$BUDGET" in ''|*[!0-9]*) BUDGET=8000;; esac
budget_chars=$((BUDGET * 4))
cd "${CLAUDE_PROJECT_DIR}" || die "no project dir"
mkdir -p "${DATA_DIR}"; OUT="${DATA_DIR}/context-${TASK}.md"; : > "$OUT"
fail_head="$(printf '%s' "$FAILURE" | head -c $((budget_chars / 2)))"   # bound the failure text too
{
  echo "## State"; [ -f "${DATA_DIR}/loop_state.json" ] && cat "${DATA_DIR}/loop_state.json"; echo
  echo "## Current failure"; printf '%s\n' "$fail_head"; echo
  echo "## Relevant files (stack-trace + last diff · budget ${BUDGET} tok)"
} >> "$OUT"
# candidate files: paths in the failure text (|| true so a no-file-token failure does not abort) + last-diff files
{ printf '%s\n' "$FAILURE" | grep -oE '[A-Za-z0-9_./-]+\.(ts|tsx|js|jsx|py|go|rs|java|rb|c|cpp|h)' || true ;
  git diff --name-only HEAD~1 2>/dev/null || true ; } | sort -u | while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in /*|*..*|.cc-local-loop/*|*/.cc-local-loop/*) continue;; esac  # reject abs paths, traversal, and the
  # data plane — telemetry/candidates/promoted.jsonl are NEVER injected into an implementer prompt (G1, explicit deny)
  git ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || continue   # TRACKED repo file only (no exfiltration)
  [ -f "$f" ] || continue
  cur=$(wc -c < "$OUT"); fs=$(wc -c < "$f")
  if [ $((cur + fs)) -gt "$budget_chars" ]; then printf '### %s (skipped — context budget exceeded)\n' "$f" >> "$OUT"; continue; fi
  { printf '### %s\n\n' "$f"; cat "$f"; echo; } >> "$OUT"
done
log "context: $(wc -l < "$OUT" | tr -d ' ') lines, ~$(( $(wc -c < "$OUT") / 4 )) tok (budget ${BUDGET}) → ${OUT}"
printf '%s\n' "$OUT"
