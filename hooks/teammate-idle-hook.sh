#!/bin/bash

# Runs when a teammate is about to go idle.
# Exit 2 = send feedback (keep working). Exit 0 = allow idle.

set -euo pipefail

HOOK_INPUT=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPT_DIR/parse-state.sh"
source "$SCRIPT_DIR/qa-log.sh"

if [[ ! -f "$RALPHA_STATE_FILE" ]]; then
  exit 0
fi

ralpha_load_frontmatter
MODE=$(ralpha_parse_field "mode")

if [[ "$MODE" != "team" ]]; then
  exit 0
fi

qa_log "idle-hook" "nudge" "mode=$MODE"
echo "Before going idle: run TaskList to check for unclaimed tasks (status: pending, no owner, not blocked). If any exist, claim one with TaskUpdate (set owner to your name) and work on it. If you have already checked and no unclaimed tasks remain, send a message to the lead confirming all your work is done, then stop working."
exit 2
