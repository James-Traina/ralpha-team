#!/bin/bash

# Ralpha-Team Report Generator
# Produces ralpha-report.md with structured summary of the session.

set -euo pipefail

COMPLETION_REASON="${1:-unknown}"
RALPHA_STATE_FILE=".claude/ralpha-team.local.md"
REPORT_FILE="ralpha-report.md"

if [[ ! -f "$RALPHA_STATE_FILE" ]]; then
  echo "No active ralpha session - cannot generate report" >&2
  exit 1
fi

# Parse state file
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPHA_STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
MODE=$(echo "$FRONTMATTER" | grep '^mode:' | sed 's/mode: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')
VERIFY_COMMAND=$(echo "$FRONTMATTER" | grep '^verify_command:' | sed 's/verify_command: *//' | sed 's/^"\(.*\)"$/\1/')
VERIFY_PASSED=$(echo "$FRONTMATTER" | grep '^verify_passed:' | sed 's/verify_passed: *//')
TEAM_NAME=$(echo "$FRONTMATTER" | grep '^team_name:' | sed 's/team_name: *//')
TEAM_SIZE=$(echo "$FRONTMATTER" | grep '^team_size:' | sed 's/team_size: *//')
STARTED_AT=$(echo "$FRONTMATTER" | grep '^started_at:' | sed 's/started_at: *//' | sed 's/^"\(.*\)"$/\1/')
OBJECTIVE=$(awk '/^---$/{i++; next} i>=2' "$RALPHA_STATE_FILE")

ENDED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Get git log since session start (best-effort)
GIT_LOG=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_LOG=$(git log --oneline --since="$STARTED_AT" 2>/dev/null || echo "(no commits)")
fi

# Build report
cat > "$REPORT_FILE" <<EOF
# Ralpha-Team Report

## Session Summary

| Field | Value |
|-------|-------|
| Mode | $MODE |
| Iterations | $ITERATION / $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi) |
| Team | $TEAM_NAME (size: $TEAM_SIZE) |
| Started | $STARTED_AT |
| Ended | $ENDED_AT |
| Completion | $COMPLETION_REASON |
| Verification | $(if [[ "$VERIFY_PASSED" = "true" ]]; then echo "PASSED"; elif [[ "$VERIFY_COMMAND" = "null" ]]; then echo "N/A"; else echo "FAILED"; fi) |

## Objective

$OBJECTIVE

## Configuration

- **Completion promise**: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "\`$COMPLETION_PROMISE\`"; else echo "none"; fi)
- **Verify command**: $(if [[ "$VERIFY_COMMAND" != "null" ]]; then echo "\`$VERIFY_COMMAND\`"; else echo "none"; fi)
- **Max iterations**: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)

## Git History

\`\`\`
$GIT_LOG
\`\`\`
EOF

echo "Report generated: $REPORT_FILE"
