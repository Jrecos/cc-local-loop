#!/usr/bin/env bash
# G4: validate references/lessons.md — cap (<=15 bullets, <=2K tokens), header intact, every bullet has provenance.
# FAILS CLOSED. Run at preflight (refuse to arm), promote-check (PR), and CI — closes the no-PR direct-write channel.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
F="${1:-${DIR}/../../references/lessons.md}"
[ -f "$F" ] || die "lessons.md not found: $F"
head -n 5 "$F" | grep -q 'the ONE injected memory file' || die "lessons.md header/sentinel missing from the top — refusing (tamper?)"
maxb="${CCLL_LESSONS_MAX:-15}"; maxt="${CCLL_LESSONS_TOK:-2000}"
# Count bullets across the WHOLE file, minus HTML-comment examples and the blockquote header — so content can't
# evade the cap by sitting above the '## Lessons' heading, and an indented '  - ...' can't smuggle content past
# either. awk state-machine (NOT `sed /<!--/,/-->/d`: a single-line `<!-- x -->` opens a range that runs to EOF,
# hiding every bullet after it from the cap — a real G4 bypass).
body="$(awk '/<!--/{c=1} !c; /-->/{c=0}' "$F" | grep -vE '^[[:space:]]*>')"
bullets="$(printf '%s\n' "$body" | grep -cE '^[[:space:]]*[-*+][[:space:]]' || true)"
[ "$bullets" -le "$maxb" ] || die "lessons.md has ${bullets} bullets > ${maxb} cap"
chars="$(wc -c < "$F" | tr -d ' ')"; toks=$((chars / 4))
[ "$toks" -le "$maxt" ] || die "lessons.md ~${toks} tok > ${maxt} cap"
# Provenance = an **Lxxx** ID AND a source tag ([seed] or [cand_...]) on the SAME bullet (was OR — an ID alone passed).
bad="$(printf '%s\n' "$body" | grep -E '^[[:space:]]*[-*+][[:space:]]' | grep -vE '\*\*L[0-9]+\*\*.*(\[seed\]|\[cand_)' || true)"
[ -z "$bad" ] || { { echo "bullets missing an **Lxxx** ID + [seed]/[cand_] provenance:"; printf '  %s\n' "$bad"; } >&2; die "every lesson needs an ID AND provenance"; }
log "lessons-lint OK (${bullets} bullets, ~${toks} tok)"
