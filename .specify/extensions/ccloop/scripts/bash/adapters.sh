#!/usr/bin/env bash
# Pluggable agent-CLI adapter. Normalizer + per-CLI invocation shapes. DIE-GUARDED until node-ai topology is live.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib/common.sh"

# name-or-path -> kind. bash-3.2 safe (tr, not ${var,,}). Strips path + .exe/.cmd/.bat.
get_agent_cli_kind(){
  local n; n="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; n="${n##*/}"
  n="${n%.exe}"; n="${n%.cmd}"; n="${n%.bat}"
  case "$n" in
    opencode) echo opencode ;;
    claude)   echo claude ;;
    codex)    echo codex ;;
    copilot)  echo copilot ;;
    *)        echo unsupported ;;
  esac
}

# Build the per-CLI command for one iteration. GUARDED: refuses to run until the serving topology exists.
invoke_agent_iteration(){ # <kind> <model> <prompt> <workdir>
  local kind="$1" model="$2" prompt="$3" wd="${4:-.}"
  case "$kind" in
    opencode|claude|codex|copilot) : ;;
    *) die "unsupported agent CLI kind '$kind' (supported: opencode, claude, codex, copilot)" ;;
  esac
  # The exact arg shapes (documented for when the topology lands):
  #   opencode: opencode run --model "$model" <<<"$prompt"
  #   claude:   claude -p "$prompt" --model "$model" --dangerously-skip-permissions
  #   codex:    printf '%s' "$prompt" | codex exec --json --model "$model" --sandbox danger-full-access --cd "$wd" -
  #   copilot:  copilot --agent speckit-ccloop-iterate -p "$prompt" --model "$model" --yolo -s
  die "node-ai serving topology not deployed - dispatch is die-guarded (homelab spec §15.5). kind=$kind model=$model wd=$wd"
}
