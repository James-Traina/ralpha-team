#!/bin/bash

# Ralpha-Team TaskCompleted Hook
# Quality gate: runs when a task is being marked complete.
# Exit code 2 prevents completion and sends feedback.
# Exit code 0 allows completion.

set -euo pipefail

HOOK_INPUT=$(cat)
RALPHA_STATE_FILE=".claude/ralpha-team.local.md"

# Only active during ralpha sessions
if [[ ! -f "$RALPHA_STATE_FILE" ]]; then
  exit 0
fi

FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPHA_STATE_FILE")
VERIFY_COMMAND=$(echo "$FRONTMATTER" | grep '^verify_command:' | sed 's/verify_command: *//' | sed 's/^"\(.*\)"$/\1/')

# If no verify command, allow all task completions
if [[ "$VERIFY_COMMAND" = "null" ]] || [[ -z "$VERIFY_COMMAND" ]]; then
  exit 0
fi

# Run verification as a spot check on task completion
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
VERIFY_RESULT=$(bash "$SCRIPT_DIR/verify-completion.sh" 2>&1)
VERIFY_EXIT=$?

if [[ $VERIFY_EXIT -eq 0 ]]; then
  # Verification passes - allow task completion
  exit 0
else
  # Verification fails - block task completion with feedback
  VERIFY_SNIPPET=$(echo "$VERIFY_RESULT" | tail -10)
  echo "Task completion blocked: verification command failed. Output: $VERIFY_SNIPPET"
  exit 2
fi
