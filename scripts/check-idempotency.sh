#!/usr/bin/env bash
# Run the deterministic gate N times on the CURRENT state and assert identical output. A flaky check breaks the
# loop's stop condition — fix the check before trusting the loop (loop-engineering step 0).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
base="${1:?usage: check-idempotency.sh <base-ref> [N]}"; N="${2:-3}"; case "$N" in ''|*[!0-9]*) N=3;; esac
git -C "${CLAUDE_PROJECT_DIR}" rev-parse --verify -q "${base}^{commit}" >/dev/null 2>&1 || die "bad base ref: ${base}"
first=""; ok=1; i=0
while [ "$i" -lt "$N" ]; do
  out="$("${DIR}/harness/gate.sh" "$base" 2>/dev/null || true)"
  if [ -z "$first" ]; then first="$out"; elif [ "$out" != "$first" ]; then ok=0; fi
  i=$((i+1))
done
[ "$ok" -eq 1 ] && log "check idempotent over ${N} runs ✓" || die "gate is NON-idempotent over ${N} runs — fix the check before running the loop"
