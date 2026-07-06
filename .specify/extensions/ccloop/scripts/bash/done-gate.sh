#!/usr/bin/env bash
# Human sign-off closure. FAIL-CLOSED: refuse unless all tasks judge-pass and no open blocking debt.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh"
PROG="${DATA_DIR}/progress.md"; DEBT="${DATA_DIR}/debt.md"

signoff(){ # <optional signer note>
  local note="${1:-human}"
  # 1) no open tasks (every task judge-pass or already human-signed)
  local open; open="$(awk -F'|' '/^\| *T[0-9]/{s=$3;gsub(/ /,"",s); if(s!="judge-pass"&&s!="human-signed")n++} END{print n+0}' "$PROG")"
  [ "$open" -eq 0 ] || die "cannot sign off: $open task(s) not judge-pass"
  # 2) no open blocking debt
  if [ -f "$DEBT" ]; then
    # match the Severity COLUMN == "blocking" (not a bare substring — so "non-blocking" does not over-block).
    local blk; blk="$(awk -F'|' '/^\|/{s=$3;gsub(/ /,"",s); if(tolower(s)=="blocking")n++} END{print n+0}' "$DEBT")"
    [ "$blk" -eq 0 ] || die "cannot sign off: $blk open blocking-debt row(s) in debt.md"
  fi
  # 3) record sign-off + flip judge-pass -> human-signed (portable awk rewrite)
  mkdir -p "$DATA_DIR"; [ -f "$DEBT" ] || printf '# Debt\n' > "$DEBT"
  printf '\n## Sign-off log\n- Signed off by: %s (RUN_ID=%s)\n' "$note" "$(cat "${DATA_DIR}/RUN_ID" 2>/dev/null || echo n/a)" >> "$DEBT"
  local tmp; tmp="$(mktemp)"
  awk -F'|' 'BEGIN{OFS="|"} { s=$3; gsub(/ /,"",s); if ($0 ~ /^\| *T[0-9]/ && s=="judge-pass"){ $3=" human-signed "; print } else print }' "$PROG" > "$tmp"
  mv "$tmp" "$PROG"
  log "done-gate: signed off; all tasks human-signed"
}

case "${1:-signoff}" in
  signoff) shift; signoff "${1:-human}" ;;
  *)       die "usage: done-gate.sh signoff [signer]" ;;
esac
