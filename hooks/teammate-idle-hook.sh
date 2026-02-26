#!/bin/bash

# Ralpha-Team TeammateIdle Hook
# Runs when a teammate is about to go idle.
# Exit code 2 sends feedback and keeps the teammate working.
# Exit code 0 allows the teammate to go idle.

set -euo pipefail

HOOK_INPUT=$(cat)
RALPHA_STATE_FILE=".claude/ralpha-team.local.md"

# Only active during ralpha team sessions
if [[ ! -f "$RALPHA_STATE_FILE" ]]; then
  exit 0
fi

FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPHA_STATE_FILE")
MODE=$(echo "$FRONTMATTER" | grep '^mode:' | sed 's/mode: *//')

# Only intervene in team mode
if [[ "$MODE" != "team" ]]; then
  exit 0
fi

# Tell the teammate to check for unclaimed tasks before going idle
echo "Before going idle: check the shared task list for unclaimed tasks. If any exist, claim and work on one. If all tasks are complete or claimed, you may go idle."
exit 2
