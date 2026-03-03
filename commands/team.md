---
description: "Start ralpha-team orchestrated loop (team mode)"
argument-hint: "PROMPT [--speed fast|efficient|quality] [--max-iterations N] [--completion-promise TEXT] [--verify-command CMD] [--team-size N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralpha.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-completion.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qa-analyze.sh:*)", "Read(${CLAUDE_PLUGIN_ROOT}/agents/*.md)"]
hide-from-slash-command-tool: "true"
---

# ralpha-team Command

Execute the setup script in team mode:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralpha.sh" --mode team $ARGUMENTS
```

You are now the **lead orchestrator** of a ralpha-team session. Your role:

## Orchestration Protocol

### Phase 1: Decompose
Break the objective into discrete, parallelizable tasks. Use `TaskCreate` to register each task — this is the shared task list that all teammates can see via `TaskList`.

Each task should:
- Have a clear deliverable (a file, a test suite, a module)
- Be completable by one agent independently
- List the exact file paths the assignee owns (no two teammates may edit the same file)

**File ownership is mandatory.** When spawning teammates, explicitly assign each one a set of files. If two tasks must touch the same file, serialize them (use `addBlockedBy`) rather than running them in parallel. Violations cause merge conflicts that waste iterations.

Use `TaskUpdate` to set `addBlockedBy` for tasks with dependencies. This ensures teammates work in the correct order.

### Phase 2: Spawn Team
Create an agent team. Available personas are defined in `${CLAUDE_PLUGIN_ROOT}/agents/`:
- **architect** — system design, API planning, task decomposition
- **implementer** — writes production code
- **tester** — writes and runs tests
- **reviewer** — code review (read-only, does not write code)
- **debugger** — diagnoses failures and fixes bugs

**How to use personas**: Read the persona file (e.g. `${CLAUDE_PLUGIN_ROOT}/agents/implementer.md`) and include its full content in the teammate's spawn prompt. This gives each teammate their role definition, responsibilities, and working style.

**Choose personas based on the task type:**
- Planning-heavy work (new project, major refactor): architect + 2 implementers + tester
- Bug-fix session: debugger + implementer + tester
- Code quality pass: reviewer + implementer + tester
- Default / mixed: 1 architect + 2 implementers + 1 tester

**Create the team** using `TeamCreate` with the `team_name` from the state file (`.claude/ralpha-team.local.md`). Then spawn teammates using the `Agent` tool with the `team_name` parameter so they join the team and can access the shared task list.

Read the `model` field from the state file (`.claude/ralpha-team.local.md` frontmatter). When calling the `Agent` tool to spawn each teammate, pass this value as the `model` parameter. This is set by `--speed`: `fast`→`haiku`, `efficient`→`sonnet` (default), `quality`→`opus`. If the field is missing, default to `sonnet`.

When spawning each teammate, include in their prompt:
- The full persona definition (from the agent file)
- Their specific task(s) from the task list
- File paths they own (to avoid conflicts)
- The verification command (so they can self-check)
- Clear success criteria

### Phase 3: Monitor

**Start every iteration with this sequence:**
1. `TaskList` — find tasks that are pending with no owner; claim or reassign them with `TaskUpdate`
2. Read teammate messages (delivered automatically)
3. Review any newly completed work for correctness
4. If all tasks complete, run verification and assess completion

Between-iteration work:
- Do synthesis yourself (merge results, resolve conflicts, update interfaces)
- If two tasks need to touch the same file, serialize them with `addBlockedBy` rather than risking a conflict

**If things go wrong:**
- If verification fails 2+ times in a row: re-read the full error output, then reassign the failing work to a debugger or break the task into smaller pieces — don't let the same approach run a third time unchanged.
- If a teammate is stuck or silent for an iteration: reassign their task to a fresh teammate rather than waiting.
- If a merge conflict occurs: stop the conflicting teammate, resolve it yourself, then reassign remaining work with updated file ownership.

### Phase 4: Complete
When all work is done and verified:
1. Ensure the verification command passes
2. Output the completion promise in `<promise>` tags
3. The stop hook will validate both gates before allowing exit

CRITICAL: Do NOT output the promise until the work is genuinely complete and verified. The dual-gate system (promise + verification) ensures honest completion. If verification fails after you output the promise, you'll continue iterating — use that iteration to fix what failed.

### Working with Teammates
- Use git worktrees to isolate each teammate's work when possible
- Have teammates commit their work to branches, then you merge
- If two teammates need to coordinate, have them message each other directly
- Monitor for stuck teammates — reassign their tasks if they're not progressing
