---
description: "Start Ralpha-Team solo loop (single-session mode)"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT] [--verify-command CMD] [--persona NAME]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralpha.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-completion.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/generate-report.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralpha Solo Command

Execute the setup script in solo mode:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralpha.sh" --mode solo $ARGUMENTS
```

You are now in a **Ralpha solo loop**. This works like the classic Ralph loop: when you try to exit, the stop hook feeds the SAME PROMPT back to you. You'll see your previous work in files and git history, allowing you to iterate and improve.

## How to Work

1. **Read your previous work** — check modified files, git log, test results
2. **Identify what's left** — compare current state against the objective
3. **Make incremental progress** — don't try to do everything at once
4. **Run the verification command** (if set) to check your progress
5. **Only output the completion promise when it's genuinely TRUE**

## Completion

When complete, output the promise in XML tags:
```
<promise>YOUR_PROMISE_TEXT</promise>
```

The stop hook checks for this tag. If a verify command is set, it must also pass. Both gates are required.

CRITICAL: Do NOT output false promises to escape the loop. The loop is designed to continue until genuine completion. If you're stuck, try a different approach rather than lying about completion.
