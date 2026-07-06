#!/usr/bin/env bash
# Enforce the ccloop status ladder on progress.md. FAIL-CLOSED: die on any illegal move / unknown status / unknown task.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh"
PROG="${DATA_DIR}/progress.md"

rank(){ case "$1" in
  pending) echo 0;; dispatched) echo 1;; implemented) echo 2;; judge-fail) echo 2;;
  judge-uncertain) echo 3;; judge-pass) echo 4;; human-signed) echo 5;; *) echo -1;; esac; }

record(){ # <taskid> <newstatus>
  local id="$1" ns="$2" cur nr cr
  [ -f "$PROG" ] || die "no progress.md at $PROG"
  [ "$(rank "$ns")" -ge 0 ] || die "unknown status '$ns'"
  [ "$ns" = human-signed ] && die "record: 'human-signed' is set ONLY by done-gate.sh (the human gate), never by the loop (M2)"
  cur="$(awk -F'|' -v id="$id" '{s2=$2;gsub(/ /,"",s2); if(s2==id){s=$3;gsub(/ /,"",s);print s;exit}}' "$PROG")"
  [ -n "$cur" ] || die "unknown task '$id' in progress.md"
  cr="$(rank "$cur")"; nr="$(rank "$ns")"
  if [ "$nr" -lt "$cr" ] && ! { [ "$cur" = judge-fail ] && [ "$ns" = dispatched ]; }; then
    die "illegal transition for $id: $cur -> $ns (monotonic; only judge-fail->dispatched may go back)"
  fi
  # rewrite the row (portable: awk to temp, then mv — never sed -i)
  local tmp; tmp="$(mktemp)"
  awk -F'|' -v id="$id" -v ns="$ns" 'BEGIN{OFS="|"}
    { s2=$2; gsub(/ /,"",s2)
      if (s2==id) { $3=" "ns" "; print; } else print }' "$PROG" > "$tmp"
  mv "$tmp" "$PROG"
}

lint(){
  [ -f "$PROG" ] || die "no progress.md"
  awk -F'|' '
    /^\| *T[0-9]/ { id=$2; gsub(/ /,"",id); s=$3; gsub(/ /,"",s)
      if (seen[id]++) { print "dup:"id; bad=1 }
      if (s!="pending"&&s!="dispatched"&&s!="implemented"&&s!="judge-fail"&&s!="judge-uncertain"&&s!="judge-pass"&&s!="human-signed"){ print "badstatus:"id":"s; bad=1 } }
    END{ exit bad?1:0 }' "$PROG" || die "progress.md failed lint"
}

# record-next: advance the current in-flight task using the judge's recorded verdict (loop wrapper for the workflow).
record_next(){
  local id verdict
  id="$(awk -F'|' '/^\| *T[0-9]/{s=$3;gsub(/ /,"",s); t=$2;gsub(/ /,"",t); if(s=="dispatched"||s=="implemented"){print t; exit}}' "$PROG")"
  [ -n "$id" ] || { log "record-next: no in-flight (dispatched/implemented) task — nothing to record"; return 0; }
  verdict="$(cat "${DATA_DIR}/last-verdict" 2>/dev/null || true)"
  [ -n "$verdict" ] || die "record-next: no judge verdict for $id (judge not wired — node-ai §15.5)"
  record "$id" "$verdict"
}

case "${1:-lint}" in
  record)      shift; record "$@" ;;
  record-next) record_next ;;
  lint)        lint ;;
  *)           die "usage: progress-lint.sh {record <task> <status>|record-next|lint}" ;;
esac
