# Ralpha Orchestration Skill

## Overview

Ralpha-Team combines two patterns into a hybrid orchestration model:

1. **Outer loop** (ralph-loop pattern): A Stop hook prevents session exit and re-injects the same prompt. The lead session iterates, seeing its previous work in files and git history.
2. **Inner parallelism** (agent-teams pattern): Within each iteration, the lead can spawn/manage an agent-team where teammates work in parallel on decomposed tasks.

## The Hybrid A+B Model

### How It Works

```
Iteration 1:
  Lead receives objective → decomposes into tasks → spawns team
  Teammates work in parallel on assigned tasks
  Lead monitors, reassigns idle teammates, synthesizes results

Iteration 2 (Stop hook re-injects prompt):
  Lead checks task list → some tasks complete, some pending
  Reassigns idle teammates to remaining tasks
  Identifies integration issues, creates fix tasks

Iteration N:
  All tasks complete → Lead runs verification → Promise output
  Stop hook validates: promise detected + verification passed
  → Session exits, report generated
```

### State File

All state lives in `.claude/ralpha-team.local.md`:

```yaml
---
active: true
mode: team|solo
iteration: N
max_iterations: M
completion_promise: "PHRASE"
verify_command: "command"
verify_passed: false
team_name: "ralpha-XXXXX"
team_size: N
persona: "name"|null
started_at: "ISO8601"
---

The original objective prompt
```

The Stop hook reads this file on every exit attempt, increments the iteration, and re-injects the prompt body.

## Task Decomposition

Good decomposition is critical for team mode. Tasks should be:

- **Independent**: each task can be completed without waiting on others
- **File-disjoint**: no two tasks edit the same files (prevents merge conflicts)
- **Sized for one agent**: completable in 1-3 loop iterations
- **Verifiable**: has a clear success criterion

### Example Decomposition

Objective: "Build a REST API with auth, CRUD, and tests"

| Task | Persona | Files Owned |
|------|---------|-------------|
| Design API schema + routes | Architect | `docs/api-spec.md` |
| Implement auth module | Implementer | `src/auth/*` |
| Implement CRUD endpoints | Implementer | `src/routes/*`, `src/models/*` |
| Write test suite | Tester | `tests/*` |
| Review + integration | Reviewer | (read-only) |

## Persona Selection

Match personas to the objective:

| Objective Type | Recommended Team |
|---------------|-----------------|
| New feature | 1 architect + 2 implementers + 1 tester |
| Bug fix | 1 debugger + 1 tester |
| Refactor | 1 architect + 2 implementers + 1 reviewer |
| Research | 3 researchers (use implementer persona) |
| Test coverage | 1 reviewer + 2 testers |

## Dual-Gate Completion

### Promise Gate
Claude outputs `<promise>PHRASE</promise>` when it believes work is done. This is subjective — Claude's assessment.

### Verification Gate
A command runs and must exit 0. This is objective — actual test results.

### Both Required
The Stop hook checks for the promise in the last assistant message, THEN runs the verification command. If either fails, the loop continues.

If promise is detected but verification fails:
- The system message tells the lead what failed
- The lead should analyze the failure and create fix tasks
- The loop continues until both gates pass

## Team Coordination Patterns

### Avoid File Conflicts
The #1 cause of wasted iterations is two teammates editing the same file. Prevent this by:
- Having the architect explicitly assign file ownership
- Using git worktrees for teammate isolation when possible
- Having the lead merge branches rather than teammates pushing to main

### Monitor and Reassign
On each iteration, the lead should:
1. Check which tasks are completed
2. Check which teammates are idle
3. Reassign idle teammates to unclaimed tasks
4. Identify integration issues and create new tasks if needed

### Teammate Communication
Teammates can message each other directly. Use this for:
- Clarifying interface contracts between modules
- Reporting blocking dependencies
- Sharing test results that affect other teammates' work

## Overnight Running

For overnight sessions:
- Always set `--max-iterations` as a safety net
- Use `--verify-command` to ensure objective quality
- Use `--completion-promise` so the loop can end naturally
- The report (`ralpha-report.md`) will tell you what happened when you wake up
- Each iteration creates git commits, so `git log` shows the full history
