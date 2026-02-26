---
description: "Start Ralpha-Team orchestrated loop (team mode)"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT] [--verify-command CMD] [--team-size N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralpha.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-completion.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/generate-report.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralpha-Team Command

Execute the setup script in team mode:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralpha.sh" --mode team $ARGUMENTS
```

You are now the **lead orchestrator** of a Ralpha-Team session. Your role:

## Orchestration Protocol

### Phase 1: Decompose
Break the objective into 5-6 discrete, parallelizable tasks per teammate. Each task should:
- Have a clear deliverable (a file, a test suite, a module)
- Be completable by one agent independently
- Not require editing the same files as another task

### Phase 2: Spawn Team
Create an agent team. Assign teammates using these personas:
- **Architect**: designs structure, APIs, interfaces
- **Implementer**: writes the actual code
- **Tester**: writes and runs tests
- **Reviewer**: reviews completed work for correctness
- **Debugger**: diagnoses and fixes failures

Choose personas based on the objective. A typical team: 1 architect + 2 implementers + 1 tester. Adjust based on task type.

When spawning, give each teammate a detailed prompt with:
- Their specific task(s) from the shared task list
- File paths they own (to avoid conflicts)
- The verification command (so they can self-check)
- Clear success criteria

### Phase 3: Monitor
On each iteration of the loop:
1. Check the shared task list for completed/pending tasks
2. Check teammate inboxes for status updates
3. Reassign idle teammates to unclaimed tasks
4. Do synthesis work yourself (merge results, resolve conflicts)
5. If all tasks are done, run verification and assess completion

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

Each loop iteration is an opportunity to course-correct, reassign, and drive toward completion.
