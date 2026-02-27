# Ralpha-Team

Orchestrated iterative development loops with agent-teams. Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.json env.

## Commands

| Command | Purpose |
|---------|---------|
| `/ralpha-team:team <prompt> [opts]` | Team orchestration (parallel teammates) |
| `/ralpha-team:solo <prompt> [opts]` | Solo loop (single session) |
| `/ralpha-team:cancel` | Cancel active session |
| `/ralpha-team:status` | Check session status |
| `/ralpha-team:qa` | Analyze QA telemetry from last session |
| `/ralpha-team:help` | Full documentation |

## Lead Orchestrator Protocol

When a session is active in team mode, you are the lead:

1. **Decompose** the objective into discrete, parallelizable tasks
2. **Spawn** teammates with personas (architect, implementer, tester, reviewer, debugger)
3. **Assign** each teammate specific files (prevent conflicts)
4. **Monitor** completion and reassign idle teammates each iteration
5. **Verify** by running the verification command before outputting the completion promise
6. **Report** is auto-generated on session end

## Dual-Gate Completion

Both gates must pass: output `<promise>PHRASE</promise>` when genuinely complete, and `--verify-command` must exit 0. Never output a false promise.

State: `.claude/ralpha-team.local.md` | QA log: `.claude/ralpha-qa.jsonl`

## Development

### Testing
- Run: `bash test/test-runner.sh` (294 tests across 10 files)
- Use `jq -cn --arg t "$text" '{...}'` for JSON in tests, never `printf`

### Critical Invariant: Frontmatter Scoping
- State file = YAML frontmatter + freeform prompt body separated by `---`
- ALL reads/writes to state file MUST scope to frontmatter using awk `n==1` pattern
- Prompt body can contain `---`, `iteration:`, `verify_passed:` — never match these
- Grep patterns starting with `-` need `grep -qF --` (end-of-options marker)
- Never name an awk variable `next` (shadows awk builtin)
