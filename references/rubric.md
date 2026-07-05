# Judge rubric & protocol

The judge is a **pure function** (no tools). It returns `{verdict, score, violations[], adversarial_tests}`.

## Cross-family invariant (asserted before every judgment)

The family that implemented a change never gates it: Qwen-family output → **Gemma-4-31B-it**; Gemma-family output
→ **Qwen3.6-35B judge-mode**; numeric / architecture / security / Opus-authored / tiebreak-disagreement → **Opus**.
`dispatch.sh` / `judge.sh` enforce this via the family-map and abort fail-closed on a violation or unknown model.

## Protocol (model-independent)

- **Two passes.** Pass 1: free-form thinking review; emit adversarial tests as **fenced code blocks** (the harness
  extracts them — code never rides inside JSON). Pass 2: grammar-constrained JSON verdict only. Reuse KV between.
- **Primitive schema only** — enums / ints, no regex (JSON-Schema→GBNF fails on PCRE, llama.cpp #22314).
- **Behavioral Comparison** (lifts spec-conformance judging ~52% → 85%): extract the spec's I/O contract +
  boundaries → summarize what the code actually does → compare the two.
- **Pairwise, both orderings** when comparing candidates; require agreement (keep position bias ≤14%).
- Keep the implementer's full reasoning in the judged text.

## Verdict

- `verdict ∈ {APPROVE, REJECT, NO_CHANGE_NEEDED}`. **DONE = gates green AND APPROVE with no Critical/High violations.**
- The judge is a **soft veto**: it can block, it cannot approve alone (the deterministic gates are the hard floor).
- `violations[]` items carry a severity; **Critical/High block**.

## Context-pack (built by the harness, not the judge)

diff + **full post-image of every changed file** (not hunks — needed for laundering detection) + direct dependents
+ spec/acceptance criteria + the harness's test output. Assert it fits the judge's 32K KV; **oversize ⇒ escalate to
Opus**, never silently truncate (a truncated judge that rubber-stamps is a correctness failure).

## Adversarial tests

Run in an **ephemeral worktree copy** under the pinned runner. A non-compiling / collection-erroring test =
`JUDGE_TEST_INVALID` → **discard + log, never a task gate-fail** (the implementer is deny-globbed from test paths,
so a judge-test typo must not dead-end the no-progress guard). One bounded re-emit on compile error, then discard.
Judge-tests are evidence **inside** the verdict only — never in the frozen/held-out suites or the DoD conjunction.

## Fail-closed

Unparseable output / 5xx / Vulkan device-lost / `n_ctx` ≠ pinned ⇒ **REJECT as infra**, escalate + Magistral
cold-standby. **Never approve on error.**

## Calibrate before trusting

No public eval exists for a model *judging diffs*. Before production, run the frozen calibration set (§`evals/`) and
measure **catch-rate AND false-positive-rate** for the Gemma-31B judge — and a separate slice for Qwen judge-mode
before the first Gemma-26B batch.
