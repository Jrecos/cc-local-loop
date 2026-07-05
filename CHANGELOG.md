# Changelog

All notable changes to `cc-local-loop` are documented here. Format: [Keep a Changelog](https://keepachangelog.com); versioning: [SemVer](https://semver.org).

## [0.1.0] — 2026-07-05
### Added
- Initial plugin skeleton: Opus-orchestrated → local-model-executed dev loop, judge-only validation, cross-family gate invariant.
- Skills: `run-loop`, `dispatch`, `judge`, `reflect`, `promote-lessons`.
- Deterministic scripts: `harness/{freeze,gate,guards}.sh`, `dispatch.sh`, `judge.sh`, `preflight.sh`, `ledger-append.sh`.
- `Stop` hook → append run outcome to the ledger (fail-safe).
- Subagents: `distiller`, `grader`.
- Seed frozen calibration set + capped `lessons.md`.
- Repo doubles as its own marketplace (`.claude-plugin/marketplace.json`).

> Status: **scaffold**. The executable loop depends on the node-ai "Option-B" serving topology being deployed
> (see the 7 preconditions in the homelab design doc §15.5). Scripts that call node-ai / OpenCode are marked `TODO(preflight)`.
