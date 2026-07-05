# Changelog

All notable changes to `cc-local-loop` are documented here. Format: [Keep a Changelog](https://keepachangelog.com); versioning: [SemVer](https://semver.org).

## [0.2.0] — 2026-07-05
### Hardened (post-review — see `docs/REVIEW-v0.1.md`)
An expert Fable review (2 priming agents → 4 auditors → converging council → verification judge) audited v0.1.0 and
found a systemic *"safety-as-prose / fails-open-at-the-edges"* pattern. v0.2.0 makes the safety guarantees **real in
code**, verified by a 36-probe regression net (`tests/run-tests.sh`).

- **Fail-open safety fixed:** `OPENCODE_PERMISSION` is now `jq`-built valid JSON, assigned unconditionally (no env
  inheritance); `gate.sh` fails **CLOSED** (verified base required, non-repo dies, never emits `"status":"pass"`
  while its runner is unwired, reads committed+index+worktree+untracked); `freeze.sh` is portable on macOS
  (`shasum` fallback), `set -euo pipefail`, jq-built JSON, `-z` listing.
- **Protected-path bug fixed:** single-sourced, anchored `PROTECTED_PAT` in `common.sh` — top-level
  `tests/ specs/ .github/ pnpm-lock.yaml package.json …` are now caught by **both** freeze and gate.
- **Cross-family holes closed:** `judge.sh` now takes the impl model and calls `assert_cross_family`; a roster
  allow-list refuses Opus-as-implementer; `family_of` normalizes case + provider prefix.
- **Human-gate made mechanical:** a `.cc-local-loop/ACTIVE` marker — `dispatch.sh`, `judge.sh`, and the Stop hook
  refuse without it; `dispatch`/`judge` skill descriptions rescoped (no workflow-summary, scoped triggers) to stop
  trigger-suction into a bypass.
- **Real anti-Goodhart controls:** `scripts/promote-check.sh` whitelist gate + `.github/CODEOWNERS` + a
  `promotion-gate` CI workflow — the frozen yardstick can no longer be edited by the loop. The prose "enforced by…"
  claims are now backed by files.
- **Guards:** per-task iteration counter + **TIME budget** in `guards.sh` (numeric-validated, fail-closed on missing
  state).
- **Stop hook / preflight:** the hook records **only inside an active loop** (no cross-project pollution); preflight
  excludes the data plane from its clean-tree check, fails on unimplemented §15.5 keys (dev bypass
  `CCLL_ALLOW_SCAFFOLD=1`), and checks the calibration seeds.
- **Portability/config:** `NODE_AI_URL` defaults to `localhost` (overridable) — no hardcoded LAN IP; `hooks.json`
  quotes `${CLAUDE_PLUGIN_ROOT}` + adds a `timeout`.
- **Agents:** `distiller` is now **read-only** (returns the candidate; `reflect` appends it via
  `candidates-append.sh`); `grader` fails loud if the `skill-creator` harness is absent.
- **New files:** `using-cc-local-loop` router skill · `scripts/doctor.sh` (ENFORCED/PARTIAL/TODO matrix) ·
  `scripts/candidates-append.sh` · `tests/run-tests.sh` (36-probe regression net) ·
  `.github/{CODEOWNERS, workflows/ci.yml, workflows/promotion-gate.yml}` · calibration `seeds/*.diff`.
- **marketplace.json** `source` fixed to `"./"` (the install path now resolves); `$schema` added to both manifests.

### Still scaffold (TODO — gated by §15.5)
The node-ai calls (`dispatch.sh` / `judge.sh` two-pass), `gate.sh` stage-3 test runner, and the adversarial-test
sandbox remain `die`-guarded until the node-ai Option-B topology is deployed. Run `bash scripts/doctor.sh` for the
live matrix.

## [0.1.0] — 2026-07-05
### Added
- Initial plugin skeleton: Opus-orchestrated → local-model-executed dev loop, judge-only validation, cross-family gate invariant.
- Skills: `run-loop`, `dispatch`, `judge`, `reflect`, `promote-lessons`.
- Deterministic scripts: `harness/{freeze,gate,guards}.sh`, `dispatch.sh`, `judge.sh`, `preflight.sh`, `ledger-append.sh`.
- `Stop` hook → append run outcome to the ledger (fail-safe).
- Subagents: `distiller`, `grader`.
- Seed frozen calibration set + capped `lessons.md`.
- Repo doubles as its own marketplace (`.claude-plugin/marketplace.json`).
