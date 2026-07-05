#!/usr/bin/env bash
# cc-local-loop shared library — source it. (No `set` here; each entry script sets its own strictness.)
# CONTRACT: die/assert_* call `exit`. Never call them inside $( ) command substitution in a non-`set -e`
# script (the ABORT prints but the parent continues). Call at top level, or check $? explicitly.

: "${NODE_AI_URL:=http://127.0.0.1:8080}"   # OVERRIDE per install: export NODE_AI_URL=http://<node-ai-host>:8080
: "${CLAUDE_PROJECT_DIR:=$(pwd)}"
DATA_DIR="${CLAUDE_PROJECT_DIR}/.cc-local-loop"
LEDGER="${DATA_DIR}/ledger/runs.jsonl"

# SINGLE SOURCE OF TRUTH for protected paths (anchored; consumed by freeze, gate, and dispatch deny-globs).
# Matches git-relative paths (NO leading slash). Covers tests, specs/SDD, CI, lockfiles, coverage/build config.
PROTECTED_PAT='(^|/)(tests?|__tests__|e2e|specs?|\.specify|\.github|\.gitlab|\.circleci|\.buildkite)/|\.(test|spec)\.|(^|/)(package|composer)\.json$|(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb|Cargo\.lock|poetry\.lock|uv\.lock)$|(^|/)(jest\.config|vitest\.config|vite\.config|\.nycrc|codecov|pyproject\.toml|setup\.cfg|tox\.ini|\.coveragerc)[^/]*$|(^|/)(tasks|progress)\.md$|(^|/)constitution[^/]*$'

log(){ printf '[cc-local-loop] %s\n' "$*" >&2; }
die(){ printf '[cc-local-loop] ABORT: %s\n' "$*" >&2; exit 1; }

# portable sha256 (Linux sha256sum, macOS shasum)
sha256(){
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum   >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else die "no sha256sum/shasum available"; fi
}

# lineage family for the cross-family invariant (fail-closed on unknown). Normalizes case + strips provider prefix.
family_of(){
  local m; m="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; m="${m##*/}"
  case "$m" in
    ornith*|qwen*)                echo qwen ;;
    gemma*)                       echo google ;;
    nemotron*)                    echo nvidia ;;
    magistral*)                   echo mistral ;;
    opus*|sonnet*|haiku*|claude*) echo anthropic ;;
    *)                            echo unknown ;;
  esac
}

# models allowed to IMPLEMENT locally (Opus/Claude is NEVER dispatched — it judges its own output, §1).
: "${CCLL_IMPL_ROSTER:=ornith-35b qwen3.6-35b gemma-4-26b-a4b}"
assert_impl_allowed(){ # <impl_model>
  local m="$1" ok=1 r
  [ "$(family_of "$m")" = anthropic ] && die "Opus/Claude is never a local implementer — it judges its own output (§1)"
  for r in $CCLL_IMPL_ROSTER; do [ "$m" = "$r" ] && ok=0; done
  [ "$ok" -eq 0 ] || die "model '$m' not in implementer roster ($CCLL_IMPL_ROSTER)"
}

assert_cross_family(){ # <impl_model> <judge_model>
  local f_impl f_judge; f_impl="$(family_of "$1")"; f_judge="$(family_of "$2")"
  [ "$f_impl" = unknown ]  && die "unknown family for impl '$1' (family-map fail-closed)"
  [ "$f_judge" = unknown ] && die "unknown family for judge '$2' (family-map fail-closed)"
  [ "$f_impl" = "$f_judge" ] && die "cross-family invariant violated: impl '$1' and judge '$2' are both '$f_impl'"
  return 0
}

health_check(){ curl -fsS --max-time 5 "${NODE_AI_URL}/health"    >/dev/null 2>&1 \
             || curl -fsS --max-time 5 "${NODE_AI_URL}/v1/models" >/dev/null 2>&1; }

ledger_append(){ # <json-row>
  mkdir -p "$(dirname "$LEDGER")"
  if command -v flock >/dev/null 2>&1; then ( flock 9; printf '%s\n' "$1" >> "$LEDGER" ) 9>>"$LEDGER"
  else printf '%s\n' "$1" >> "$LEDGER"; fi
}
