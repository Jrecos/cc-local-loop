#!/usr/bin/env bash
# Refuse to start the loop unless its cage is verified (design doc §15.5). Exit non-zero on any failure.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
fail=0
log "preflight — node-ai + repo state"
if health_check; then log "OK  : node-ai reachable (${NODE_AI_URL})"; else log "FAIL: node-ai unreachable (${NODE_AI_URL})"; fail=1; fi
if [ -z "$(git -C "${CLAUDE_PROJECT_DIR}" status --porcelain 2>/dev/null)" ]; then log "OK  : git tree clean"; else log "FAIL: git tree not clean"; fail=1; fi
# TODO(preflight): #1 deployed llama-swap config hash == Option-B ; #4 stop-counter verified to stop at N (Anthropic #18646)
# TODO(preflight): #6 Ornith reasoning-template /props check ; #7 Gemma-26B tool-calling smoke test
log "TODO: config-hash, stop-counter, Ornith/Gemma-26B preflights (§15.5 #1,#4,#6,#7)"
[ "$fail" -eq 0 ] || die "preflight failed — the loop will not start"
log "preflight passed"
