# ralpha-team

A Claude Code plugin that runs your prompt in a loop until the job is actually done.

You give it an objective, a way to check completion, and optionally a team size. It feeds the same prompt back, iteration after iteration, until the verification command passes.

## Install

```bash
claude plugin install https://github.com/James-Traina/ralpha-team
```

## Setup

Team mode requires the experimental agent-teams flag. Add this to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Solo mode works without this flag. Both modes require `jq` to be installed.

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
  --verify-command 'pytest test/test_auth.py' \
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
| `--speed fast\|efficient\|quality` | Model tier: `fast`=haiku, `efficient`=sonnet, `quality`=opus | efficient |
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

This generates a findings report (`.claude/ralpha-qa-findings.md`) with a health score and prioritized issues: stuck loops, flaky verification, idle teammates, excessive iterations. It also suggests a follow-up command you can run to fix what it found.

## Components

| Category | Count | Location |
|----------|-------|----------|
| Commands | 5 | `commands/` — team, solo, cancel, status, qa |
| Agents | 5 | `agents/` — architect, implementer, tester, reviewer, debugger |
| Hooks | 5 | `hooks/` — session-start, stop, task-completed, teammate-idle, pre-compact |
| Scripts | 6 | `scripts/` — setup, parsing, verification, QA logging, QA analysis + reports, quality eval |
| Tests | 110 | `tests/` — 11 test files |

Run `bash tests/test-runner.sh`. No build step, no deps beyond `jq` and standard Unix tools.

## Troubleshooting

**Tests fail with "jq: command not found"**
Install jq: `brew install jq` (macOS) or `apt install jq` (Linux). It's the only external dependency.

**Session won't stop / loop keeps running**
Run `/ralpha-team:cancel` to end the session and generate a report. If that doesn't work, delete `.claude/ralpha-team.local.md` manually.

**Teammates idle forever / not claiming tasks**
Check that tasks are unblocked (`blockedBy` is empty) and unassigned (`owner` is empty). The idle hook nudges teammates to run `TaskList`, but if all tasks are blocked or already assigned, they'll stay idle. Break blocked tasks into smaller pieces or reassign.

## Background

This is a port of [ralph-orchestrator](https://github.com/mikeyobrien/ralph-orchestrator) to Claude Code's officially supported plugin system. The core idea — feed the same prompt back, let the agent see its own work accumulate in files and git — comes from that project. This version replaces the original's approach with native Claude Code primitives: the plugin hook API for loop control, `TeamCreate`/`Agent`/`TaskCreate` for coordination, and the dual-gate completion check.

Most of the hard bugs were in the state file — YAML frontmatter on top, freeform prompt body below — and making sure the hooks don't corrupt a prompt that happens to contain `iteration:` or `---` as regular text.

## License

MIT
