#!/bin/bash

# Quality gate: runs verification when a task is marked complete.
# Exit 2 = block completion with feedback. Exit 0 = allow.

set -euo pipefail

HOOK_INPUT=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPT_DIR/parse-state.sh"

if [[ ! -f "$RALPHA_STATE_FILE" ]]; then
  exit 0
fi

ralpha_load_frontmatter
VERIFY_COMMAND=$(ralpha_parse_field "verify_command")

if [[ "$VERIFY_COMMAND" = "null" ]] || [[ -z "$VERIFY_COMMAND" ]]; then
  exit 0
fi

set +e
VERIFY_RESULT=$(bash "$SCRIPT_DIR/verify-completion.sh" 2>&1)
VERIFY_EXIT=$?
set -e

if [[ $VERIFY_EXIT -eq 0 ]]; then
  exit 0
fi

VERIFY_SNIPPET=$(echo "$VERIFY_RESULT" | tail -10)
echo "Task completion blocked: verification command failed. Output: $VERIFY_SNIPPET"
exit 2
