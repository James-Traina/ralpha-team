# Changelog

All notable changes to ralpha-team are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). Versioning follows [Semantic Versioning](https://semver.org/).

## [1.9.1] - 2026-03-09

### Added
- `CHANGELOG.md` (this file)
- `.github/workflows/ci.yml` — CI pipeline: JSON validation, script permissions, test suite
- `settings.json` — plugin permissions manifest
- `## Updating` section to `README.md`

### Changed
- All 5 agent files: `description: |` → `description: >-`; added `model: sonnet` and `tools:` YAML list to frontmatter
- `hooks/hooks.json`: all 4 hook commands now wrapped with `bash "..."` and properly quoted (were being passed as raw shell strings)
- `agents/implementer.md`: added "Search before implementing" step and explicit stub/placeholder prohibition
- `agents/reviewer.md`: Correctness checklist now flags stub implementations as Critical
- `tests/` → `.tests/` (hidden directory; all 12 test files relocated)

### Fixed
- `test-self-verification.sh`: corrected `find` path from `tests/` to `.tests/`

## [1.9.0] - 2026-02-28

### Added
- 10-dimension quality evaluator (`scripts/eval-dimensions.sh`): 39 automated checks, 1–5 scorecard
- `--speed` flag for `/ralpha-team:solo` and `/ralpha-team:team` (fast / efficient / quality)
- Port attribution: acknowledges [ralph-orchestrator](https://github.com/mikeyobrien/ralph-orchestrator) origin

## [1.8.0] - 2026-02-20

### Added
- Initial public release of ralpha-team plugin
- Solo mode (`/ralpha-team:solo`): single-agent verification loop with dual-gate completion
- Team mode (`/ralpha-team:team`): parallel agents (architect, implementer, tester, reviewer, debugger)
- QA toolkit: session logging, health analysis, findings report
- Hook infrastructure: `SessionStart`, `Stop`, `TaskCompleted`, `TeammateIdle`, `PreCompact`
- 12 test files covering e2e, hooks, state parsing, edge cases, and self-verification
