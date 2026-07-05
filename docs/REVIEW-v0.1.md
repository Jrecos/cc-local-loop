# cc-local-loop v0.1.0 — Expert Review

**Method:** a looped Fable review — 2 priming agents built the expert base (official 2026 plugin/skill/hooks spec + best-practices/anti-patterns/security), then **4 expert auditors** (spec/structure · skill-quality/triggering · loop-safety · security/robustness) audited the repo — **many findings empirically verified by running the scripts** — and a **converging council** validated severities, deduped, and prioritized. **Loop verdict: CONVERGED** (mutually consistent, empirically grounded, zero false positives → proceed to remediation, not another audit round).

---

## Executive summary

The **architecture is genuinely well-designed** — correct human-gating on `run-loop`/`promote-lessons`, a fail-closed judge stub, honest `die` scaffolds on both model-touching scripts, and a quarantine-first improvement design. But the review converged on **one systemic pattern in two flavors**:

1. **Safety that exists only as prose** — 3 of 5 `gate.sh` stages fake `"status":"pass"`; 6 of 7 stop rules are absent but described as facts; phantom `CODEOWNERS`/whitelist controls; a "ONE injected memory file" (`lessons.md`) that nothing injects; a ledger whose schema can't feed its own miners.
2. **The safety code that does exist fails open at its edges** — a deny-map truncated into invalid JSON by bash brace-parsing; leading-slash regexes that miss top-level `tests/`, `specs/`, `.github/`; a gate that passes on git errors, one-commit repos, and can't see uncommitted (or *any*) implementer work; a freeze that's silently hollow on the author's own macOS.

**Between this repo and its own stated contract: 7 T0 items (~half a day) and 11 T1 items.** The single most important fix: **make `gate.sh` fail closed and honest** — refuse to emit `"status":"pass"` while its stages are TODO and its base is unverifiable — because the whole Definition of Done ("gates green AND judge approves") currently rests on a gate that is green by default.

> The `die` scaffolds in `dispatch.sh`/`judge.sh` mean **nothing dangerous runs today** — this is a review of a scaffold against its intended contract, so the CRITICALs are "critical relative to purpose," disarmed until those guards are removed. That's exactly the right time to fix them.

---

## Master findings (severity-ranked, deduped)

Legend: **[V]** = empirically verified by running the code. Locations are `file:line`.

### CRITICAL

| # | Location | Issue | Fix |
|---|---|---|---|
| **B1** [V] | `scripts/dispatch.sh:15` | `OPENCODE_PERMISSION` default is **malformed JSON** — inside `${VAR:=…}` the `}` closing glob `{test,spec}` terminates the expansion → exported `{"edit":{"*":"deny","**/*.{test,spec` → jq-invalid → OpenCode falls open. (ShellCheck SC2089/90.) | Build with `jq -n`/single-quote; assign unconditionally (no `:=`); `jq -e` validate before export. |
| **B3** [V] | `gate.sh:11`, `freeze.sh:9` | Protected-path regexes require a **leading `/`** → top-level `tests/`, `specs/`, `.github/`, `__tests__/`, `e2e/` MISS in both scope-gate and freeze (the canonical layouts). Gate also omits lockfiles/`package.json` entirely. | Anchor `(^\|/)`; single-source the pattern (B8). |
| **B4** [V] | `gate.sh:6,10` | Gate **fails OPEN**: git error / bad base / default `HEAD~1` (misses earlier commits, malformed on 1-commit repos) / uncommitted-worktree tamper invisible (`base..HEAD` only). | Require explicit verified base; `die` outside a repo / on git error; include worktree + index. |
| **B5** [V] | `gate.sh` (whole) | Gate **fakes success** — hash-verify, lint/type/build, frozen-tests, coverage are TODO comments but it still emits `{"status":"pass"}` exit 0, while the skills describe all stages in present tense. Violates the repo's own "fail loud" rule. | Emit `unimplemented` + non-zero until stages are wired; never `pass` from a gate that didn't gate. |
| **D1** [V] | `promote-lessons/SKILL.md:32`, `evals/calibration/README.md:5` | Anti-Goodhart controls **don't exist as code** — no CODEOWNERS, no `.github/`, no CI, zero `whitelist` logic (grep-confirmed) — yet both files claim they're "enforced". The frozen-yardstick guarantee is 100% prose addressed to an LLM. | T0: fix the claim ("TODO"). T2: ship `promote-check.sh` + CODEOWNERS + CI path-guard. |
| **E1** [V] | `dispatch`/`judge` `SKILL.md` frontmatter | **Human-gate bypass via trigger suction.** `run-loop` is correctly gated, but `dispatch`/`judge` are model-invocable with workflow-summarizing, generic descriptions ("implement this with local models", "whether a task is DONE") → a user phrase auto-triggers `dispatch` → runs with **no preflight/freeze/gate/judge** (and today already curls the hardcoded LAN IP before the `die`). | Rescope+redirect the descriptions; add a mechanical `.cc-local-loop/ACTIVE` marker that `dispatch.sh`/`judge.sh` require. |
| **A1** [V] | `.claude-plugin/marketplace.json:14` | `"source":"."` is invalid (must be `"./"`) → the README install path breaks at resolution. Plugin `--strict` validate passes; **marketplace validate fails**. | `"source":"./"`. |

### HIGH

| # | Location | Issue | Fix |
|---|---|---|---|
| **NEW-1** | `run-loop/SKILL.md`, `gate.sh`, `judge.sh` | **The pipeline can't see its own work.** Implementer has "no git"; gate/judge look at `base..HEAD` (committed only); nobody commits between implement and gate → empty diff → trivial PASS / `NO_CHANGE_NEEDED`. | Harness-owned `git add -A && git commit` after dispatch, or worktree-aware gate/judge (also closes B4). |
| **B2** [V] | `dispatch.sh:15` | `:=` honors a **pre-set** `OPENCODE_PERMISSION` → a permissive value from `.envrc`/interactive/poisoned CLAUDE.md silently replaces the deny-map. | Construct in-script unconditionally; if override is a feature, assert protected denies present. |
| **B6** [V] | `freeze.sh:9,13` | **Silently hollow on macOS (author's platform):** `sha256sum` absent (Darwin has `shasum`); no `set -e` → empty hashes, logs "froze N", exit 0. Also misses `pnpm-lock.yaml`, drops quoted/non-ASCII filenames, string-concat JSON. | `set -euo pipefail`; `shasum -a 256` fallback; `git ls-files -z`; `jq -n`. |
| **B7** [V] | `guards.sh:5-9` | Only MAX_ITER; counts **cumulative global ledger lines** (not per-task) → any 6 sessions ⇒ permanent ESCALATE; missing/bad ledger ⇒ CONTINUE forever; non-numeric var ⇒ CONTINUE. 6/7 stop rules (incl. the "primary" TIME budget) are TODO. | Per-task counter; numeric-validate; missing ledger ⇒ ESCALATE; implement TIME budget first. |
| **C1** [V] | `judge.sh:5` | Signature `<judge_model> <base>` never learns the impl model, **never calls `assert_cross_family`** — yet rubric + skill claim it enforces cross-family. | `judge.sh <impl_model> <judge_model> <base>` + assert. |
| **C2** [V] | `dispatch.sh:8-10` | `IMPL=opus*` → Gemma judge → assert **PASSES** — the forbidden "Opus-authored → Opus judges" pairing. Also accepts non-roster models. | Roster allow-list + refuse Opus-as-implementer. |
| **D2** [V] | `evals/calibration/seeds/` | Yardstick has **no artifacts** (`.gitkeep` only); 3 cases reference missing `seeds/*.diff`; no code verifies `benchmark.json` → grader could fabricate results. | Author the seed diffs; artifact + benchmark existence/schema checks. |
| **D3** [V] | `references/lessons.md`, execution path | `lessons.md` ("the ONE injected memory file") is **never injected** — nothing on the implement path reads it. The reflect→promote subsystem improves a file nothing consumes. | Inject `lessons.md` into the dispatch context-pack. |
| **D4** [V] | `ledger-append.sh:10` vs `reflect`/`distiller` | **Ledger schema is fiction:** hook writes `{run_id,ts,git_sha,outcome:"recorded",source}`; miners need `{task_id,gate_results,judge,retries,escalation,…}` → evidence patterns unminable → distiller extracts "patterns" from vibes. | Harness emits structured per-task rows; reflect refuses if fields absent. |
| **E2/E3** [V] | `dispatch`/`judge` descriptions | Workflow summarized in descriptions (agent follows summary, skips body); generic triggers collide with the user's **installed `task-closure`** skill ("task is done / márcala como hecha"). | Strip mechanism; scope every trigger to "a cc-local-loop diff / loop task". |
| **E4** | `agents/grader.md`, `promote-lessons` | Grader ordered to reuse the `skill-creator` harness but has no Skill tool, no path, undeclared dependency → flounders or reimplements (forbidden). | Pin the concrete invocation; declare the dependency; fail loud if absent. |
| **F1** [V] | `hooks/hooks.json`, `ledger-append.sh` | **Stop hook unconditional** → fires in every project → creates `.cc-local-loop/` everywhere and then **`preflight.sh` fails "tree not clean" on the loop's own data plane** (self-deadlock after run #1). | Gate the hook on `.cc-local-loop/ACTIVE`; exclude the data plane from the clean-tree check. |
| **F4** [V] | `scripts/lib/common.sh:5` | `NODE_AI_URL` defaults to hardcoded private IP `192.168.0.87:8080` → any installer curls a stranger; once wired, **source + diffs POSTed over plain HTTP** to whatever answers. | Require via `:?` (or default localhost); document the no-auth/plain-HTTP homelab assumption. |
| **F5** | `judge.sh:14`, `rubric.md:34` | Judge-emitted (model-authored) tests run in a worktree that isolates **repo state, not the process** (same user/network/$HOME). | `env -i`, no network, ulimits/timeout, scratch HOME. |
| **B8** [V] | `gate.sh` vs `freeze.sh` | Three divergent hand-copied protected-path definitions — root cause of B3/B6. | Single `PROTECTED_PAT` in `common.sh`, consumed everywhere. |

### MEDIUM

`D5` agents granted `Bash` despite "read-only" contracts; cap-lint/decay/provenance prose-only · `E5` present-tense claims for unimplemented behavior in `judge`/`run-loop` skills (no scaffold note) · `F2` `hooks.json` unquoted `${CLAUDE_PLUGIN_ROOT}` + no `timeout` (breaks on spaced install paths; **land with F1, not before**) · `F3` `ledger-append.sh` brittle `sed` parse → `jq -r` · `G1` `preflight.sh` verifies 2/7 keys but prints "passed" · `G4` `${CLAUDE_PROJECT_DIR}` in agent prose; subagents referenced by file-path not namespaced name; `.gitignore` protects the plugin repo but data lands in target repos (add to `.git/info/exclude` at freeze) · `NEW-2` `gate.sh` says "NEVER `npm run` (game-able)" then the wiring example is `npm run -s lint` — whoever copies it builds the forbidden path.

### LOW / OPPORTUNITY

`A2` `$schema` + metadata polish · `C3` `family_of` case/prefix-fragile → normalize · `L1` `die` unsafe inside `$( )` (document the contract) · **`G2` the harness that gates the model is itself UNGATED — add a ~30-line bats/CI suite running exactly the auditors' probes (non-repo, bad base, 1-commit, uncommitted tamper, top-level `tests/`, pnpm-lock, Opus-impl, macOS shasum): the regression net that keeps every T0/T1 fix fixed** · `G3` a `doctor.sh` printing an ENFORCED / DESCRIBED-ONLY / TODO matrix per README claim · `E6` a `using-cc-local-loop` orientation/router skill (closes the E1 suction gap) + **Spanish triggers** ("corre el loop", "qué aprendimos") to match the user's other bilingual skills.

---

## Remediation roadmap

### T0 — before ANY install (~half a day)

1. `A1` — `"source":"./"` in marketplace.json; re-run both validates. *(1-liner)*
2. `F1` — gate the Stop hook on `.cc-local-loop/ACTIVE`; exclude the data plane from preflight's clean-tree check. *(small)*
3. `F2` — quote `"${CLAUDE_PLUGIN_ROOT}"` + `timeout` in hooks.json — **same commit as #2, never before**. *(1-liner)*
4. `F4` — `NODE_AI_URL` required (`:?`) or localhost default; document the homelab HTTP assumption. *(1-liner)*
5. `B1+B2` — build `OPENCODE_PERMISSION` with `jq -n`, assign unconditionally, validate before export. *(small)*
6. `E1a+E5a` — rescope dispatch/judge descriptions; add the scaffold-honesty note to judge/run-loop. *(small, prose)*
7. `D1a` — change the "enforced by CODEOWNERS + whitelist" claims to "TODO (see roadmap)". *(1-liner)*

### T1 — before the first real loop run (before removing either `die` guard)

`NEW-1` commit step / worktree-aware gate · `B3+B8` single anchored `PROTECTED_PAT` · `B4` gate fails closed (verified base, repo required, includes dirt) · `B5` hash-verify + pinned runner, else `unimplemented`+nonzero · `B6` freeze hardening (shasum, `-z`, `jq -n`, pnpm-lock) · `B7` per-task counter + numeric-validate + missing⇒ESCALATE · `C1+C2` judge signature+assert, dispatch roster/Opus-refusal · `E1b` mechanical `loop-active` marker · `D4` structured ledger rows · `F5` process-sandbox judge tests · `G1` preflight fails on unimplemented keys.

### T2 — hardening / enforcement-as-code

`D1b` real CODEOWNERS + CI path-whitelist on promotion PRs · `D2` seed diffs + artifact/benchmark checks · `D3` inject `lessons.md` into the context-pack · `D5+G4` drop `Bash` from distiller, constrain grader, fix agent path/var refs · `E4` declare/vendor the skill-creator dependency · `F3`/`NEW-2`/`C3`/`E5` cleanups · **`G2` bats/CI probe suite** (the regression net).

### T3 — v0.2

`E6` `using-cc-local-loop` router skill + Spanish triggers · `G3` `doctor.sh` guarantee-matrix · `A2` marketplace polish · externalize the model roster to config · README dead-link cleanup.

---

## What's explicitly correct (keep)

`disable-model-invocation:true` on exactly the two human-only entry points and no others; "safety-critical logic in scripts, not prose — call them, don't reimplement" (exemplary degrees-of-freedom pinning); fail-closed language throughout; the reflect/promote quarantine-vs-gate split; skill bodies 40–73 lines (well under 500); the fail-safe Stop hook (held up under garbage stdin / missing lib / no git in testing); the data plane correctly under `${CLAUDE_PROJECT_DIR}`; no secrets/tokens anywhere; the 5-skill decomposition is right-sized (no sprawl, no monolith — do **not** merge dispatch/judge into run-loop).

---

*Review executed as a Fable loop: 2 priming agents → 4 auditors (empirical) → converging council. All spec claims verified against live 2026 docs (code.claude.com, agentskills.io); all `[V]` behaviors reproduced in sandbox git repos. — 2026-07-05.*
