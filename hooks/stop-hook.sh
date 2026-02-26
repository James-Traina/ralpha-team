#!/bin/bash

# Ralpha-Team Stop Hook
# Prevents session exit when a ralpha loop is active.
# Solo mode: re-injects same prompt. Team mode: re-injects with teammate coordination instructions.

set -euo pipefail

HOOK_INPUT=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPT_DIR/parse-state.sh"
source "$SCRIPT_DIR/qa-log.sh"

# No active loop - allow exit
if [[ ! -f "$RALPHA_STATE_FILE" ]]; then
  exit 0
fi

ralpha_load_frontmatter
ITERATION=$(ralpha_parse_field "iteration")
MAX_ITERATIONS=$(ralpha_parse_field "max_iterations")
MODE=$(ralpha_parse_field "mode")
COMPLETION_PROMISE=$(ralpha_parse_field "completion_promise")
VERIFY_COMMAND=$(ralpha_parse_field "verify_command")

qa_log_num "stop-hook" "invoked" "iteration=$ITERATION" "max_iterations=$MAX_ITERATIONS" "mode=$MODE"

# --- Helpers ---

abort_with_warning() {
  qa_log "stop-hook" "abort" "reason=$1"
  echo "WARNING: Ralpha: $1. Stopping." >&2
  rm -f "$RALPHA_STATE_FILE"
  exit 0
}

complete_session() {
  local reason="$1"
  qa_log "stop-hook" "session_complete" "reason=$reason"
  echo "Ralpha: $2"
  if [[ -f "$SCRIPT_DIR/generate-report.sh" ]]; then
    bash "$SCRIPT_DIR/generate-report.sh" "$reason" 2>/dev/null || true
  fi
  rm -f "$RALPHA_STATE_FILE"
  exit 0
}

bump_iteration() {
  local next=$((ITERATION + 1))
  local tmp="${RALPHA_STATE_FILE}.tmp.$$"
  # Only modify within frontmatter (n==1), not the prompt body
  awk -v val="$next" '
    BEGIN{n=0}
    /^---$/{n++; print; next}
    n==1 && /^iteration:/{print "iteration: " val; next}
    {print}
  ' "$RALPHA_STATE_FILE" > "$tmp"
  mv "$tmp" "$RALPHA_STATE_FILE"
  echo "$next"
}

block_and_continue() {
  local sys_msg="$1"
  local prompt
  prompt=$(ralpha_parse_prompt)
  qa_log "stop-hook" "decision" "action=block" "system_msg=$sys_msg"
  jq -n --arg prompt "$prompt" --arg msg "$sys_msg" \
    '{ "decision": "block", "reason": $prompt, "systemMessage": $msg }'
  exit 0
}

# --- Validation ---

if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  abort_with_warning "State file corrupted (iteration: '$ITERATION')"
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  abort_with_warning "State file corrupted (max_iterations: '$MAX_ITERATIONS')"
fi

# --- Max iterations check ---

if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  qa_log_num "stop-hook" "max_iterations_reached" "iteration=$ITERATION" "max_iterations=$MAX_ITERATIONS"
  complete_session "max_iterations_reached" "Max iterations ($MAX_ITERATIONS) reached."
fi

# --- Parse transcript for last assistant message ---

TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  abort_with_warning "Transcript file not found ($TRANSCRIPT_PATH)"
fi

if ! grep -q '"role"[[:space:]]*:[[:space:]]*"assistant"' "$TRANSCRIPT_PATH"; then
  abort_with_warning "No assistant messages in transcript"
fi

LAST_LINE=$(grep '"role"[[:space:]]*:[[:space:]]*"assistant"' "$TRANSCRIPT_PATH" | tail -1)
if [[ -z "$LAST_LINE" ]]; then
  abort_with_warning "Failed to extract last assistant message"
fi

set +e
LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>&1)
JQ_EXIT=$?
set -e

if [[ $JQ_EXIT -ne 0 ]] || [[ -z "$LAST_OUTPUT" ]]; then
  abort_with_warning "Failed to parse assistant message"
fi

MSG_LENGTH=${#LAST_OUTPUT}
qa_log_num "stop-hook" "transcript_parsed" "msg_length=$MSG_LENGTH"

# --- Check completion promise ---

PROMISE_DETECTED=false
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  # Case-insensitive comparison with whitespace normalization
  PROMISE_LOWER=$(echo "$PROMISE_TEXT" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  EXPECTED_LOWER=$(echo "$COMPLETION_PROMISE" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [[ -n "$PROMISE_LOWER" ]] && [[ "$PROMISE_LOWER" = "$EXPECTED_LOWER" ]]; then
    PROMISE_DETECTED=true
  fi
  qa_log "stop-hook" "promise_check" "detected=$PROMISE_DETECTED" "text=$PROMISE_TEXT" "expected=$COMPLETION_PROMISE"
fi

# --- Dual-gate: promise + verification ---

if [[ "$PROMISE_DETECTED" = true ]]; then
  if [[ "$VERIFY_COMMAND" != "null" ]] && [[ -n "$VERIFY_COMMAND" ]]; then
    qa_timer_start _VERIFY_TIMER
    set +e
    VERIFY_RESULT=$(bash "$SCRIPT_DIR/verify-completion.sh" 2>&1)
    VERIFY_EXIT=$?
    set -e
    VERIFY_ELAPSED=$(qa_timer_elapsed _VERIFY_TIMER)
    qa_log_num "stop-hook" "verify_after_promise" "exit_code=$VERIFY_EXIT" "duration_s=$VERIFY_ELAPSED"

    if [[ $VERIFY_EXIT -eq 0 ]]; then
      local_tmp="${RALPHA_STATE_FILE}.tmp.$$"
      # Only modify within frontmatter (n==1), not the prompt body
      awk '
        BEGIN{n=0}
        /^---$/{n++; print; next}
        n==1 && /^verify_passed:/{print "verify_passed: true"; next}
        {print}
      ' "$RALPHA_STATE_FILE" > "$local_tmp"
      mv "$local_tmp" "$RALPHA_STATE_FILE"
      complete_session "completed" "Promise detected AND verification passed."
    else
      NEXT=$(bump_iteration)
      VERIFY_SNIPPET=$(echo "$VERIFY_RESULT" | tail -20)
      qa_log_num "stop-hook" "verify_failed_after_promise" "next_iteration=$NEXT"
      block_and_continue "Ralpha iteration $NEXT | Promise detected but VERIFICATION FAILED. Fix the issues and try again. Verification output: $VERIFY_SNIPPET"
    fi
  else
    complete_session "completed" "Promise detected. Completion confirmed."
  fi
fi

# --- Not complete: continue loop ---

NEXT=$(bump_iteration)

if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_MSG="To complete: output <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE)"
else
  PROMISE_MSG="No completion promise set - loop runs until max iterations"
fi

if [[ "$MODE" = "team" ]]; then
  SYSTEM_MSG="Ralpha iteration $NEXT [TEAM mode] | $PROMISE_MSG | Check teammate inboxes and task status."
else
  SYSTEM_MSG="Ralpha iteration $NEXT [SOLO mode] | $PROMISE_MSG"
fi

PROMPT_TEXT=$(ralpha_parse_prompt)
if [[ -z "$PROMPT_TEXT" ]]; then
  abort_with_warning "No prompt text in state file"
fi

block_and_continue "$SYSTEM_MSG"
