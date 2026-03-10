---
name: solo
description: "Start ralpha-team solo loop (single-session mode)"
argument-hint: "PROMPT [--speed fast|efficient|quality] [--max-iterations N] [--completion-promise TEXT] [--verify-command CMD] [--persona NAME]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralpha.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-completion.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qa-analyze.sh:*)", "Read(${CLAUDE_PLUGIN_ROOT}/agents/*.md)"]
hide-from-slash-command-tool: "true"
---

# Ralpha Solo Command

Execute the setup script in solo mode:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralpha.sh" --mode solo $ARGUMENTS
```

You are now in a **Ralpha solo loop**. When you try to exit, the stop hook feeds the same prompt back to you. You'll see your previous work in files and git history.

## Persona

If a `--persona` was specified, load it now:

1. Read the state file `.claude/ralpha-team.local.md` and check the `persona:` field
2. If it's not `null`, read the persona definition from `${CLAUDE_PLUGIN_ROOT}/agents/{persona}.md`
3. **Adopt that persona's role, responsibilities, and working style for the entire session**

If no persona was set, work as a generalist.

## How to Work

1. **Orient yourself** — run `git log --oneline -5` then `git diff HEAD~1` on the most relevant files. This shows exactly what changed last iteration and prevents you from redoing completed work.
2. **Search before implementing** — before writing any code, confirm the thing you're about to build doesn't already exist. Use Grep/Glob to search for the function name, module path, or related patterns. Duplicate implementations waste iterations.
3. **Identify what's left** — compare current state against the objective
4. **Make incremental progress** — don't try to do everything at once
5. **Run the verification command** (if set) after each meaningful change — at minimum once per iteration, producing at least one file change or test result
6. **Commit after each verified change** — `git add -A && git commit -m "..."` with a clear message. Each iteration should leave a commit so progress is visible and rollback is cheap.
7. **If no verification command is set**, rely solely on the completion promise. Self-test your work manually before claiming completion.
8. **Only output the completion promise when it's genuinely TRUE**

## If Stuck

- **No file changes this iteration**: your approach isn't working. Try something completely different — a different file, a different algorithm, a different angle on the problem. Repeating the same failing strategy wastes the loop.
- **Same verification error repeating**: stop and re-read the full error carefully. Then try a different fix strategy, not the same one again.
- **Can't implement something fully**: leave a clear TODO comment with a specific description of what's missing — never write a stub that returns fake data or pretends to work.

## Completion

When complete, output the completion promise in XML tags. The exact phrase must match what was set with `--completion-promise` (check the `completion_promise:` field in `.claude/ralpha-team.local.md` if unsure):

```
<promise>EXACT_PHRASE_HERE</promise>
```

The stop hook compares this case-insensitively to the expected phrase. If a verify command is set, it must also pass. Both gates are required.

CRITICAL: Do NOT output false promises to escape the loop. The loop is designed to continue until genuine completion. If you're stuck, try a different approach rather than lying about completion.
