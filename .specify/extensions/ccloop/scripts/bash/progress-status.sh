#!/usr/bin/env bash
# Read progress.md and report status counts (JSON) or assert the loop is closed. FAIL-CLOSED on --assert-closed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh"
PROG="${DATA_DIR}/progress.md"

counts(){ # emits: total open passed uncertain  (open = not judge-pass and not human-signed)
  [ -f "$PROG" ] || { echo "0 0 0 0"; return 0; }
  awk -F'|' '
    /^\| *T[0-9]/ {
      s=$3; gsub(/ /,"",s); total++
      if (s=="judge-pass") passed++
      else if (s=="human-signed") { }
      else { open++; if (s=="judge-uncertain") unc++ }
    }
    END { printf "%d %d %d %d", total+0, open+0, passed+0, unc+0 }
  ' "$PROG"
}

read -r total open passed unc <<EOF
$(counts)
EOF

case "${1:---json}" in
  --json)          printf '{"total":%d,"open":%d,"passed":%d,"uncertain":%d}\n' "$total" "$open" "$passed" "$unc" ;;
  --assert-closed)
    # FAIL-CLOSED: zero tasks is NOT "closed" — a vacuous/empty progress.md must never green the loop to sign-off.
    [ "$total" -gt 0 ] || die "assert-closed: progress.md has 0 tasks (nothing derived — refusing to call it closed)"
    [ "$open" -eq 0 ]  || die "assert-closed: $open task(s) still open (cap exhausted or incomplete)"
    ;;
  *)               die "usage: progress-status.sh {--json|--assert-closed}" ;;
esac
