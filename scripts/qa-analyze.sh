#!/bin/bash

# QA Analyzer and Report Generator for ralpha-team
# Reads .claude/ralpha-qa.jsonl, detects patterns, outputs prioritized findings.
# Also generates session reports via --report flag.
#
# Usage (--report must be the first argument; modes are mutually exclusive):
#   bash scripts/qa-analyze.sh [log-file]          # QA analysis → .claude/ralpha-qa-findings.md
#     Default log: .claude/ralpha-qa.jsonl
#   bash scripts/qa-analyze.sh --report <reason>    # Session report → ralpha-report.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# jq is required by both modes (report mode uses qa-log.sh which depends on jq)
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' is required but was not found." >&2
  exit 1
fi

# --- Session report mode ---
if [[ "${1:-}" = "--report" ]]; then
  COMPLETION_REASON="${2:-unknown}"
  REPORT_FILE="ralpha-report.md"

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

  if [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] && [[ $MAX_ITERATIONS -gt 0 ]]; then
    MAX_DISPLAY="$MAX_ITERATIONS"
  else
    MAX_DISPLAY="unlimited"
  fi
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
  exit 0
fi

# --- QA analysis mode ---

LOG_FILE="${1:-.claude/ralpha-qa.jsonl}"
mkdir -p .claude
OUTPUT_FILE=".claude/ralpha-qa-findings.md"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "No QA log found at $LOG_FILE" >&2
  echo "Run a Ralpha session first to generate telemetry." >&2
  exit 1
fi

TOTAL_ENTRIES=$(wc -l < "$LOG_FILE" | tr -d ' ')
if [[ "$TOTAL_ENTRIES" -eq 0 ]]; then
  echo "QA log is empty" >&2
  exit 1
fi

# --- Extract metrics ---

# Session info
SESSION_MODE=$(jq -r 'select(.component=="setup" and .event=="session_start") | .data.mode' "$LOG_FILE" | tail -1)
SESSION_MODE="${SESSION_MODE:-unknown}"
MAX_ITER=$(jq -r 'select(.component=="setup" and .event=="session_start") | .data.max_iterations' "$LOG_FILE" | tail -1)
MAX_ITER="${MAX_ITER:-0}"

# Count events by type
STOP_INVOCATIONS=$(jq -r 'select(.component=="stop-hook" and .event=="invoked") | .event' "$LOG_FILE" | wc -l | tr -d ' ')
PROMISE_CHECKS=$(jq -r 'select(.component=="stop-hook" and .event=="promise_check") | .event' "$LOG_FILE" | wc -l | tr -d ' ')
PROMISE_DETECTED=$(jq -r 'select(.component=="stop-hook" and .event=="promise_check" and .data.detected=="true") | .event' "$LOG_FILE" | wc -l | tr -d ' ')
PROMISE_MISSED=$(( PROMISE_CHECKS - PROMISE_DETECTED ))
VERIFY_RUNS=$(jq -r 'select(.component=="verify") | .event' "$LOG_FILE" | wc -l | tr -d ' ')
VERIFY_PASSED=$(jq -r 'select(.component=="verify" and .event=="passed") | .event' "$LOG_FILE" | wc -l | tr -d ' ')
VERIFY_FAILED=$(jq -r 'select(.component=="verify" and .event=="failed") | .event' "$LOG_FILE" | wc -l | tr -d ' ')
ABORTS=$(jq -r 'select(.component=="stop-hook" and .event=="abort") | .event' "$LOG_FILE" | wc -l | tr -d ' ')
BLOCKS=$(jq -r 'select(.component=="stop-hook" and .event=="decision" and .data.action=="block") | .event' "$LOG_FILE" | wc -l | tr -d ' ')
COMPLETIONS=$(jq -r 'select(.component=="stop-hook" and .event=="session_complete") | .event' "$LOG_FILE" | wc -l | tr -d ' ')
IDLE_NUDGES=$(jq -r 'select(.component=="idle-hook" and .event=="nudge") | .event' "$LOG_FILE" | wc -l | tr -d ' ')
TASK_GATES_BLOCKED=$(jq -r 'select(.component=="task-completed" and .event=="gate_blocked") | .event' "$LOG_FILE" | wc -l | tr -d ' ')

# Last iteration reached
LAST_ITERATION=$(jq -r 'select(.component=="stop-hook" and .event=="invoked") | .data.iteration' "$LOG_FILE" | sort -n | tail -1)
LAST_ITERATION="${LAST_ITERATION:-0}"

# Verification timing
VERIFY_DURATIONS=$(jq -r 'select(.component=="verify") | .data.duration_s // 0' "$LOG_FILE")
MAX_VERIFY_DURATION=0
TOTAL_VERIFY_DURATION=0
for d in $VERIFY_DURATIONS; do
  d=${d%.*}   # truncate fractional part
  d=${d:-0}
  if [[ "$d" =~ ^[0-9]+$ ]]; then
    TOTAL_VERIFY_DURATION=$((TOTAL_VERIFY_DURATION + d))
    if [[ "$d" -gt "$MAX_VERIFY_DURATION" ]]; then
      MAX_VERIFY_DURATION=$d
    fi
  fi
done

# Completion reason
COMPLETION_REASON=$(jq -r 'select(.component=="stop-hook" and .event=="session_complete") | .data.reason' "$LOG_FILE" | tail -1)
COMPLETION_REASON="${COMPLETION_REASON:-none}"

# --- Pattern Detection ---

FINDINGS_MUST_FIX=()
FINDINGS_SHOULD_FIX=()
FINDINGS_NICE_TO_HAVE=()

# MUST-FIX: Parse/abort failures
if [[ "$ABORTS" -gt 0 ]]; then
  ABORT_REASONS=$(jq -r 'select(.component=="stop-hook" and .event=="abort") | .data.reason' "$LOG_FILE")
  FINDINGS_MUST_FIX+=("**Parse/abort failure** ($ABORTS occurrence(s)): $ABORT_REASONS|File: \`hooks/stop-hook.sh\`|Fix: Check state file integrity. Ensure transcript path is valid and contains assistant messages.")
fi

# MUST-FIX: Verification never passes (promise detected 2+ times but verify always fails)
if [[ "$PROMISE_DETECTED" -ge 2 ]] && [[ "$VERIFY_PASSED" -eq 0 ]] && [[ "$VERIFY_FAILED" -gt 0 ]]; then
  FINDINGS_MUST_FIX+=("**Verification never passes** (promise detected $PROMISE_DETECTED times, verify failed $VERIFY_FAILED times, never passed)|File: \`scripts/verify-completion.sh\`|Fix: The verify command may be wrong, environment-dependent, or testing the wrong thing. Run it manually outside the hook context.")
fi

# MUST-FIX: Stuck loop (5+ total blocks with no promise attempt)
if [[ "$BLOCKS" -ge 5 ]] && [[ "$PROMISE_CHECKS" -eq 0 ]]; then
  FINDINGS_MUST_FIX+=("**Stuck loop** ($BLOCKS blocks, 0 promise attempts): The agent never attempted to complete.|File: \`commands/team.md\` or \`commands/solo.md\`|Fix: Ensure the completion promise instruction is clear. The agent may not know how to signal completion.")
fi

# SHOULD-FIX: Excessive iterations (>=80% of max used)
if [[ "$MAX_ITER" -gt 0 ]] && [[ "$LAST_ITERATION" -gt 0 ]]; then
  USAGE_PCT=$(( (LAST_ITERATION * 100) / MAX_ITER ))
  if [[ "$USAGE_PCT" -ge 80 ]]; then
    FINDINGS_SHOULD_FIX+=("**Excessive iterations** (used $LAST_ITERATION/$MAX_ITER = ${USAGE_PCT}%)|File: task decomposition or objective complexity|Fix: Break the objective into smaller sub-tasks, or increase max-iterations if the task genuinely needs more time.")
  fi
fi

# SHOULD-FIX: Flaky verification (mix of pass and fail)
if [[ "$VERIFY_PASSED" -gt 0 ]] && [[ "$VERIFY_FAILED" -gt 0 ]]; then
  FINDINGS_SHOULD_FIX+=("**Flaky verification** ($VERIFY_PASSED passes, $VERIFY_FAILED failures): Non-deterministic results.|File: \`scripts/verify-completion.sh\` and the verify command itself|Fix: Ensure the verification command is deterministic. Check for race conditions, timing issues, or external dependencies.")
fi

# SHOULD-FIX: Idle waste (3+ nudges in team mode)
if [[ "$IDLE_NUDGES" -ge 3 ]]; then
  FINDINGS_SHOULD_FIX+=("**Idle teammate waste** ($IDLE_NUDGES idle nudges): Teammates going idle frequently without claiming tasks.|File: \`commands/team.md\` Phase 1 (task decomposition)|Fix: Create more granular tasks. Ensure tasks are unblocked and claimable. Consider reducing team size.")
fi

# SHOULD-FIX: Task completion gates blocking often
if [[ "$TASK_GATES_BLOCKED" -ge 3 ]]; then
  FINDINGS_SHOULD_FIX+=("**Task gate blocking** ($TASK_GATES_BLOCKED blocks): Teammates marking tasks complete but verification failing.|File: \`hooks/task-completed-hook.sh\`|Fix: Teammates may not be running verification before marking tasks done. Add self-check instructions to teammate prompts.")
fi

# NICE-TO-HAVE: No verification configured
if [[ "$VERIFY_RUNS" -eq 0 ]] && [[ "$STOP_INVOCATIONS" -gt 0 ]]; then
  FINDINGS_NICE_TO_HAVE+=("**No verification command**: Session ran without --verify-command. Completion relied solely on the promise gate.|Suggestion: Add a verification command for objective quality assurance.")
fi

# NICE-TO-HAVE: Slow verification
if [[ "$MAX_VERIFY_DURATION" -ge 30 ]]; then
  FINDINGS_NICE_TO_HAVE+=("**Slow verification** (max ${MAX_VERIFY_DURATION}s, total ${TOTAL_VERIFY_DURATION}s across $VERIFY_RUNS runs): Verification overhead is high.|File: the --verify-command itself|Fix: Optimize the test command, or run only relevant tests (e.g., pytest -x for fail-fast).")
fi

# NICE-TO-HAVE: Quick completion
if [[ "$LAST_ITERATION" -le 2 ]] && [[ "$COMPLETIONS" -gt 0 ]]; then
  FINDINGS_NICE_TO_HAVE+=("**Quick completion** (completed in $LAST_ITERATION iterations): Task may be simpler than expected.|Suggestion: This is fine. Consider using solo mode for simple tasks.")
fi

# NICE-TO-HAVE: Promise attempts that didn't match
if [[ "$PROMISE_MISSED" -gt 0 ]]; then
  MISSED_TEXTS=$(jq -r 'select(.component=="stop-hook" and .event=="promise_check" and .data.detected=="false") | .data.text' "$LOG_FILE" | head -5)
  FINDINGS_NICE_TO_HAVE+=("**Mismatched promise attempts** ($PROMISE_MISSED times): Agent output promise tags but text didn't match expected.|Texts attempted: $MISSED_TEXTS|Suggestion: Check if the completion promise wording is too specific.")
fi

# --- Generate Report ---

MUST_COUNT=${#FINDINGS_MUST_FIX[@]}
SHOULD_COUNT=${#FINDINGS_SHOULD_FIX[@]}
NICE_COUNT=${#FINDINGS_NICE_TO_HAVE[@]}
TOTAL_FINDINGS=$((MUST_COUNT + SHOULD_COUNT + NICE_COUNT))

# Health score: penalizes by severity so a single MUST-FIX dominates the score.
# Weights: MUST-FIX=30 (one drops to 70), SHOULD-FIX=10, NICE-TO-HAVE=2. Floor at 0.
HEALTH=$((100 - MUST_COUNT * 30 - SHOULD_COUNT * 10 - NICE_COUNT * 2))
if [[ "$HEALTH" -lt 0 ]]; then HEALTH=0; fi

cat > "$OUTPUT_FILE" <<EOF
# ralpha-team QA Findings

**Health Score: ${HEALTH}/100** | Mode: $SESSION_MODE | Iterations: $LAST_ITERATION/$MAX_ITER | Outcome: $COMPLETION_REASON

## Metrics

| Metric | Value |
|--------|-------|
| Stop hook invocations | $STOP_INVOCATIONS |
| Promise checks | $PROMISE_CHECKS ($PROMISE_DETECTED detected, $PROMISE_MISSED missed) |
| Verification runs | $VERIFY_RUNS ($VERIFY_PASSED passed, $VERIFY_FAILED failed) |
| Verification time | ${TOTAL_VERIFY_DURATION}s total, ${MAX_VERIFY_DURATION}s max |
| Aborts | $ABORTS |
| Idle nudges | $IDLE_NUDGES |
| Task gate blocks | $TASK_GATES_BLOCKED |
| Log entries | $TOTAL_ENTRIES |

## Findings ($TOTAL_FINDINGS total)

EOF

if [[ "$MUST_COUNT" -gt 0 ]]; then
  echo "### MUST-FIX ($MUST_COUNT)" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  for i in "${!FINDINGS_MUST_FIX[@]}"; do
    IFS='|' read -ra PARTS <<< "${FINDINGS_MUST_FIX[$i]}"
    echo "$((i+1)). ${PARTS[0]}" >> "$OUTPUT_FILE"
    for part in "${PARTS[@]:1}"; do
      echo "   - $part" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
  done
fi

if [[ "$SHOULD_COUNT" -gt 0 ]]; then
  echo "### SHOULD-FIX ($SHOULD_COUNT)" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  for i in "${!FINDINGS_SHOULD_FIX[@]}"; do
    IFS='|' read -ra PARTS <<< "${FINDINGS_SHOULD_FIX[$i]}"
    echo "$((i+1)). ${PARTS[0]}" >> "$OUTPUT_FILE"
    for part in "${PARTS[@]:1}"; do
      echo "   - $part" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
  done
fi

if [[ "$NICE_COUNT" -gt 0 ]]; then
  echo "### NICE-TO-HAVE ($NICE_COUNT)" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  for i in "${!FINDINGS_NICE_TO_HAVE[@]}"; do
    IFS='|' read -ra PARTS <<< "${FINDINGS_NICE_TO_HAVE[$i]}"
    echo "$((i+1)). ${PARTS[0]}" >> "$OUTPUT_FILE"
    for part in "${PARTS[@]:1}"; do
      echo "   - $part" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
  done
fi

if [[ "$TOTAL_FINDINGS" -eq 0 ]]; then
  echo "No issues detected. Session looks healthy." >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

# Cycle driver: suggest next action
cat >> "$OUTPUT_FILE" <<'EOF'
## Next Action

To use these findings as input for a self-improvement cycle:

```bash
/ralpha-team:solo Address the MUST-FIX findings in .claude/ralpha-qa-findings.md \
  --completion-promise 'ALL FINDINGS ADDRESSED' \
  --verify-command 'bash tests/test-runner.sh' \
  --max-iterations 10
```
EOF

echo "QA analysis complete: $OUTPUT_FILE ($TOTAL_FINDINGS findings, health: $HEALTH/100)"
