#!/bin/bash

# Reads verify_command from state file and executes it.
# Exit 0 = passed, non-zero = failed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parse-state.sh"

if [[ ! -f "$RALPHA_STATE_FILE" ]]; then
  echo "No active ralpha session" >&2
  exit 1
fi

ralpha_load_frontmatter
VERIFY_COMMAND=$(ralpha_parse_field "verify_command")

if [[ "$VERIFY_COMMAND" = "null" ]] || [[ -z "$VERIFY_COMMAND" ]]; then
  echo "No verification command configured"
  exit 0
fi

echo "Running verification: $VERIFY_COMMAND"

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
