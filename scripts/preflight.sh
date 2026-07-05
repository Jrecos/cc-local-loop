#!/usr/bin/env bash
# Refuse to start unless the cage is verified (§15.5). Unimplemented checks FAIL (dev bypass: CCLL_ALLOW_SCAFFOLD=1).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
fail=0
log "preflight — node-ai + repo state"
# git repo FIRST (else the clean-tree check fails open)
if git -C "${CLAUDE_PROJECT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then log "OK  : git repo"; else log "FAIL: not a git repo"; fail=1; fi
if health_check; then log "OK  : node-ai reachable (${NODE_AI_URL})"; else log "FAIL: node-ai unreachable (${NODE_AI_URL})"; fail=1; fi
# clean tree EXCLUDING our own data plane
if [ -z "$(git -C "${CLAUDE_PROJECT_DIR}" status --porcelain -- . ':(exclude).cc-local-loop' 2>/dev/null)" ]; then log "OK  : git tree clean"; else log "FAIL: git tree not clean"; fail=1; fi
# yardstick seeded (§15.5 #3)
if ls "${DIR}/../evals/calibration/seeds/"*.diff >/dev/null 2>&1; then log "OK  : calibration seeds present"; else log "FAIL: calibration seeds missing (freeze the yardstick first)"; fail=1; fi
# unimplemented §15.5 keys — FAIL unless explicitly bypassed
if [ "${CCLL_ALLOW_SCAFFOLD:-0}" = 1 ]; then
  log "WARN: scaffold mode — skipping #1 config-hash, #4 stop-counter, #6 Ornith-template, #7 Gemma-26B-tools"
else
  log "FAIL: §15.5 #1/#4/#6/#7 not implemented (set CCLL_ALLOW_SCAFFOLD=1 to bypass in dev)"; fail=1
fi
[ "$fail" -eq 0 ] || die "preflight failed — the loop will not start"
log "preflight passed"
