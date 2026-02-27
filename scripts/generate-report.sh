#!/bin/bash

# Produces ralpha-report.md with structured summary of the session.

set -euo pipefail

COMPLETION_REASON="${1:-unknown}"
REPORT_FILE="ralpha-report.md"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parse-state.sh"
source "$SCRIPT_DIR/qa-log.sh"

if [[ ! -f "$RALPHA_STATE_FILE" ]]; then
  echo "No active ralpha session - cannot generate report" >&2
  exit 1
fi

ralpha_load_frontmatter
ITERATION=$(ralpha_parse_field "iteration")
MAX_ITERATIONS=$(ralpha_parse_field "max_iterations")
MODE=$(ralpha_parse_field "mode")
COMPLETION_PROMISE=$(ralpha_parse_field "completion_promise")
VERIFY_COMMAND=$(ralpha_parse_field "verify_command")
VERIFY_PASSED=$(ralpha_parse_field "verify_passed")
TEAM_NAME=$(ralpha_parse_field "team_name")
TEAM_SIZE=$(ralpha_parse_field "team_size")
STARTED_AT=$(ralpha_parse_field "started_at")
OBJECTIVE=$(ralpha_parse_prompt)

ENDED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

GIT_LOG=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_LOG=$(git log --oneline --since="$STARTED_AT" 2>/dev/null || echo "(no commits)")
fi

# Resolve display values
MAX_DISPLAY=$( [[ $MAX_ITERATIONS -gt 0 ]] && echo "$MAX_ITERATIONS" || echo "unlimited" )
if [[ "$VERIFY_PASSED" = "true" ]]; then
  VERIFY_DISPLAY="PASSED"
elif [[ "$VERIFY_COMMAND" = "null" ]]; then
  VERIFY_DISPLAY="N/A"
else
  VERIFY_DISPLAY="FAILED"
fi
PROMISE_DISPLAY=$( [[ "$COMPLETION_PROMISE" != "null" ]] && echo "\`$COMPLETION_PROMISE\`" || echo "none" )
VERIFY_CMD_DISPLAY=$( [[ "$VERIFY_COMMAND" != "null" ]] && echo "\`$VERIFY_COMMAND\`" || echo "none" )

cat > "$REPORT_FILE" <<EOF
# ralpha-team Report

## Session Summary

| Field | Value |
|-------|-------|
| Mode | $MODE |
| Iterations | $ITERATION / $MAX_DISPLAY |
| Team | $TEAM_NAME (size: $TEAM_SIZE) |
| Started | $STARTED_AT |
| Ended | $ENDED_AT |
| Completion | $COMPLETION_REASON |
| Verification | $VERIFY_DISPLAY |

## Objective

$OBJECTIVE

## Configuration

- **Completion promise**: $PROMISE_DISPLAY
- **Verify command**: $VERIFY_CMD_DISPLAY
- **Max iterations**: $MAX_DISPLAY

## Git History

\`\`\`
$GIT_LOG
\`\`\`
EOF

qa_log "report" "generated" "file=$REPORT_FILE" "completion_reason=$COMPLETION_REASON"
echo "Report generated: $REPORT_FILE"
