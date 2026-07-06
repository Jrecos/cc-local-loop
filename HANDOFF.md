# Handoff — cc-local-loop

_A resume-from-here brief for continuing this plugin in Claude Code. As of 2026-07-05._

## What this project is

A Claude Code plugin that runs an autonomous dev loop — **Opus orchestrates → local models on `node-ai` implement → a cross-family judge gates → Opus reviews** — with a *safe, human-gated* self-improvement layer. Read `CLAUDE.md` first (especially the **G1–G8 guardrails** — they are the design), then `references/architecture.md` for the deep dive and E2E walkthrough. The design spec it implements is `~/Claude/Projects/homelab/docs/ai-dev-orchestration-workflow.md` (v11).

## Where things stand — v0.4.0

- **Green:** `bash tests/run-tests.sh` → **72/72 probes.** Manifests at 0.4.0. `bash scripts/doctor.sh` shows the ENFORCED/PARTIAL/TODO matrix.
- **Just landed (v0.4):** the **observability-only telemetry layer** + human-gated improvement cadence — `emit.sh` (validated event writer, one stream `events.jsonl`), `metrics.sh` + `metrics` skill (read-only report; cost is a *gauge*), `eval-run.sh` (proposer-only calibration cadence), `lessons-lint.sh` (G4 cap/provenance, fail-closed at preflight+promote-check+CI). Wired into `run-loop`, `reflect`, `promote-check`, `doctor`, `.gitignore`, CI. See `CHANGELOG.md` `[0.4.0]`.
- **How it got here:** the project's loop pattern — implement → gate → **Fable adversarial judge** → iterate. The v0.4 telemetry design was council-verified *before* build (ETH-Zurich lens), then two review rounds hardened it: the judges caught two silent dead-code bugs (`eval-run` delta never fired; `emit` events were forgeable) and one bug introduced by a fix (a single-line HTML comment blinded the lessons linter). All fixed + regression-probed.
- **Scaffold, on purpose:** `dispatch.sh` / `judge.sh` / `gate.sh` stage-3 are `die`-guarded until node-ai "Option-B" serving is deployed. Nothing fakes green.

## Commit status (updated 2026-07-05)

**v0.4.0 is already committed AND pushed** (`4d1c94b`, `origin/main` up to date) — the earlier "not yet pushed" note was stale (Cowork couldn't touch `.git`, but the tag landed since). This session added a macOS portability fix + doc sync on top:

- **Fixed (post-0.4):** `sandbox-run.sh` died on macOS when a docker/podman *binary* was present but the daemon was down (it `exec`'d into a dead runtime with no fallback), and its `env -i` fallback invoked a `timeout` that stock macOS doesn't ship. It now probes daemon liveness before committing via `exec`, resolves `timeout`/`gtimeout`, and degrades to a no-timeout-wall (loud WARN) instead of dying. New deterministic probe **15b** forces the fallback path regardless of runtime. Gate: **72/72** (was silently 70/71 on this box).
- **Uncommitted here:** new `CLAUDE.md` + `HANDOFF.md`, plus the `sandbox-run.sh` + `tests/run-tests.sh` fix. Commit on a green gate:

```bash
cd ~/projects/cc-local-loop
bash tests/run-tests.sh        # confirm 72/72
git add -A && git commit -m "fix(sandbox): macOS daemon-liveness + timeout fallback (probe 15b); docs" && git push
```

## What's next (in priority order)

1. **Deploy node-ai "Option-B" serving** (sequential `--parallel 1`, judge persistent, implementers swap, `--kv-unified`) in the `homelab` repo (`services/node-ai/`), then **un-scaffold** `dispatch.sh` / `judge.sh` and wire `gate.sh` stage-3 to a real project test runner. This is the gate between "hardened scaffold" and "live loop."
2. **Wire the grader** so `eval-run.sh` produces a real verdict instead of `result:"pending"` (needs the `skill-creator` eval harness + node-ai).
3. **v0.5 candidates** (already noted in code): have the harness scripts (`gate.sh`/`guards.sh`/`judge.sh`) call `emit.sh … harness` themselves (so telemetry authorship is fully deterministic, not orchestrator-relayed); optional redacted central store.
4. **First real dogfood run:** `claude --plugin-dir .` and run the loop on this repo itself once Option-B is up.

## How to brief Claude Code

> "This is my `cc-local-loop` Claude Code plugin — read `CLAUDE.md`, and treat the **G1–G8 guardrails** as hard invariants. After any change, `bash tests/run-tests.sh` must stay green (72/72) and new behavior needs a new probe. Telemetry scripts fail-safe (never add `set -e`); safety scripts fail-closed. Everything must stay portable to macOS bash 3.2. I want to work on **[node-ai Option-B wiring / the grader / v0.5 harness self-emit / …]**. Follow the loop: implement → run-tests → adversarial review → fix → re-gate."

## Guardrails

- **Don't weaken G1–G8** (see `CLAUDE.md`). If a change touches telemetry, lessons, dispatch, the judge, or promotion, re-read them.
- **`evals/calibration/**` is the frozen yardstick** — never edit it in-loop; expanding it is a separate, explicit human PR.
- **Keep it honest:** a scaffold that `die`s is correct; a scaffold that fakes a green result is a bug.
