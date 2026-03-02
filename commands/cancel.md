---
description: "Cancel active ralpha-team session"
allowed-tools: ["Bash(test -f .claude/ralpha-team.local.md:*)", "Bash(rm .claude/ralpha-team.local.md)", "Read(.claude/ralpha-team.local.md)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qa-analyze.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralpha

To cancel the active Ralpha session:

1. Check if `.claude/ralpha-team.local.md` exists: `test -f .claude/ralpha-team.local.md && echo "EXISTS" || echo "NOT_FOUND"`

2. **If NOT_FOUND**: Say "No active Ralpha session found."

3. **If EXISTS**:
   - Read `.claude/ralpha-team.local.md` to get iteration and mode
   - Generate a final report: run `"${CLAUDE_PLUGIN_ROOT}/scripts/qa-analyze.sh" --report "cancelled"`
   - If mode is "team":
     1. Read `team_name` from the state file
     2. Send each teammate a shutdown request using `SendMessage` with `type: "shutdown_request"`
     3. Wait for shutdown confirmations, then call `TeamDelete` to remove the team and its task list
   - Remove the state file: `rm .claude/ralpha-team.local.md`
   - Report: "Cancelled Ralpha session (mode: MODE, iteration: N)"
