<!--
SYNC IMPACT REPORT — cc-local-loop Constitution
================================================
Version change: (uninitialized template) → 1.0.0  [INITIAL RATIFICATION]
Rationale: First concrete constitution. Prior file was the unfilled template
(all [PLACEHOLDER] tokens). Principles distilled from the project's existing
authoritative guardrail spec in CLAUDE.md (G1–G8 + core invariants) and
references/architecture.md, cross-referenced to the enforcing scripts so each
principle is code-testable, not aspirational.

Principles established (7):
  I.   Fixed Roles: Opus Thinks and Reviews, Local Models Implement
  II.  Done Is Defined in Code, Measured Against a Frozen Yardstick (G6)
  III. One Injected Memory; Everything Else Is Observability-Only (G1)
  IV.  Improvement Is Human-Gated, Additive, and Capped (G3/G4/G5/G7)
  V.   Safety Lives in Scripts; Fail-Closed and Fail-Safe Are Deliberate (G2/G8)
  VI.  The Regression Gate Is the Review Contract
  VII. Two Planes Stay Separate; Everything Is Portable

Sections established:
  - Additional Constraints (spec sync, scaffold honesty, marketplace, security posture)
  - Development Workflow & Quality Gates
  - Governance

Removed sections: none (initial fill).

Template / artifact consistency:
  ✅ .specify/templates/plan-template.md — Constitution Check gate references the
     constitution dynamically ("[Gates determined based on constitution file]");
     it surfaces all 7 principles at plan time. No edit required.
  ✅ .specify/templates/spec-template.md — no constitution coupling. No edit required.
  ✅ .specify/templates/tasks-template.md — generic "Tests are OPTIONAL" default
     intentionally retained for template reusability; Principle VI + the plan-time
     Constitution Check make probe tasks MANDATORY for code-plane changes. The
     override is stated in Principle VI and Governance rather than by editing the
     generic template.
  ✅ Command templates — none present (.specify/templates/commands absent). The
     speckit command skills under .claude/skills/ are Spec Kit-managed; unmodified.
  ✅ Runtime guidance — CLAUDE.md and references/architecture.md are the SOURCES this
     constitution was derived from; consistent by construction. README.md reviewed,
     no contradiction.

Deferred / follow-up TODOs:
  - RATIFICATION_DATE set to 2026-07-05 (date of first adoption). If you prefer to
    anchor ratification to project inception (v0.1.0, commit 6240909), edit the date
    and bump LAST_AMENDED_DATE accordingly.
  - Optional: add a one-line pointer to this constitution from the top of CLAUDE.md.
-->

# cc-local-loop Constitution

## Core Principles

### I. Fixed Roles: Opus Thinks and Reviews, Local Models Implement

The loop's division of labor is fixed and MUST NOT be inverted: Claude Code (Opus 4.8)
orchestrates and reviews; local models on `node-ai` (via OpenCode) implement; a judge
gates. Opus MUST NOT act as a local implementer — it may re-judge its own output only on
explicit escalation. The model family that implemented a change MUST NEVER judge that
change; this is enforced by `assert_cross_family` / `assert_impl_allowed` in
`scripts/lib/common.sh`, not by convention.

Rationale: paying for Opus only to *think and review* — while free local hardware does the
high-volume implementation — is the plugin's entire cost thesis. Cross-family judging is
what stops a model from rubber-stamping its own work; making it a code-enforced invariant
rather than a guideline is what makes the result trustworthy.

### II. Done Is Defined in Code, Measured Against a Frozen Yardstick (G6)

"Done" MUST be decided by mechanical gates against a frozen calibration set, never by a
model's opinion. `evals/calibration/**` (the seeded-bug yardstick) is the sole arbiter of
quality and MUST remain un-editable in-loop — protected by `PROTECTED_PAT` and CODEOWNERS.
`cost-per-accepted-change` is a gauge for humans, NEVER an optimizer target; no code path
may branch on it.

Rationale: a loop that grades itself drifts toward whatever is cheapest to satisfy. An
external, frozen, human-owned yardstick is the only arbiter that cannot be gamed from
inside the loop.

### III. One Injected Memory; Everything Else Is Observability-Only (G1)

Exactly one artifact — `references/lessons.md` — may ever be injected into an implementer
or judge prompt. All telemetry (`.cc-local-loop/ledger/events.jsonl`, metrics, eval
snapshots, candidates) is observability-only and MUST NEVER enter a prompt.
`scripts/build-context.sh` MUST deny the data plane.

Rationale: the ETH-Zurich finding (arXiv 2602.11988) that LLM-generated injected context
*reduces* task resolution (~-3%) while inflating cost (~+20%). Telemetry is for humans to
observe, not for the model to consume; conflating the two is the exact failure mode this
plugin exists to avoid.

### IV. Improvement Is Human-Gated, Additive, and Capped (G3/G4/G5/G7)

Self-improvement MUST follow one shape: the cadence proposes, humans promote.
`scripts/eval-run.sh` may measure and propose but MUST NEVER edit `lessons.md`, promote a
lesson, or open a PR (G3). `references/lessons.md` is mechanically capped (≤15 bullets /
≤2K tokens) with required provenance, enforced FAIL-CLOSED by `scripts/lessons-lint.sh` at
preflight, at promote-check, AND in CI (G4). A promotion MUST be additive or a single
amendment; wholesale rewrites are rejected by `scripts/promote-check.sh` (G5).
Observability may grow unbounded but is never injected; candidates are budgeted; lessons
are capped (G7).

Rationale: unbounded, self-authored memory is precisely the failure mode named in
Principle III. Every entry into the one injected memory must survive both a human and a
mechanical gate.

### V. Safety Lives in Scripts; Fail-Closed and Fail-Safe Are Deliberate (G2/G8)

Safety-critical logic MUST live in `scripts/` (bash), never in skill prose — skills
orchestrate and *call* scripts; they MUST NOT reimplement a gate in prose. Safety-path
scripts (`gate.sh`, `judge.sh`, `promote-check.sh`, `lessons-lint.sh`, `freeze.sh`,
`build-context.sh`) MUST fail CLOSED: `die` on any doubt, never fake a pass. Telemetry
scripts (`emit.sh`, `ledger-append.sh`) MUST fail SAFE: always `exit 0` so telemetry can
never kill the loop, and MUST NOT use `set -e`. State is schema-pinned and overwrite-only:
`emit`/`metrics` MUST NOT write `loop_state.json` (G2). Telemetry authorship is
deterministic — `emit.sh`'s envelope (`event`/`run_id`/`source`) wins over the payload, so
a caller cannot forge an event (G8). Unwired paths MUST be `die`-guarded, never faked
green: the plugin verifies its cage before entering it.

Rationale: the two `set` modes are the difference between a loop that stops safely and one
that either lies about success or dies on a routine log write. Keeping safety in tested
scripts (not prose) is what lets the regression net actually enforce it.

### VI. The Regression Gate Is the Review Contract

`bash tests/run-tests.sh` MUST pass (currently 72/72 probes) after every change. Any new
script or new behavior MUST ship a probe in the same change — the regression net IS the
review contract, the auditor probes made executable. `PROTECTED_PAT` in
`scripts/lib/common.sh` is the single source of truth for protected paths and MUST be
edited nowhere else. This gate is mandatory for all code-plane changes and SUPERSEDES the
generic "tests are optional" default of the task template.

Rationale: guardrails that are not tested are aspirational. The gate is what makes every
other principle real; untested safety is indistinguishable from no safety.

### VII. Two Planes Stay Separate; Everything Is Portable

The code plane (this repo — versioned, shared) and the data plane (`.cc-local-loop/**`,
written into the target project at runtime) MUST NOT mix. The data plane MUST stay out of
the target repo (via `.git/info/exclude`), with the deliberate exception of
`promoted.jsonl`, re-included so a lesson-promotion PR carries its audit trail. Every
script MUST run unmodified on macOS (bash 3.2 / BSD userland) AND Linux (GNU): no GNU-only
flags, no `sed -i`, no `date -d`; use the established portable idioms
(`wc -c | tr -d ' '`, the `sha256` `shasum` fallback, `awk` state machines, quoted
expansions).

Rationale: the loop runs across heterogeneous homelab hardware and writes into arbitrary
target repos. A script that works on only one platform is a latent outage; telemetry that
leaks into a user's git history is a privacy breach.

## Additional Constraints

**Spec parity.** This plugin is the running implementation of the homelab design spec
`ai-dev-orchestration-workflow.md` (v11). Code and spec MUST be kept in sync; a change that
diverges from the spec MUST either update the spec or be rejected.

**Scaffold honesty.** `scripts/doctor.sh` is the live ENFORCED / PARTIAL / TODO matrix and
the source of truth for what is actually wired. Nothing may fake green. The node-ai calls
(`dispatch.sh`, `judge.sh`) and `gate.sh`'s stage-3 test runner remain `die`-guarded until
the node-ai "Option-B" serving topology is deployed (homelab spec §15.5);
`eval-run.sh` records `result:"pending"` until the grader is wired.

**Marketplace dual-role.** The repo doubles as its own marketplace
(`.claude-plugin/marketplace.json`, `source: "./"`). A version bump MUST update BOTH
`.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

**Security posture.** Test isolation runs under `sandbox-run.sh` (`--network none`).
Secrets MUST NEVER be written to telemetry or to `lessons.md`. Protected paths (tests,
specs/SDD, CI, lockfiles, `tasks.md`, `evals/calibration/`) are governed exclusively by
`PROTECTED_PAT`.

## Development Workflow & Quality Gates

The project's iteration loop is: **implement → `bash tests/run-tests.sh` (gate) →
adversarial review → fix → re-gate.** Concretely:

- Every change MUST leave the gate green (72/72) and MUST add a probe for any new script or
  behavior, in the same change.
- The full script surface MUST pass `bash -n`; `shellcheck -S warning` is advisory (CI runs
  it non-blocking).
- Manifests and calibration JSON (`.claude-plugin/*.json`, `hooks/hooks.json`,
  `evals/calibration/cases.json`) MUST validate with `jq`.
- A change that touches telemetry, lessons, dispatch, the judge, or promotion MUST keep the
  corresponding G1–G8 probe(s) passing. Weakening a guardrail is out of scope for ordinary
  work and requires a constitutional amendment (see Governance).
- Review and design context: `docs/REVIEW-v0.1.md` (the expert review that shaped current
  hardening) and `references/architecture.md` (deep design + end-to-end walkthrough).

## Governance

This constitution supersedes ad-hoc practice. Where it and `CLAUDE.md` overlap, they MUST
agree: this file is the governing law; `CLAUDE.md` is its operational elaboration and
`references/architecture.md` is the design rationale.

The G1–G8 guardrails and the fixed-roles / cross-family invariants are **constitutional
invariants**. Weakening, removing, or redefining any of them MUST be done only through an
explicit constitutional amendment — a written rationale, human approval, a version bump,
and the corresponding regression probe updated in the SAME change. It MUST NEVER be done as
an in-loop change.

Amendment procedure: propose → human review → update this file plus any affected templates
and probes → bump the version per the policy below → keep the gate green.

Versioning policy (semantic versioning for this constitution):

- **MAJOR** — a guardrail or invariant removed or redefined in a backward-incompatible way.
- **MINOR** — a new principle or section added, or existing guidance materially expanded.
- **PATCH** — clarifications, wording, and non-semantic refinements.

Compliance is verified mechanically: every change is checked by `bash tests/run-tests.sh`
and `bash scripts/doctor.sh`; CI re-runs the gate and `scripts/lessons-lint.sh`. A change
that cannot keep the gate green is non-compliant by definition. Runtime development guidance
lives in `CLAUDE.md` and `references/architecture.md`.

**Version**: 1.0.0 | **Ratified**: 2026-07-05 | **Last Amended**: 2026-07-05
