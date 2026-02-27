# Ralpha-Team

A Claude Code plugin that runs your prompt in a loop until the job is actually done.

You give it an objective, a way to check completion, and optionally a team size. It keeps going — feeding the same prompt back, iteration after iteration — until the verification command passes.

## Install

```bash
claude plugin install https://github.com/James-Traina/Ralpha-Team
```

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in your Claude Code settings for team mode.

## How it works

Two modes:

**Solo** — one Claude session, looping. Each iteration sees the previous work in files and git history. Good for focused tasks like fixing a bug or writing a module.

**Team** — a lead session decomposes the objective into tasks, spawns parallel teammates (architect, implementer, tester, etc.), and coordinates across iterations. Good for larger work where you want multiple agents touching different files simultaneously.

Both modes use the same completion mechanism: a dual gate. Claude has to (1) explicitly claim it's done by outputting a promise phrase, and (2) a verification command you provide has to exit 0. If Claude says it's done but the tests fail, the loop continues with the failure output fed back in.

## Quick start

```bash
# Solo: fix a bug, loop until tests pass
/ralpha-team:solo Fix the token refresh race condition \
  --completion-promise 'FIXED' \
  --verify-command 'pytest tests/test_auth.py' \
  --max-iterations 10

# Team: build a feature with 4 parallel agents
/ralpha-team:team Build a REST API with auth, CRUD, and tests \
  --completion-promise 'ALL TESTS PASSING' \
  --verify-command 'npm test' \
  --max-iterations 30 \
  --team-size 4
```

## Options

| Flag | What it does | Default |
|------|-------------|---------|
| `--max-iterations N` | Hard stop after N loops | unlimited |
| `--completion-promise 'TEXT'` | Phrase Claude must output to claim completion | none |
| `--verify-command 'CMD'` | Shell command that must exit 0 | none |
| `--team-size N` | Number of teammates (team mode) | 3 |
| `--persona NAME` | Role persona for solo mode | generalist |

## Commands

| Command | What it does |
|---------|-------------|
| `/ralpha-team:team <prompt> [opts]` | Start a team session |
| `/ralpha-team:solo <prompt> [opts]` | Start a solo loop |
| `/ralpha-team:cancel` | Kill the active session |
| `/ralpha-team:status` | Check where things stand |
| `/ralpha-team:qa` | Analyze telemetry from last session |
| `/ralpha-team:help` | Full docs |

## The dual gate

This is the part that matters. Without it, Claude will sometimes claim it's done when it isn't.

The **promise gate** requires Claude to output `<promise>YOUR PHRASE</promise>` — and the text inside has to match (case-insensitive) what you set with `--completion-promise`. The **verification gate** runs your command and checks the exit code.

Both gates have to pass on the same iteration. Promise without passing verification? Loop continues, failure output fed back. No promise at all? Keeps going until `--max-iterations`. The point is you can set it up, walk away, and come back to either finished work or a clear log of where it got stuck.

## Team personas

In team mode, the lead assigns roles from `agents/`:

- **architect** — structure, APIs, planning
- **implementer** — production code
- **tester** — tests and coverage
- **reviewer** — code review (read-only)
- **debugger** — diagnoses and fixes failures

A typical split: one architect, two implementers, one tester. Each teammate owns specific files to avoid merge conflicts.

## QA telemetry

Every session writes structured logs to `.claude/ralpha-qa.jsonl`. After a session:

```bash
/ralpha-team:qa
```

This generates a findings report (`ralpha-qa-findings.md`) with a health score and prioritized issues: stuck loops, flaky verification, idle teammates, excessive iterations. The report also suggests a follow-up command to fix the issues it found — so the plugin can improve itself.

## Components

| Category | Count | Location |
|----------|-------|----------|
| Commands | 6 | `commands/` — team, solo, cancel, status, qa, help |
| Agents | 5 | `agents/` — architect, implementer, tester, reviewer, debugger |
| Hooks | 5 | `hooks/` — session-start, stop, task-completed, teammate-idle, pre-compact |
| Scripts | 7 | `scripts/` — session-init, setup, parsing, verification, QA logging, reports |
| Skills | 1 | `skills/` — ralpha-orchestration |
| Tests | 262+ | `tests/` — 11 test files |

Run `bash tests/test-runner.sh`. No build step, no deps beyond `jq` and standard Unix tools.

## Background

This came out of combining two ideas: the "ralph loop" (feed the same prompt back, let the agent see its own work accumulate in files and git) and Claude Code's agent teams (multiple sessions sharing a task list). Most of the hard bugs were in the state file — YAML frontmatter on top, freeform prompt body below — and making sure the hooks don't corrupt a prompt that happens to contain `iteration:` or `---` as regular text.

## License

MIT
