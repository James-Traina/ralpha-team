#!/usr/bin/env bash

# ralpha-team TaskCompleted Hook
# Acknowledges task completion and logs it. Full verification runs at Stop, not here.
#
# Why not run verify_command on task completion?
# In a multi-task session the global verify_command will likely fail mid-build —
# code is partially implemented. Running it after every intermediate task penalises
# correct work for unrelated missing pieces and wastes token budget on noisy output.
# The Stop hook is the right place for the dual-gate verification check.

set -euo pipefail

HOOK_INPUT=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPT_DIR/parse-state.sh"
source "$SCRIPT_DIR/qa-log.sh"

if [[ ! -f "$RALPHA_STATE_FILE" ]]; then
  exit 0
fi

ralpha_load_frontmatter
ITERATION=$(ralpha_parse_field "iteration")
MODE=$(ralpha_parse_field "mode")

TASK_ID=$(jq -r '.task_id // "unknown"' <<< "$HOOK_INPUT" 2>/dev/null || echo "unknown")

qa_log "task-completed" "acknowledged" "iteration=$ITERATION" "mode=$MODE" "task_id=$TASK_ID"
exit 0
