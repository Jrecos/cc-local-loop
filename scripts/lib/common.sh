#!/usr/bin/env bash
# cc-local-loop shared library — source it: . "<plugin>/scripts/lib/common.sh"
# (No `set` here; each entry script sets its own strictness.)

: "${NODE_AI_URL:=http://192.168.0.87:8080}"
: "${CLAUDE_PROJECT_DIR:=$(pwd)}"
DATA_DIR="${CLAUDE_PROJECT_DIR}/.cc-local-loop"
LEDGER="${DATA_DIR}/ledger/runs.jsonl"

log(){ printf '[cc-local-loop] %s\n' "$*" >&2; }
die(){ printf '[cc-local-loop] ABORT: %s\n' "$*" >&2; exit 1; }

# lineage family — the load-bearing map for the cross-family gate invariant (fail-closed on unknown)
family_of(){
  case "$1" in
    ornith*|qwen*)          echo qwen ;;
    gemma*)                 echo google ;;
    nemotron*)              echo nvidia ;;
    magistral*)             echo mistral ;;
    opus*|sonnet*|haiku*)   echo anthropic ;;
    *)                      echo unknown ;;
  esac
}

assert_cross_family(){ # <impl_model> <judge_model>
  local fi fj; fi="$(family_of "$1")"; fj="$(family_of "$2")"
  [ "$fi" = unknown ] && die "unknown family for impl '$1' (family-map fail-closed)"
  [ "$fj" = unknown ] && die "unknown family for judge '$2' (family-map fail-closed)"
  [ "$fi" = "$fj" ] && die "cross-family invariant violated: impl '$1' and judge '$2' are both '$fi'"
  return 0
}

health_check(){ curl -fsS --max-time 5 "${NODE_AI_URL}/health" >/dev/null 2>&1 \
             || curl -fsS --max-time 5 "${NODE_AI_URL}/v1/models" >/dev/null 2>&1; }

ledger_append(){ mkdir -p "$(dirname "$LEDGER")"; printf '%s\n' "$1" >> "$LEDGER"; }
