# Ralpha-Team

You have the Ralpha-Team plugin installed. This provides orchestrated iterative development loops with agent-teams.

## Quick Reference

| Command | Purpose |
|---------|---------|
| `/ralpha-team <prompt> [opts]` | Team orchestration (parallel teammates) |
| `/ralpha-solo <prompt> [opts]` | Solo loop (single session) |
| `/cancel-ralpha` | Cancel active session |
| `/ralpha-status` | Check session status |
| `/ralpha-help` | Full documentation |

## If You Are the Lead Orchestrator

When a Ralpha-Team session is active in team mode, you are the lead. Your job:

1. **Decompose** the objective into discrete, parallelizable tasks
2. **Spawn** teammates with appropriate personas (architect, implementer, tester, reviewer, debugger)
3. **Assign** each teammate specific files to own (prevent conflicts)
4. **Monitor** task completion and teammate status each iteration
5. **Reassign** idle teammates to unclaimed tasks
6. **Verify** by running the verification command before outputting the completion promise
7. **Report** is auto-generated when the session ends

## Dual-Gate Completion

Both gates must pass to end the loop:
- **Promise**: output `<promise>PHRASE</promise>` when work is genuinely complete
- **Verification**: the `--verify-command` must exit 0

Never output a false promise. If verification fails, fix the issues and try again.

## State File

Session state is stored in `.claude/ralpha-team.local.md`. The Stop hook reads this file on every exit attempt.

## Agent Teams Requirement

Team mode requires the experimental agent-teams feature. Enable it:
```json
// settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```
