# Changelog

All notable changes to `cc-local-loop` are documented here. Format: [Keep a Changelog](https://keepachangelog.com); versioning: [SemVer](https://semver.org).

## [Unreleased]
### Fixed — sandbox-run.sh macOS portability
- `sandbox-run.sh` no longer dies when a docker/podman **binary** is present but its **daemon is down**: it now probes
  daemon liveness (`docker info` / `podman info`) *before* committing via `exec`, so a dead runtime falls through to the
  `env -i` fallback instead of `exec`-ing into a broken socket.
- The fallback no longer assumes a host `timeout`: stock macOS ships none, so it resolves `timeout`/`gtimeout` (passing the
  binary's dir on `PATH`, since `env -i` wipes it) and degrades to a **no-timeout-wall** with a loud WARN rather than failing.
- New deterministic probe **15b** forces the fallback path (`CCLL_SANDBOX_RUNTIME=none`) regardless of runtime. Gate **71 → 72**.

## [0.4.0] — 2026-07-05
### Added — observability-only telemetry + a human-gated improvement cadence
A design council (Fable, under the ETH-Zurich lens) verified the layer *before* build, then the same loop
(implement → gate → Fable judge → fix → re-judge) hardened it across two review rounds. Regression net grew **49 → 71 probes**.
- **`emit.sh`** — a **validated** event writer feeding ONE stream (`.cc-local-loop/ledger/events.jsonl`). Whitelisted event
  names, byte-accurate ≤8KB cap, single-JSON-object only, and an **envelope that wins over the payload** so a caller can't
  forge `event`/`run_id`/`source` (G8). Always exits 0 — telemetry never kills the loop.
- **`metrics.sh` + skill `metrics`** — **read-only** report (accepted changes, escalation rate, judge/gate rates, lesson
  funnel, cost-per-accepted-change as a **gauge, never a target** — G6). Resilient per-line parse: one torn/scalar line
  can't blank the report. **Never injected into a prompt (G1).**
- **`eval-run.sh`** — the improvement **cadence** unit (cron/launchd/Routine calls the *script*, not a skill). Re-runs the
  **frozen** calibration set → per-run snapshot → `eval_delta` events. **PROPOSER only** — it never promotes or opens a PR (G3).
- **`lessons-lint.sh`** — mechanical **cap** (≤15 bullets / ≤2K tokens) + **provenance** (ID **and** `[seed]`/`[cand_]`) + header
  sentinel, **fail-closed**, wired at **preflight + promote-check + CI** (G4). Indented/`*`/`+` bullets and above-heading
  content can't evade it; an awk comment-stripper (not a `sed` range that runs to EOF).
- **Wiring:** `run-loop` step 0 stamps `CCLL_RUN_ID` (persisted for the Stop hook's `run_end`) and emits `run_start`; step 7
  relays each harness script's own JSON verbatim. `reflect` mines `events.jsonl` (+ the `eval_delta` evidence class).
  `promote-check.sh` enforces **additive-only** promotions (blocks a wholesale-rewrite delete). `PROTECTED_PAT` now covers
  `evals/calibration/` so the yardstick is mechanically un-editable in-loop. Portable ledger locking (macOS has no `flock`).
- **Data plane:** `.gitignore` / `.git/info/exclude` now exclude the directory's **contents** with a carve-out
  (`!.cc-local-loop/promoted.jsonl`) so a lesson-promotion PR can carry its audit trail. `doctor.sh` gains 4 rows.
### Guardrails (G1–G8)
G1 one injected memory file (telemetry never in a prompt) · G2 schema-pinned state · G3 cadence proposes, humans promote ·
G4 mechanical lessons-lint · G5 additive deltas only · G6 frozen set is the arbiter, cost is inert · G7 retention split ·
G8 deterministic telemetry authorship.

## [0.3.0] — 2026-07-05
### Added — field-benchmark hardening (from two write-ups: a Strix-Halo-class serving bench + a loop-engineering roadmap)
Implemented and verified by the same review loop (implement → gate → Fable judge → fix → re-gate). Regression net grew **36 → 49 probes**.
- **`guards.sh` circuit breaker:** per-task **no-progress** (identical failing signature ×2), **oscillation** (a signature repeating within the last 4), and a **liveness heartbeat** — on top of MAX_ITER + TIME. Portable (bash 3.2 / macOS).
- **`sandbox-run.sh`:** runs model-authored tests with **`--network none --read-only`** (prompt-injection defense), with an `env -i` + `timeout` fallback. Closes review finding **F5**; the judge lane runs its adversarial tests here.
- **`build-context.sh`:** a **narrow, token-budgeted** iteration context (state + the one open failure + only its stack-trace / last-diff **tracked** files). Rejects absolute / `..` / out-of-repo paths — **no exfiltration** (a bug the Fable judge caught: a `../secrets.py` in model-influenced failure text was embeddable; now blocked + regression-probed).
- **`state.sh`:** two-level state — human `STATUS.md` + machine `loop_state.json`.
- **`check-idempotency.sh`:** runs the gate N× on one state and aborts if non-deterministic (a flaky check breaks the stop condition).
- **`doctor.sh`** matrix: stop-rules / narrow-context / two-level-state / check-idempotency now **ENFORCED**; adversarial-test sandbox **PARTIAL**.
### Docs
- The homelab spec records the infra findings (decisions ADR #15): **`--kv-unified`** (avoid the ~30% split-KV penalty), the default-slots-as-a-queue trap, spec-decode = a *latency* tool (validates the E2B draft for the persistent judge), the quant ladder. **NVFP4 / vLLM / AEON / MTP are CUDA-only — not applicable on our Vulkan/RADV.**

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
