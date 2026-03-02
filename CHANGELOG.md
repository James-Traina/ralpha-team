# Changelog

## v1.9.0 — Final polish

- Fix plugin.json description typo ("Ralph" → "Ralpha")
- Guard parse_field/parse_prompt against missing load_frontmatter
- Harden promise regex against nested tags
- Add tool guidance and no-verify fallback to all 5 agent personas
- Sharpen team.md: file ownership enforcement, persona selection, merge-conflict recovery
- Sharpen cancel.md: explicit SendMessage/TeamDelete cleanup steps
- Add Setup section and Troubleshooting FAQ to README
- Move frontmatter scoping invariant to top of CLAUDE.md
- Add CONTRIBUTING.md and CHANGELOG.md
- Prioritized PreCompact prompt preservation order
- Add WHY comments to health score, quote_yaml, team name, promise regex

## v1.8.0 — Simplify to 5-5-5-5

- Drop help.md command (6 → 5 commands)
- Merge session-init.sh into setup-ralpha.sh --init (7 → 5 scripts)
- Merge generate-report.sh into qa-analyze.sh --report
- Remove dead skills/ directory
- Fix "Task tool" → "Agent tool" in team.md
- Harden error handling from PR review findings
- Rename test-generate-report.sh → test-qa-report.sh

## v1.7.0 — Test trim + rename

- Rename test/ → tests/
- Trim test suite from 293 → 100 (10 per file × 10 files)
- Shared test fixtures: create_transcript, hook_input, create_state

## v1.6.0 — Robustness + normalization

- Shared test fixtures, YAML unescape bug fix
- Remove empty .mcp.json
- Normalize plugin name to lowercase ralpha-team everywhere

## v1.5.0 — Robustness tweaks

- Hook timeouts 120s, quote_yaml fix
- Stuck-recovery prompts, "if stuck" guidance

## v1.4.0 — Polish pass

- Hooks matchers/timeouts, SessionStart, PreCompact
- Deeper agent personas, self-verification tests
- README install instructions

## v1.3.0 — Ship hardening

- 4 bug fixes, frontmatter scoping invariant
- Env var warning, model wiring
- 254 tests

## v1.2.0 — QA toolkit

- JSONL telemetry logging (qa-log.sh)
- Pattern detection and analysis (qa-analyze.sh)
- Self-improvement flywheel cycle

## v1.1.0 — High-priority fixes

- Persona wiring, task list integration
- Promise matching (case-insensitive, whitespace-normalized)

## v1.0.0 — Initial release

- Solo and team modes
- Dual-gate completion (promise + verification)
- 5 agent personas (architect, implementer, tester, reviewer, debugger)
- Stop hook loop mechanism
