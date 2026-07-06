# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **v0.5.0 repackaging note:** `cc-local-loop` is now a **GitHub Spec Kit 0.12.4 extension** (`ccloop`), not a standalone
> Claude Code plugin. The canonical scripts live under `.specify/extensions/ccloop/scripts/bash/` (paths below that say
> `scripts/…` refer to that location); the loop is a spec-kit **workflow** (`.specify/extensions/ccloop/workflow/workflow.yml`);
> the data plane is `specs/<feature>/ccloop/` (fallback `.cc-local-loop/` when no feature is armed). New guardrail **G9 —
> `tasks.md` immutability**. The regression net (`tests/run-tests.sh`) now runs against the extension. See
> `specs/001-ccloop-extension/` and `docs/superpowers/specs/2026-07-06-ccloop-speckit-extension-design.md`. Sections below
> describing the "plugin" form are historical.

## What this repo is

`cc-local-loop` is a **Claude Code plugin** (and its own marketplace) that packages an autonomous dev loop:

> **Opus 4.8 (Claude Code) orchestrates → local models on `node-ai` implement (via OpenCode) → a cross-family judge gates → Opus reviews.**

The invariant is `Opus → local models → Opus`: you pay for Opus only to *think and review*; the high-volume implementation runs free on local hardware. The loop converges on a **Definition of Done enforced in code**, never a model's opinion. This plugin is the running implementation of the design spec at `~/Claude/Projects/homelab/docs/ai-dev-orchestration-workflow.md` (v11) — keep the two in sync.

It is a **plugin, so most files are declarative** (Markdown skills, JSON manifests, bash scripts). There is no compiler; "build" = the scripts pass syntax + the regression net stays green.

## The most important rule: preserve the G1–G8 guardrails

The whole point of this plugin is a *safe* self-improving loop. Every change — especially to telemetry, lessons, dispatch, the judge, or promotion — must preserve these eight invariants. They are enforced in code and checked by `tests/run-tests.sh`; if a change would weaken one, it's wrong.

- **G1 — one injected memory.** Only `references/lessons.md` is ever injected into an implementer/judge prompt. Telemetry (`.cc-local-loop/ledger/events.jsonl`, metrics, eval snapshots) is **observability-only, never injected.** (`build-context.sh` explicitly denies the data plane.)
- **G2 — schema-pinned state.** `loop_state.json` is small and overwrite-only; `emit`/`metrics` never write it.
- **G3 — cadence proposes, humans promote.** `eval-run.sh` measures and proposes; it never calls `promote-lessons`, opens a PR, or edits `lessons.md`.
- **G4 — mechanical lessons gate.** `lessons-lint.sh` enforces the cap (≤15 bullets / ≤2K tokens) + provenance, **fail-closed**, at preflight **and** promote-check **and** CI.
- **G5 — additive only.** Promotions add (or single-amend) a lesson; a wholesale rewrite is rejected by `promote-check.sh`.
- **G6 — the frozen calibration set is the only arbiter.** `cost-per-accepted-change` is a **gauge, never an optimizer target**; nothing branches on it. `evals/calibration/**` is un-editable in-loop (in `PROTECTED_PAT` + CODEOWNERS).
- **G7 — retention split.** Observability is unbounded but never injected; candidates are budgeted; `lessons.md` is capped.
- **G8 — deterministic telemetry authorship.** `emit.sh`'s envelope (`event`/`run_id`/`source`) **wins over the payload**, so a caller can't forge an event.

Why so strict: the ETH-Zurich finding (arXiv 2602.11988) that LLM-generated injected context *reduces* resolution (~-3%) and inflates cost (+20%). Telemetry ≠ memory; improvement is human-gated, additive, and capped.

## Architecture: two planes

- **Code plane (this repo)** — versioned, shared: `skills/`, `scripts/`, `hooks/`, `agents/`, `references/`, `evals/calibration/`, `tests/`.
- **Data plane (the target project)** — at runtime the loop writes `.cc-local-loop/{ACTIVE, RUN_ID, frozen.json, ledger/events.jsonl, candidates.jsonl, evals/}` into *the project it works on*. Kept out of that repo via `.git/info/exclude` — **except** `promoted.jsonl`, deliberately re-included so a lesson-promotion PR can carry its audit trail.

**Safety-critical logic lives in `scripts/` (bash), not in the skills.** Skills are thin orchestration prose that *call* the scripts; they must never reimplement a gate in prose. The layout:

- **`skills/`** — `run-loop` (the orchestrator state machine; **human-started only**, `disable-model-invocation: true`), `dispatch` + `judge` (knowledge/how-to; the real work is the scripts), `reflect` (distills the event stream → quarantined candidates), `promote-lessons` (**human-gated** PR promotion), `metrics` (read-only report), `using-cc-local-loop` (router/orientation).
- **`scripts/lib/common.sh`** — the shared library and single source of truth for: `PROTECTED_PAT` (protected-path regex), `family_of` + `assert_cross_family` + `assert_impl_allowed` (the roster/cross-family invariant), `ledger_append` (line-safe append), `sha256`, `health_check`.
- **`scripts/harness/`** — `freeze.sh` (hash-pin the protected spine), `gate.sh` (scope → hash-verify → runner; **fails closed**), `guards.sh` (stop rules: MAX_ITER + TIME + no-progress + oscillation + heartbeat).
- **`scripts/`** (top level) — `dispatch.sh`, `judge.sh`, `preflight.sh`, `build-context.sh` (narrow, token-budgeted, data-plane-denied), `sandbox-run.sh` (`--network none` test isolation), `state.sh`, `check-idempotency.sh`, `emit.sh` (validated event writer), `metrics.sh` (read-only), `eval-run.sh` (proposer-only cadence), `lessons-lint.sh` (G4), `candidates-append.sh`, `promote-check.sh`, `doctor.sh` (the live ENFORCED/PARTIAL/TODO matrix).
- **`hooks/hooks.json`** — a `Stop` hook → `ledger-append.sh` writes a `run_end` event (only inside an active loop; fail-safe).
- **`agents/`** — `distiller` (read-only; returns a candidate lesson) and `grader` (eval; fails loud without the `skill-creator` plugin).
- **`references/`** — `rubric.md` (judge criteria), `lessons.md` (**the ONE injected memory**), `architecture.md` (deep design + E2E walkthrough).
- **`evals/calibration/`** — the **frozen yardstick** (seeded-bug `seeds/*.diff`). Measured against, **never edited in-loop**.

## Commands

```bash
# THE GATE — must stay green after every change (72 probes: syntax, safety, cross-family, telemetry, G1-G8)
bash tests/run-tests.sh

# Run a single probe group by its number (they're numbered `echo "N. ..."` blocks)
bash tests/run-tests.sh 2>&1 | sed -n '/^18\./,/^19\./p'

# What's actually ENFORCED in code vs PARTIAL/TODO scaffold
bash scripts/doctor.sh

# Individual gate scripts (read-only, safe to run anywhere)
bash scripts/lessons-lint.sh              # G4 cap/provenance on references/lessons.md
bash scripts/metrics.sh                   # read-only telemetry report (needs prior runs)

# Syntax + lint the whole script surface
for s in scripts/*.sh scripts/harness/*.sh; do bash -n "$s"; done
shellcheck -S warning scripts/*.sh scripts/harness/*.sh   # advisory (CI runs it with || true)

# Validate manifests / hooks / calibration JSON
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json evals/calibration/cases.json; do jq -e . "$f" >/dev/null && echo "ok $f"; done

# Use / develop the plugin locally
claude --plugin-dir .                     # load this repo as a plugin (dogfood it on itself)
```

## Conventions

- **After ANY change, `bash tests/run-tests.sh` must pass (currently 72/72).** New script or new behavior ⇒ **add a probe** in the same PR. The regression net *is* the review contract — it's the auditor probes made executable.
- **Fail-closed vs fail-safe is deliberate — respect each script's `set` mode:**
  - Safety-path scripts (`gate.sh`, `judge.sh`, `promote-check.sh`, `lessons-lint.sh`, `freeze.sh`, `build-context.sh`) **fail CLOSED** — `die` on any doubt, never fake a pass.
  - Telemetry scripts (`emit.sh`, `ledger-append.sh`) **fail SAFE — always `exit 0`** so telemetry can never kill the loop. **Do not add `set -e` to these** (there are comments saying so; they rely on limping past a failed helper).
- **`PROTECTED_PAT` in `common.sh` is the single source of truth** for protected paths (tests, specs/SDD, CI, lockfiles, `tasks.md`, `evals/calibration/`). Consumed by `freeze`, `gate`, and `dispatch`. Edit it there, nowhere else.
- **The cross-family invariant is absolute:** the model family that implemented a change never judges it. Enforced by `assert_cross_family` / `assert_impl_allowed` in `common.sh`. Opus is never a local implementer (it judges its own output only on escalation).
- **Portability: macOS (bash 3.2 / BSD userland) AND Linux (GNU) must both work.** No GNU-only flags, no `sed -i`, no `date -d`. Use the established idioms: `wc -c | tr -d ' '` for byte counts, `sha256()`'s `shasum` fallback, `awk` state machines over fragile `sed` ranges, quoted expansions, guarded empty-array expansion.
- **Telemetry authorship is deterministic (G8):** feed `emit.sh` the harness scripts' **own JSON verbatim** — never hand-type an event payload; the envelope wins regardless.

## Scaffold status (honest, and enforced)

The plugin **verifies its cage before entering it.** The node-ai calls (`dispatch.sh`, `judge.sh`) and `gate.sh`'s stage-3 test runner are `die`-guarded until the node-ai **"Option-B" serving topology** is deployed (homelab spec §15.5). This is intentional — nothing fakes green. `eval-run.sh` records `result:"pending"` until the grader is wired. Run `bash scripts/doctor.sh` for the live matrix; the honest TODOs are the node-ai wiring and the project-specific test runner.

## Working with git here

Claude Code runs natively, so git works normally (unlike the sandboxed Cowork environment, which couldn't manage `.git` on the mount). The repo **doubles as its own marketplace** (`.claude-plugin/marketplace.json`, `source: "./"`), so bumping a version means updating both `plugin.json` and `marketplace.json`. Development happens against `github.com/Jrecos/cc-local-loop`.

- Review + iteration pattern the project uses: **implement → `bash tests/run-tests.sh` (gate) → adversarial review → fix → re-gate.** The expert review that shaped the current hardening is in `docs/REVIEW-v0.1.md`; the deep design + end-to-end walkthrough is `references/architecture.md`.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
<!-- SPECKIT END -->
