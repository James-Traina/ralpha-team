---
description: "Cancel active Ralpha-Team session"
allowed-tools: ["Bash(test -f .claude/ralpha-team.local.md:*)", "Bash(rm .claude/ralpha-team.local.md)", "Read(.claude/ralpha-team.local.md)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/generate-report.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralpha

To cancel the active Ralpha session:

1. Check if `.claude/ralpha-team.local.md` exists: `test -f .claude/ralpha-team.local.md && echo "EXISTS" || echo "NOT_FOUND"`

2. **If NOT_FOUND**: Say "No active Ralpha session found."

3. **If EXISTS**:
   - Read `.claude/ralpha-team.local.md` to get iteration and mode
   - Generate a final report: run `"${CLAUDE_PLUGIN_ROOT}/scripts/generate-report.sh" "cancelled"`
   - If mode is "team", clean up the team (ask teammates to shut down, then clean up team resources)
   - Remove the state file: `rm .claude/ralpha-team.local.md`
   - Report: "Cancelled Ralpha session (mode: MODE, iteration: N)"
