# ralpha-team

Orchestrated iterative development loops with agent-teams. Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.json env.

## Commands

| Command | Purpose |
|---------|---------|
| `/ralpha-team:plan <context> [opts]` | Planning loop — generates `IMPLEMENTATION_PLAN.md` |
| `/ralpha-team:team <prompt> [opts]` | Team orchestration (parallel teammates) |
| `/ralpha-team:solo <prompt> [opts]` | Solo loop (single session) |
| `/ralpha-team:cancel` | Cancel active session |
| `/ralpha-team:status` | Check session status |
| `/ralpha-team:qa` | Analyze QA telemetry from last session |

## Completion

Both gates must pass: output `<promise>PHRASE</promise>` when genuinely complete, and `--verify-command` must exit 0. Never output a false promise.

State: `.claude/ralpha-team.local.md` | QA log: `.claude/ralpha-qa.jsonl`

## ⚠️ Plugin Invariant: Frontmatter Scoping

The state file (`.claude/ralpha-team.local.md`) = YAML frontmatter + freeform prompt body separated by `---`. This is the #1 source of bugs.

- **ALL** reads/writes to state file MUST scope to frontmatter using awk `n==1` pattern
- Prompt body can contain `---`, `iteration:`, `verify_passed:` — never match these
- Grep patterns starting with `-` need `grep -qF --` (end-of-options marker)
- Never name an awk variable `next` (shadows awk builtin)
- 4 locations use this pattern: `parse-state.sh` (2), `stop-hook.sh` (2)

## Development

### Testing
- Run: `bash .tests/test-runner.sh` (110 tests across 11 files)
- Use `jq -cn --arg t "$text" '{...}'` for JSON in tests, never `printf`
