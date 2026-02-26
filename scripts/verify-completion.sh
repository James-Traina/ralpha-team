#!/bin/bash

# Ralpha-Team Verification Runner
# Reads verify_command from state file and executes it.
# Exit 0 = verification passed, non-zero = failed.

set -euo pipefail

RALPHA_STATE_FILE=".claude/ralpha-team.local.md"

if [[ ! -f "$RALPHA_STATE_FILE" ]]; then
  echo "No active ralpha session" >&2
  exit 1
fi

FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPHA_STATE_FILE")
VERIFY_COMMAND=$(echo "$FRONTMATTER" | grep '^verify_command:' | sed 's/verify_command: *//' | sed 's/^"\(.*\)"$/\1/')

if [[ "$VERIFY_COMMAND" = "null" ]] || [[ -z "$VERIFY_COMMAND" ]]; then
  echo "No verification command configured"
  exit 0
fi

echo "Running verification: $VERIFY_COMMAND"

# Run the command and capture output + exit code
set +e
VERIFY_OUTPUT=$(eval "$VERIFY_COMMAND" 2>&1)
VERIFY_EXIT=$?
set -e

echo "$VERIFY_OUTPUT"

if [[ $VERIFY_EXIT -eq 0 ]]; then
  echo "Verification PASSED"
else
  echo "Verification FAILED (exit code: $VERIFY_EXIT)"
fi

exit $VERIFY_EXIT
