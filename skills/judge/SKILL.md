---
name: judge
description: >
  Runs the cross-family judge on ONE cc-local-loop diff after the deterministic gates pass. Use ONLY at the
  run-loop's judge step, when re-judging after an ADJUST round, or to check whether a loop task meets the loop's
  Definition of Done. Scoped to cc-local-loop runs — NOT a general code-review or "is my task done" skill. Always
  invoked via scripts/judge.sh, which fails closed on infra errors; never approve a diff by reading it directly.
---

# judge — the semantic gate (raw API, no harness)

The judge is a **pure function**: diff in → `{verdict, score, violations[], adversarial_tests}` out. Not an
OpenCode agent, no tools. Always go through the script so the cross-family assert, two-pass protocol, and
fail-closed behavior hold:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/judge.sh" <impl_model> <judge_model> <base>
# judge_model is DERIVED from the cross-family invariant, not chosen freely
```

## Cross-family invariant (asserted in the script, fail-closed)

Qwen-family impl (Ornith/Qwen) → **Gemma-4-31B**; Gemma-family impl (Gemma-26B) → **Qwen judge-mode**; Opus /
numeric / architecture / security → **Opus judges**. Same-family review never satisfies the gate. `judge.sh` takes
the impl model precisely so it can assert this and abort. Full protocol: `references/rubric.md`.

## What the script does (load-bearing invariants)

- **Context-pack** = diff + full post-image of changed files + spec/AC + harness test output; asserts it fits the
  judge 32K KV, else escalates to Opus (never truncates).
- **Two passes:** free-form (fenced adversarial tests) → grammar-JSON verdict. The harness runs the emitted tests via
  `"${CLAUDE_PLUGIN_ROOT}/scripts/sandbox-run.sh"` (a `--network none --read-only` container, or an `env -i` + timeout
  fallback) — model-authored code never touches your network or files outside the workdir. Non-compiling ⇒
  `JUDGE_TEST_INVALID` (discard, never a gate-fail).
- **Fail-closed:** infra error / unparseable / device-lost ⇒ **REJECT + escalate** (exit 2), never approve on error.
  Empty diff ⇒ `NO_CHANGE_NEEDED` → Opus.

> **Scaffold (v0.3):** `judge.sh` refuses to run (`die`) until node-ai Option-B (Gemma-31B + E2B draft) is deployed
> and the two-pass call is wired (§15.5). It already asserts cross-family and fails closed on the health check.
