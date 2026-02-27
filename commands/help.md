---
description: "Explain ralpha-team plugin and available commands"
---

# ralpha-team Help

Explain the following to the user:

## What is ralpha-team?

ralpha-team combines two patterns:

1. **Ralph Loop** -- a self-referential loop where the same prompt is fed back repeatedly, with Claude seeing its previous work in files and git history
2. **Agent Teams** -- multiple Claude Code instances working in parallel, coordinated by a lead session

The lead session runs a ralph-loop (outer iteration) and within each iteration spawns/manages an agent-team for parallel work (inner parallelism).

## Modes

- **Team** (`/ralpha-team:team`): Lead decomposes work, spawns teammates with role personas, monitors and reassigns across iterations. Best for complex multi-file tasks.
- **Solo** (`/ralpha-team:solo`): Single-session ralph-loop. Same prompt fed back each iteration. Best for focused single-track tasks.

## Commands

| Command | Description |
|---------|-------------|
| `/ralpha-team:team <prompt> [opts]` | Start team orchestration |
| `/ralpha-team:solo <prompt> [opts]` | Start solo loop |
| `/ralpha-team:cancel` | Cancel active session |
| `/ralpha-team:status` | Check session status |
| `/ralpha-team:qa` | Analyze QA telemetry from last session |
| `/ralpha-team:help` | This help message |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--max-iterations <n>` | Stop after N iterations | unlimited |
| `--completion-promise '<text>'` | Promise phrase for completion | none |
| `--verify-command '<cmd>'` | Verification command (must pass) | none |
| `--team-size <n>` | Teammates in team mode | 3 |
| `--persona <name>` | Persona for solo mode | none |

## Dual-Gate Completion

1. **Promise gate**: Claude outputs `<promise>PHRASE</promise>` when it believes work is done
2. **Verification gate**: A command (e.g., `npm test`) must exit 0

Both must pass simultaneously. If promise is detected but verification fails, the loop continues with failure feedback.

## Personas

- **Architect**: designs structure, APIs, creates implementation plans
- **Implementer**: writes code, makes tests pass
- **Tester**: writes tests, validates coverage
- **Reviewer**: reviews code for correctness and quality
- **Debugger**: diagnoses failures, fixes broken tests

## Examples

```bash
# Overnight feature build with full gates
/ralpha-team:team Build a REST API with auth, CRUD, and tests \
  --completion-promise 'ALL TESTS PASSING' \
  --verify-command 'npm test' \
  --max-iterations 30 \
  --team-size 4

# Quick solo bug fix
/ralpha-team:solo Fix the token refresh race condition \
  --completion-promise 'FIXED' \
  --verify-command 'pytest test/test_auth.py' \
  --max-iterations 10
```

## Monitoring

```bash
/ralpha-team:status                              # Interactive status check
grep '^iteration:' .claude/ralpha-team.local.md  # Quick iteration check
cat .claude/ralpha-team.local.md                 # Full state
```

## QA Toolkit

Every session automatically writes telemetry to `.claude/ralpha-qa.jsonl`. After a session:

```bash
/ralpha-team:qa    # Analyze telemetry, generate findings with health score
```

The findings report (`ralpha-qa-findings.md`) classifies issues as MUST-FIX / SHOULD-FIX / NICE-TO-HAVE and suggests a self-improvement cycle command — creating a dogfooding flywheel where the plugin improves itself.
