# ralpha-team

A Claude Code plugin that runs your prompt in a loop until the job is actually done.

You give it an objective, a way to check completion, and optionally a team size. It feeds the same prompt back, iteration after iteration, until the verification command passes.

## Install

Inside Claude Code, run each command **separately**:

```
/plugin marketplace add James-Traina/science-plugins
```

```
/plugin install ralpha-team@science-plugins
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

Three modes:

**Plan** — a read-only analysis loop that scans your specs and codebase, then writes `IMPLEMENTATION_PLAN.md` as a prioritised checklist. Run this before a large build to give the loop a structured task queue rather than re-reasoning scope every iteration.

**Solo** — one Claude session, looping. Each iteration sees the previous work in files and git history. Good for focused tasks like fixing a bug or writing a module. Reads from `IMPLEMENTATION_PLAN.md` when present.

**Team** — a lead session decomposes the objective into tasks, spawns parallel teammates (architect, implementer, tester, etc.), and coordinates across iterations. Good for larger work where you want multiple agents touching different files simultaneously.

All modes use the same completion mechanism: a dual gate. Claude has to (1) explicitly claim it's done by outputting a promise phrase inside `<promise>` tags, and (2) a verification command you provide has to exit 0.

## Quick start

```bash
# Plan first: generate a task checklist from your specs
/ralpha-team:plan "Build a REST API with auth, CRUD, and tests" \
  --max-iterations 3

# Then build from the plan
/ralpha-team:team "Work through IMPLEMENTATION_PLAN.md" \
  --completion-promise 'ALL TESTS PASSING' \
  --verify-command 'npm test' \
  --max-iterations 30 \
  --team-size 4

# Or solo for a focused fix
/ralpha-team:solo "Fix the token refresh race condition" \
  --completion-promise 'FIXED' \
  --verify-command 'pytest test/test_auth.py' \
  --max-iterations 10
```

## Options

| Flag | What it does | Default |
|------|-------------|---------|
| `--speed fast\|efficient\|quality` | Default model tier for unnamed agents: `fast`=haiku, `efficient`=sonnet, `quality`=opus | efficient |
| `--max-iterations N` | Hard stop after N loops | unlimited |
| `--completion-promise 'TEXT'` | Phrase Claude must output inside `<promise>TEXT</promise>` tags | none |
| `--verify-command 'CMD'` | Shell command that must exit 0 | none |
| `--team-size N` | Number of teammates (team mode) | 3 |
| `--persona NAME` | Role persona for solo mode | generalist |

## Commands

| Command | What it does |
|---------|-------------|
| `/ralpha-team:plan <context> [opts]` | Generate or refresh `IMPLEMENTATION_PLAN.md` |
| `/ralpha-team:team <prompt> [opts]` | Start a team session |
| `/ralpha-team:solo <prompt> [opts]` | Start a solo loop |
| `/ralpha-team:cancel` | Kill the active session |
| `/ralpha-team:status` | Check where things stand |
| `/ralpha-team:qa` | Analyze telemetry from last session |

## The dual gate

This is the part that matters. Without it, Claude will sometimes claim it's done when it isn't.

The **promise gate** requires Claude to output `<promise>YOUR PHRASE</promise>` — and the text inside has to match (case-insensitive) what you set with `--completion-promise`. Claude must emit the tags, not just the phrase. The **verification gate** runs your command and checks the exit code.

Both gates have to pass on the same iteration. Promise without passing verification? Loop continues, failure output fed back. No promise at all? Keeps going until `--max-iterations`. The point is you can set it up, walk away, and come back to either finished work or a clear log of where it got stuck.

## Team personas

In team mode, the lead assigns roles from `agents/`. Each persona has its own model assignment — named personas use their defined model regardless of `--speed`:

- **planner** — strategic gap analysis, plan generation (Opus)
- **architect** — system design, APIs, task decomposition (Sonnet)
- **implementer** — production code (Sonnet)
- **tester** — writes tests (Sonnet)
- **validator** — runs the build/test suite mechanically, reports pass/fail only; single-instance (Sonnet)
- **reviewer** — code review, read-only (Sonnet)
- **debugger** — diagnoses and fixes failures (Sonnet)

A typical split: architect + two implementers + tester + validator. Each teammate owns specific files to avoid merge conflicts.

## Consumer project setup

For best results, add a `CLAUDE.md` at your project root with build and validation commands. This is what the validator reads to know how to apply backpressure:

```markdown
# [Your Project Name]

## Build & Validation

- Build: `npm run build`
- Tests: `npm test`
- Typecheck: `npx tsc --noEmit`
- Lint: `npx eslint src/`

## Architecture

[Key conventions, patterns, and invariants agents should respect]
```

To enable per-edit typecheck/lint (runs after every source file write), create `.ralpha-validate.conf` in the project root:

```bash
# .ralpha-validate.conf
TYPECHECK_CMD="npx tsc --noEmit 2>&1"
LINT_CMD="npx eslint src/ --quiet 2>&1"
```

This hooks into Claude's edit events and catches type errors before they accumulate across an iteration.

## QA telemetry

Every session writes structured logs to `.claude/ralpha-qa.jsonl`. After a session:

```bash
/ralpha-team:qa
```

This generates a findings report (`.claude/ralpha-qa-findings.md`) with a health score and prioritized issues: stuck loops, flaky verification, idle teammates, excessive iterations. It also suggests a follow-up command you can run to fix what it found.

## Components

| Category | Count | Location |
|----------|-------|----------|
| Commands | 6 | `commands/` — plan, team, solo, cancel, status, qa |
| Agents | 7 | `agents/` — planner, architect, implementer, tester, validator, reviewer, debugger |
| Hooks | 6 | `hooks/` — post-tool-validate, session-start, stop, task-completed, teammate-idle, pre-compact |
| Scripts | 6 | `scripts/` — setup, parsing, verification, QA logging, QA analysis + reports, quality eval |
| Tests | 110 | `.tests/` — 11 test files |

Run `bash .tests/test-runner.sh`. No build step, no deps beyond `jq` and standard Unix tools.

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

## Updating

```bash
/plugin update ralpha-team
```

## License

MIT
