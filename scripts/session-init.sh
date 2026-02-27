#!/bin/bash
# Ralpha-Team: SessionStart hook
# Validates environment prerequisites and warns about stale state.
set -euo pipefail

warnings=""

# Check for agent-teams env var (required for team mode)
if [ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" != "1" ]; then
  warnings="${warnings}Ralpha-Team: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 is not set. Team mode will not work without it. Fix: add it to your Claude Code settings.json under \"env\" (Settings > Environment > CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1).\n"
fi

# Check for jq (required by parse-state.sh and QA logging)
if ! command -v jq >/dev/null 2>&1; then
  warnings="${warnings}Ralpha-Team: jq is not installed. State parsing and QA logging require it. Install with: brew install jq (macOS) or apt install jq (Linux).\n"
fi

# Warn about stale state from a previous session
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE="$PROJECT_DIR/.claude/ralpha-team.local.md"
if [ -f "$STATE_FILE" ]; then
  warnings="${warnings}Ralpha-Team: Found state file from a previous session (.claude/ralpha-team.local.md). Run /ralpha-team:cancel to clean up, or /ralpha-team:status to inspect it.\n"
fi

# Print warnings if any
if [ -n "$warnings" ]; then
  printf "%b" "$warnings"
fi
