---
description: "Check ralpha-team session status"
allowed-tools: ["Read(.claude/ralpha-team.local.md)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-completion.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralpha Status

Check the status of the active Ralpha session:

1. Read `.claude/ralpha-team.local.md`
2. If it doesn't exist, say "No active Ralpha session."
3. If it exists, report:
   - Mode (solo/team)
   - Current iteration / max iterations
   - Completion promise (if set)
   - Verify command (if set) and whether it currently passes
   - Team name and size (if team mode)
   - Started at timestamp
   - If team mode, check the shared task list and report pending/completed tasks
