---
name: status
description: "Check ralpha-team session status"
allowed-tools: ["Read(.claude/ralpha-team.local.md)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify-completion.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralpha Status

Check the status of the active Ralpha session:

1. Read `.claude/ralpha-team.local.md`
2. If it doesn't exist, say "No active Ralpha session."
3. If it exists, report using this format:

```
## Ralpha Session Status

**Mode**: solo | team
**Iteration**: N / MAX
**Started**: TIMESTAMP
**Objective**: [first line of the prompt body]

**Verification**: [command] — PASSING | FAILING | not set
**Completion promise**: [phrase] — not yet detected | not set

**Tasks** (team mode only):
  - X completed, Y pending, Z blocked
  - Unclaimed: [list pending tasks with no owner]
```

For the verify command status: run it live and report the actual current result, not the last cached result.
