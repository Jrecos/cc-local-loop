#!/usr/bin/env bash
# Offline reflection: distill the event ledger into QUARANTINED candidate lessons. FAIL-SAFE (always exit 0) —
# reflection is best-effort and must never kill the loop. It NEVER edits references/lessons.md (that is the
# human-gated promote path, G3). The real distillation is the `distiller` agent; this is the deterministic hook.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh" 2>/dev/null || true

case "${1:-run}" in
  run)
    if [ -f "$LEDGER" ]; then
      n="$(grep -c . "$LEDGER" 2>/dev/null || echo 0)"
      log "reflect: ${n} ledger event(s); candidates are quarantined via candidates-append.sh + the distiller agent (never auto-applied, never touch lessons.md)."
    else
      log "reflect: no ledger yet — nothing to distill."
    fi
    ;;
  *) log "reflect: unknown arg '${1:-}' (no-op)";;
esac
exit 0   # fail-safe: reflection never blocks the loop
