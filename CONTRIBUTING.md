# Contributing to ralpha-team

## Quick start

1. Fork and clone the repo
2. Make your changes
3. Run tests: `bash tests/test-runner.sh` (requires `jq`)
4. Open a PR against `main`

## Structure

- `commands/` — slash command prompts (markdown with YAML frontmatter)
- `agents/` — persona definitions for team mode
- `hooks/` — event hooks (`hooks.json` + shell scripts)
- `scripts/` — shared shell libraries and setup logic
- `tests/` — 10 test files, 10 tests each (100 total)

## Key rules

- **Frontmatter scoping**: All state file reads/writes must use the `awk n==1` pattern. See CLAUDE.md.
- **Tests**: Keep 10 tests per file. If you add a test, remove or consolidate another.
- **JSON in tests**: Use `jq -cn --arg t "$text" '{...}'`, never `printf`.
- **No new dependencies**: Only `jq`, `perl`, and standard Unix tools.

## Testing

```bash
bash tests/test-runner.sh
```

All 100 tests must pass before merging.
