#!/bin/bash

# Ralpha-Team Stop Hook
# Hybrid A+B: prevents session exit when a ralpha loop is active.
# Solo mode: re-injects same prompt (identical to ralph-loop).
# Team mode: also checks teammate status and verification gates.
#
# Adapted from the official ralph-loop plugin stop-hook.sh
# (anthropics/claude-plugins-official/plugins/ralph-loop)

set -euo pipefail

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

# Check if ralpha is active
RALPHA_STATE_FILE=".claude/ralpha-team.local.md"

if [[ ! -f "$RALPHA_STATE_FILE" ]]; then
  # No active loop - allow exit
  exit 0
fi

# Parse markdown frontmatter (YAML between ---) and extract values
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPHA_STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
MODE=$(echo "$FRONTMATTER" | grep '^mode:' | sed 's/mode: *//')
# Extract completion_promise and strip surrounding quotes if present
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')
# Extract verify_command and strip quotes
VERIFY_COMMAND=$(echo "$FRONTMATTER" | grep '^verify_command:' | sed 's/verify_command: *//' | sed 's/^"\(.*\)"$/\1/')

# Validate numeric fields before arithmetic operations
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "WARNING: Ralpha state file corrupted (iteration: '$ITERATION'). Stopping." >&2
  rm "$RALPHA_STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "WARNING: Ralpha state file corrupted (max_iterations: '$MAX_ITERATIONS'). Stopping." >&2
  rm "$RALPHA_STATE_FILE"
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Ralpha: Max iterations ($MAX_ITERATIONS) reached."

  # Generate report before stopping
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
  if [[ -f "$SCRIPT_DIR/generate-report.sh" ]]; then
    bash "$SCRIPT_DIR/generate-report.sh" "max_iterations_reached" 2>/dev/null || true
  fi

  rm "$RALPHA_STATE_FILE"
  exit 0
fi

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "WARNING: Ralpha: Transcript file not found ($TRANSCRIPT_PATH). Stopping." >&2
  rm "$RALPHA_STATE_FILE"
  exit 0
fi

# Read last assistant message from transcript (JSONL format)
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "WARNING: Ralpha: No assistant messages in transcript. Stopping." >&2
  rm "$RALPHA_STATE_FILE"
  exit 0
fi

LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
if [[ -z "$LAST_LINE" ]]; then
  echo "WARNING: Ralpha: Failed to extract last assistant message. Stopping." >&2
  rm "$RALPHA_STATE_FILE"
  exit 0
fi

LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>&1)

if [[ $? -ne 0 ]] || [[ -z "$LAST_OUTPUT" ]]; then
  echo "WARNING: Ralpha: Failed to parse assistant message. Stopping." >&2
  rm "$RALPHA_STATE_FILE"
  exit 0
fi

# Check for completion promise (only if set)
PROMISE_DETECTED=false
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

  # Use = for literal string comparison (not glob pattern matching)
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    PROMISE_DETECTED=true
  fi
fi

# If promise detected, check verification gate (dual-gate: promise + verify)
if [[ "$PROMISE_DETECTED" = true ]]; then
  if [[ "$VERIFY_COMMAND" != "null" ]] && [[ -n "$VERIFY_COMMAND" ]]; then
    # Run verification command
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
    VERIFY_RESULT=$(bash "$SCRIPT_DIR/verify-completion.sh" 2>&1)
    VERIFY_EXIT=$?

    if [[ $VERIFY_EXIT -eq 0 ]]; then
      # Both gates passed - allow completion
      echo "Ralpha: Promise detected AND verification passed."

      # Update verify_passed in state
      TEMP_FILE="${RALPHA_STATE_FILE}.tmp.$$"
      sed "s/^verify_passed: .*/verify_passed: true/" "$RALPHA_STATE_FILE" > "$TEMP_FILE"
      mv "$TEMP_FILE" "$RALPHA_STATE_FILE"

      # Generate final report
      if [[ -f "$SCRIPT_DIR/generate-report.sh" ]]; then
        bash "$SCRIPT_DIR/generate-report.sh" "completed" 2>/dev/null || true
      fi

      rm "$RALPHA_STATE_FILE"
      exit 0
    else
      # Promise detected but verification failed - continue loop
      NEXT_ITERATION=$((ITERATION + 1))
      TEMP_FILE="${RALPHA_STATE_FILE}.tmp.$$"
      sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$RALPHA_STATE_FILE" > "$TEMP_FILE"
      mv "$TEMP_FILE" "$RALPHA_STATE_FILE"

      PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPHA_STATE_FILE")

      VERIFY_SNIPPET=$(echo "$VERIFY_RESULT" | tail -20)

      jq -n \
        --arg prompt "$PROMPT_TEXT" \
        --arg msg "Ralpha iteration $NEXT_ITERATION | Promise detected but VERIFICATION FAILED. Fix the issues and try again. Verification output: $VERIFY_SNIPPET" \
        '{
          "decision": "block",
          "reason": $prompt,
          "systemMessage": $msg
        }'
      exit 0
    fi
  else
    # No verify command - promise alone is sufficient
    echo "Ralpha: Promise detected. Completion confirmed."

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
    if [[ -f "$SCRIPT_DIR/generate-report.sh" ]]; then
      bash "$SCRIPT_DIR/generate-report.sh" "completed" 2>/dev/null || true
    fi

    rm "$RALPHA_STATE_FILE"
    exit 0
  fi
fi

# Not complete - continue loop with SAME PROMPT
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt (everything after the closing ---)
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPHA_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "WARNING: Ralpha: No prompt text in state file. Stopping." >&2
  rm "$RALPHA_STATE_FILE"
  exit 0
fi

# Update iteration in frontmatter (portable across macOS and Linux)
TEMP_FILE="${RALPHA_STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$RALPHA_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$RALPHA_STATE_FILE"

# Build system message with iteration count, mode, and completion info
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_MSG="To complete: output <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE)"
else
  PROMISE_MSG="No completion promise set - loop runs until max iterations"
fi

if [[ "$MODE" = "team" ]]; then
  SYSTEM_MSG="Ralpha iteration $NEXT_ITERATION [TEAM mode] | $PROMISE_MSG | Check teammate inboxes and task status."
else
  SYSTEM_MSG="Ralpha iteration $NEXT_ITERATION [SOLO mode] | $PROMISE_MSG"
fi

# Output JSON to block the stop and feed prompt back
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
