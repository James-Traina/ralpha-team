---
name: ralpha-orchestration
description: >
  Use this skill when orchestrating an active Ralpha-Team session, managing
  agent-team teammates, decomposing work into tasks, monitoring loop iterations,
  or working with the dual-gate completion system (promise + verification).
  Triggers: "ralpha", "ralph loop", "orchestrate teammates", "spawn team",
  "completion promise", "verification gate", "overnight autonomous".
---

# Ralpha Orchestration Skill

## The Hybrid Model

- **Outer loop** (ralph-loop): Stop hook prevents session exit and re-injects the same prompt. The lead iterates, seeing previous work in files and git history.
- **Inner parallelism** (agent-teams): Within each iteration, the lead spawns/manages teammates working in parallel on decomposed tasks.

```
Iteration 1: Lead decomposes objective → spawns team → teammates work in parallel
Iteration 2: Lead checks tasks → reassigns idle teammates → resolves integration issues
Iteration N: All done → verification passes → promise output → session exits
```

## State File

All state lives in `.claude/ralpha-team.local.md` (YAML frontmatter + prompt body). The Stop hook reads this on every exit attempt, increments iteration, and re-injects the prompt.

## Task Decomposition

Tasks should be:
- **Independent**: completable without waiting on others
- **File-disjoint**: no two tasks edit the same files
- **Sized for one agent**: completable in 1-3 iterations
- **Verifiable**: clear success criterion

### Example

Objective: "Build a REST API with auth, CRUD, and tests"

| Task | Persona | Files Owned |
|------|---------|-------------|
| Design API schema + routes | Architect | `docs/api-spec.md` |
| Implement auth module | Implementer | `src/auth/*` |
| Implement CRUD endpoints | Implementer | `src/routes/*`, `src/models/*` |
| Write test suite | Tester | `test/*` |
| Review + integration | Reviewer | (read-only) |

## Persona Selection

| Objective Type | Recommended Team |
|---------------|-----------------|
| New feature | 1 architect + 2 implementers + 1 tester |
| Bug fix | 1 debugger + 1 tester |
| Refactor | 1 architect + 2 implementers + 1 reviewer |
| Test coverage | 1 reviewer + 2 testers |

## Team Coordination

- **Avoid file conflicts**: Architect assigns file ownership. Use git worktrees when possible. Lead merges branches.
- **Monitor each iteration**: Check completed/pending tasks, reassign idle teammates, identify integration issues.
- **Teammate communication**: Direct messages for interface contracts, blocking dependencies, shared test results.

## Overnight Running

- Always set `--max-iterations` as a safety net
- Use both `--verify-command` and `--completion-promise`
- The report (`ralpha-report.md`) summarizes what happened
- Each iteration creates git commits for full history via `git log`
