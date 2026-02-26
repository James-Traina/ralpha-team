---
description: "Explain Ralpha-Team plugin and available commands"
---

# Ralpha-Team Help

Explain the following to the user:

## What is Ralpha-Team?

Ralpha-Team is a Claude Code plugin that combines two powerful patterns:

1. **Ralph Loop** (the Ralph Wiggum technique) — a self-referential loop where the same prompt is fed back repeatedly, with Claude seeing its previous work in files and git history
2. **Agent Teams** — multiple Claude Code instances working in parallel, coordinated by a lead session

The hybrid: the lead session runs a ralph-loop (outer iteration), and within each iteration can spawn/manage an agent-team for parallel work (inner parallelism).

## Modes

### Team Mode (`/ralpha-team`)
- Lead orchestrator decomposes work into tasks
- Spawns teammates with role personas (architect, implementer, tester, reviewer, debugger)
- Teammates work in parallel, each on their own tasks
- Lead monitors, reassigns, and synthesizes across iterations
- Best for: complex multi-file tasks, overnight runs, greenfield projects

### Solo Mode (`/ralpha-solo`)
- Single-session ralph-loop, no teammates
- Same prompt fed back on each iteration
- Best for: focused single-track tasks, bug fixes, refactoring

## Commands

| Command | Description |
|---------|-------------|
| `/ralpha-team <prompt> [opts]` | Start team orchestration |
| `/ralpha-solo <prompt> [opts]` | Start solo loop |
| `/cancel-ralpha` | Cancel active session |
| `/ralpha-status` | Check session status |
| `/ralpha-help` | This help message |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--max-iterations <n>` | Stop after N iterations | unlimited |
| `--completion-promise '<text>'` | Promise phrase for completion | none |
| `--verify-command '<cmd>'` | Verification command (must pass) | none |
| `--team-size <n>` | Teammates in team mode | 3 |
| `--persona <name>` | Persona for solo mode | none |

## Completion (Dual Gate)

Ralpha uses a dual-gate completion system:
1. **Promise gate**: Claude outputs `<promise>PHRASE</promise>` when it believes work is done
2. **Verification gate**: A command (e.g., `npm test`) must exit with code 0

Both gates must pass simultaneously. If the promise is detected but verification fails, the loop continues with feedback about what failed.

## Personas

Teammates can be assigned role personas:
- **Architect**: designs structure, APIs, creates implementation plans
- **Implementer**: writes code, makes tests pass
- **Tester**: writes tests, validates coverage
- **Reviewer**: reviews code for correctness and quality
- **Debugger**: diagnoses failures, fixes broken tests

## Examples

```bash
# Overnight feature build with full gates
/ralpha-team Build a REST API with auth, CRUD, and tests \
  --completion-promise 'ALL TESTS PASSING' \
  --verify-command 'npm test' \
  --max-iterations 30 \
  --team-size 4

# Quick solo bug fix
/ralpha-solo Fix the token refresh race condition \
  --completion-promise 'FIXED' \
  --verify-command 'pytest tests/test_auth.py' \
  --max-iterations 10

# Greenfield with no verify (trust the promise)
/ralpha-team Create a CLI tool for managing TODOs \
  --completion-promise 'CLI COMPLETE' \
  --max-iterations 50
```

## Monitoring

```bash
# Quick iteration check
grep '^iteration:' .claude/ralpha-team.local.md

# Full state
cat .claude/ralpha-team.local.md

# Check status interactively
/ralpha-status
```

## Learn More

- Ralph Wiggum technique: https://ghuntley.com/ralph/
- Official ralph-loop plugin: anthropics/claude-plugins-official
- Agent teams docs: https://code.claude.com/docs/en/agent-teams
