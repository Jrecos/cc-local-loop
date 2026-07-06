# lessons.md — the ONE injected memory file

> **This is the only memory file injected into the loop's prompts.** Everything else (the ledger, candidates) is
> telemetry and must never be injected.
>
> **Cap: ~15 bullets / ~2K tokens.** Only **operational, non-obvious, tool-specific imperatives** belong here.
> No architectural narration — auto-generated / verbose context *reduces* resolution rates and inflates cost
> (ETH Zurich, [arXiv 2602.11988](https://arxiv.org/abs/2602.11988)).
>
> **Additions are human-gated only** — via `promote-lessons` (a PR carrying non-regression evidence). Nothing here
> is auto-written. Each bullet carries an ID **and** provenance (enforced by `lessons-lint.sh`, fail-closed). The set
> is **capped**: when full, a new lesson must **replace** a lower-value one at promotion review (human decision) —
> there is no automatic time-decay.

## Lessons

- **L001** `[seed]` On the `claude -p` fallback lane, set `CLAUDE_CODE_ATTRIBUTION_HEADER=0` — the rotating header
  invalidates the KV prefix and re-prefill is ~90% slower on Strix Halo. (env export alone doesn't take; put it in
  settings.json.)
- **L002** `[seed]` Dispatch a **fresh `opencode run` per task, never `--attach`** — per-task `OPENCODE_PERMISSION`
  only enforces in the process you set it on; with `--attach` the scope is silently dropped (fails open).
- **L003** `[seed]` Serve **Ornith with a non-thinking / coder template** until the OpenCode↔llama.cpp prefill-400
  fix lands (#20861 / opencode#27920); verify the loaded template with `curl node-ai:8080/props`.

<!-- New lessons are appended here by promote-lessons (PR-only). Format:
- **Lxxx** `[cand_id · runs:...]` <one operational imperative>. -->
