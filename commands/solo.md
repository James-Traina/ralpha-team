---
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

1. **Read your previous work** — check modified files, git log, test results
2. **Identify what's left** — compare current state against the objective
3. **Make incremental progress** — don't try to do everything at once
4. **Run the verification command** (if set) after each meaningful change — at minimum once per iteration, producing at least one file change or test result
5. **If no verification command is set**, rely solely on the completion promise. Self-test your work manually before claiming completion.
6. **Only output the completion promise when it's genuinely TRUE**

## Completion

When complete, output the promise in XML tags:
```
<promise>YOUR_PROMISE_TEXT</promise>
```

The stop hook checks for this tag. If a verify command is set, it must also pass. Both gates are required.

CRITICAL: Do NOT output false promises to escape the loop. The loop is designed to continue until genuine completion. If you're stuck, try a different approach rather than lying about completion.
