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

**Field-benchmark notes (Strix-Halo class; homelab ADR #15).** A DGX-Spark bench of our exact model stack surfaced:
(a) if we ever re-enable parallelism, **`--kv-unified` is mandatory** — a bare `-np N` silently splits llama.cpp's KV
cache (~30% per-stream penalty); (b) llama.cpp defaults to **4 slots** — concurrency >4 queues silently (our old
"15 t/s" artifact); (c) **speculative decoding is a latency tool, not throughput** → the E2B draft earns its keep on
the *persistent, low-concurrency judge*, not on batched implementers; (d) quant ladder Q8 → Q4 ≈ +30% single-stream.
**NVFP4 / vLLM / AEON / MTP are CUDA-only — not applicable on our Vulkan/RADV.** Parallel serving stays a documented
future option (the same box class does 546–648 tok/s aggregate across a swarm when tuned).

## Dispatch (why OpenCode, not raw claude -p)

Implementers run **inside OpenCode's harness** (per-agent permission engine, tools, session) via a **fresh
`opencode run` per task, no `--attach`**. OpenCode fails **loud** (a 400) where `claude -p` fails **silent**
(dropped thinking blocks). `claude -p` + `ANTHROPIC_BASE_URL`→node-ai is a tested fallback lane only. CCR and
opencode-mcp are interactive-only. See homelab doc §3.3 / §15.3 / §15.7 (build-vs-buy).

## Self-improvement (safe, 4 stages)

`collect (hook→ledger) → distill (reflect → quarantine) → gate (frozen calibration) → promote (human PR)`. The
environment gets sharper; the model stays the same. The loop never touches its own gates or yardstick. See homelab
doc §15.4.

## End-to-end example — one feature through the loop

**Scenario:** a repo has `specs/003-token-refresh.md` and a `tasks.md` with `- [ ] T012 [route:O]
[scope:src/auth/token.ts] [ac:FR-003] [esc:F@2]`. FR-003 says an expired token must refresh once, then fail closed.

**You type:** `/cc-local-loop:run-loop tasks.md`

```
① PREFLIGHT + ARM
   $ scripts/preflight.sh
     OK  : git repo · node-ai reachable · git tree clean · calibration seeds present
     (all §15.5 keys green — CCLL_ALLOW_SCAFFOLD unset)  → preflight passed
   $ : > .cc-local-loop/ACTIVE            # arms dispatch/judge/hook (mechanical human-gate)

② ROUTE  T012 → agentic auth patch → impl=ornith-35b ; judge=gemma-4-31b-it (cross-family: qwen≠google) ✓

③ FREEZE (once)
   $ scripts/harness/freeze.sh
     froze 7 protected files @ a1b2c3d4e5f6 → .cc-local-loop/frozen.json
     (tests/**, specs/**, package-lock.json, .github/**, tasks.md hash-pinned — the anti-tamper spine)

④ IMPLEMENT  (Ornith, inside OpenCode's harness; scope = src/auth/token.ts only; lessons.md injected)
   $ scripts/dispatch.sh ornith-35b T012
     dispatch: impl=ornith-35b judge=gemma-4-31b-it task=T012 (fresh opencode run, no --attach)
     → OpenCode edits src/auth/token.ts (cannot touch tests/ or specs/ — permission-denied)

⑤ COMMIT  git add -A && git commit -m "wip(T012)"     # so the gate/judge can see the diff

⑥ GATE
   $ scripts/harness/gate.sh <base>
     {"status":"fail","failing":["tests: token refresh retried twice (FR-003: refresh ONCE)"]}
   → a frozen test caught a real bug. On to guards.

⑦ GUARDS  $ scripts/harness/guards.sh T012
     {"decision":"CONTINUE","iter":1,"elapsed_s":48}    # under MAX_ITER=6 and the TIME budget

⑧ ADJUST  re-dispatch Ornith with the failing-test output + the full payload (§7 contract)
   → fixes the retry guard.  COMMIT → GATE → {"status":"pass"}  ✓

⑨ JUDGE
   $ scripts/judge.sh ornith-35b gemma-4-31b-it <base>
     {"verdict":"APPROVE","score":0.94,"violations":[],"adversarial_tests":"…refresh-once, expired-then-fail…"}
   → harness runs the judge's adversarial tests in a sandbox → all green.

⑩ DONE  = gate green AND judge APPROVE, no Critical/High. Opus reviews the bounded report (git diff + test tail +
   verdict JSON), not the executor transcript → ~5–10× fewer paid Opus tokens.
```

**Feature end → learn (optional, safe):**

```
$ rm -f .cc-local-loop/ACTIVE                          # disarm the loop
/cc-local-loop:reflect
  → ledger shows the same failing-gate signature ("retry-once") on T012 + two earlier tasks (≥3) →
    distiller (read-only) returns ONE candidate lesson → quarantined in candidates.jsonl. Nothing goes live.

/cc-local-loop:promote-lessons cand_042        (human-started)
  → grader runs it against the FROZEN calibration set (≥5 reps): non-regression ✓ + fixes its RED case ✓
  → scripts/promote-check.sh <branch>          # whitelist gate: PR touches ONLY references/lessons.md ✓
  → opens a PR adding one bullet to lessons.md with evidence  →  YOU merge it.
```

The next run injects the improved `lessons.md`. **The environment got sharper; the model never changed.**

> **Today (v0.2 scaffold):** steps ④ and ⑨ `die` until node-ai Option-B is deployed (§15.5); `bash scripts/doctor.sh`
> shows exactly what is ENFORCED vs TODO. The routing, freeze, scope-gate, hash-verify, guards, cross-family assert,
> and the whole feedback-loop containment are already live and code-enforced.

## Reference

Full spec, sources, and council history: `homelab/docs/ai-dev-orchestration-workflow.md` (v11).
