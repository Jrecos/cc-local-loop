# Architecture

`cc-local-loop` is the packaged form of the design in the homelab repo's
`docs/ai-dev-orchestration-workflow.md` (**v11** — the canonical, council-validated spec). This file is the
stand-alone summary; the homelab doc is the source of truth for every decision, source, and trade-off.

## Invariant

`Opus 4.8 (Claude Code) → local models (node-ai) → Opus 4.8`. Opus plans + routes + reviews and **never writes
implementation code**. Local models implement + judge. The loop converges on a deterministic Definition of Done
**enforced in code (the harness), not by any model's opinion**.

## Roster (node-ai — GMKtec EVO X2, Ryzen AI Max+ 395, Radeon 8060S gfx1151, 128 GB)

- **Implementer pool** (routed per task): `ornith-35b` (agentic/refactor/tests) · `qwen3.6-35b`
  (algorithmic/frontend/reasoning) · `gemma-4-26b-a4b` (precision/spec, small scope + tiebreak).
- **Judge:** `gemma-4-31b-it` (raw two-pass API, thinking, persistent). Cold-standby judge: `magistral-small`.
- **Cross-family gate invariant:** the implementing family never judges its own output (see `rubric.md`).

## The loop (state machine, owned by the harness + Opus)

`route → freeze → implement (opencode run) → gate (harness) → judge (Gemma, raw API) → adjust → DONE`.
Stop rules (harness): MAX_ITER=6, no-progress (k=2), oscillation (last 4), **time budget (primary)**, token budget,
hash-mismatch tripwire, OpenCode crash. Sessions are separated; every ADJUST re-injects the full payload.

## Serving (node-ai "Option B")

Sequential `--parallel 1` (one model decodes at a time → full ~215 GB/s, no contention). Judge + its E2B draft are
**persistent**; implementers **swap** in the remaining ~44–48 GB. Queue sorted by model; Gemma-26B verdicts parked
for the Qwen residency window (~0 extra swaps). See homelab doc §8.1.

## Dispatch (why OpenCode, not raw claude -p)

Implementers run **inside OpenCode's harness** (per-agent permission engine, tools, session) via a **fresh
`opencode run` per task, no `--attach`**. OpenCode fails **loud** (a 400) where `claude -p` fails **silent**
(dropped thinking blocks). `claude -p` + `ANTHROPIC_BASE_URL`→node-ai is a tested fallback lane only. CCR and
opencode-mcp are interactive-only. See homelab doc §3.3 / §15.3 / §15.7 (build-vs-buy).

## Self-improvement (safe, 4 stages)

`collect (hook→ledger) → distill (reflect → quarantine) → gate (frozen calibration) → promote (human PR)`. The
environment gets sharper; the model stays the same. The loop never touches its own gates or yardstick. See homelab
doc §15.4.

## Reference

Full spec, sources, and council history: `homelab/docs/ai-dev-orchestration-workflow.md` (v11).
