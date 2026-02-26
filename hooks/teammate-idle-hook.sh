#!/bin/bash

# Runs when a teammate is about to go idle.
# Exit 2 = send feedback (keep working). Exit 0 = allow idle.

set -euo pipefail

HOOK_INPUT=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPT_DIR/parse-state.sh"

if [[ ! -f "$RALPHA_STATE_FILE" ]]; then
  exit 0
fi

ralpha_load_frontmatter
MODE=$(ralpha_parse_field "mode")

if [[ "$MODE" != "team" ]]; then
  exit 0
fi

echo "Before going idle: check the shared task list for unclaimed tasks. If any exist, claim and work on one. If all tasks are complete or claimed, you may go idle."
exit 2
