---
name: judge
description: >
  Runs the cross-family Gemma judge for cc-local-loop as a raw two-pass API call (no agent, no tools) that returns a
  structured verdict plus adversarial-test source the harness executes. Use when the run-loop needs to validate a
  diff after the deterministic gates pass, when judging code correctness / spec-conformance, or when deciding
  whether a task is DONE. Enforces the cross-family invariant and fails closed on any infra error.
---

# judge — the semantic gate (raw API, no harness)

The judge is a **pure function**: diff in → `{verdict, score, violations[], adversarial_tests}` out. It is NOT an
OpenCode agent and has NO tools. Invoke it through the script so the context-pack, two-pass protocol, and
fail-closed behavior are enforced:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/judge.sh" <judge_model> <base>
# judge_model is derived by the cross-family invariant, NOT chosen freely
```

## Cross-family invariant (mandatory)

- Qwen-family implementation (Ornith / Qwen) → judged by **Gemma-4-31B-it**.
- Gemma-family implementation (Gemma-26B) → judged by **Qwen3.6-35B in judge-mode** (never the 31B — same family).
- Anything Opus wrote, or numeric / architecture / security → **Opus judges**.
- Same-family review never satisfies the gate. The script asserts this and aborts if violated.

## What the script does

1. **Builds the context-pack:** the diff + **full post-image of every changed file** + direct dependents +
   spec/acceptance criteria + the harness's test output. Asserts it fits the judge's 32K KV; oversize ⇒ escalate to
   Opus (never silently truncate — a truncated judge that rubber-stamps is a correctness failure).
2. **Two passes:** pass 1 = free-form thinking review (emits adversarial-test source as fenced blocks); pass 2 =
   grammar-constrained JSON verdict only (primitive schema: enums/ints, no regex). The harness extracts the fenced
   tests — code never rides inside the JSON.
3. **Harness runs the emitted tests** in an ephemeral worktree copy. A non-compiling test = `JUDGE_TEST_INVALID` →
   discard + log, **never a task gate-fail** (the implementer can't edit test paths, so a judge-test typo must not
   dead-end the loop). A compiling-and-failing test ⇒ REJECT with the failure in the ADJUST payload.

## Fail-closed

Unparseable output / 5xx / Vulkan device-lost / `n_ctx` ≠ pinned ⇒ **REJECT as infra**, escalate + Magistral
cold-standby, **never approve on error**. Empty diff ⇒ explicit `NO_CHANGE_NEEDED` → Opus.

Judge rubric + protocol details: `${CLAUDE_PLUGIN_ROOT}/references/rubric.md`.
