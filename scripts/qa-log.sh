#!/bin/bash

# QA Logger for Ralpha-Team
# Source this file, then call qa_log() to write structured JSONL entries.
# Always-on when a session is active (negligible overhead: one file append per call).
#
# Usage:
#   source "$SCRIPT_DIR/qa-log.sh"
#   qa_log "stop-hook" "promise_check" detected=true expected="ALL DONE"
#
# Log format (JSONL, one entry per line):
#   {"ts":"2026-02-26T10:00:00Z","component":"stop-hook","event":"promise_check","data":{"detected":"true","expected":"ALL DONE"}}

RALPHA_QA_LOG=".claude/ralpha-qa.jsonl"

# Write a structured log entry.
# Args: component event [key=value ...]
qa_log() {
  # No-op if .claude/ dir doesn't exist (no active session)
  [[ -d .claude ]] || return 0

  local component="${1:-unknown}"
  local event="${2:-unknown}"
  shift 2 2>/dev/null || true

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Build data object from remaining key=value args
  local data_json="{}"
  for kv in "$@"; do
    local key="${kv%%=*}"
    local val="${kv#*=}"
    # Use jq to safely escape values
    data_json=$(echo "$data_json" | jq -c --arg k "$key" --arg v "$val" '. + {($k): $v}')
  done

  # Write complete entry
  jq -cn \
    --arg ts "$ts" \
    --arg component "$component" \
    --arg event "$event" \
    --argjson data "$data_json" \
    '{"ts":$ts,"component":$component,"event":$event,"data":$data}' \
    >> "$RALPHA_QA_LOG" 2>/dev/null || true
}

# Log with numeric values (avoids quoting numbers as strings)
# Args: component event [key=value ...] where values may be numeric
qa_log_num() {
  [[ -d .claude ]] || return 0

  local component="${1:-unknown}"
  local event="${2:-unknown}"
  shift 2 2>/dev/null || true

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  local data_json="{}"
  for kv in "$@"; do
    local key="${kv%%=*}"
    local val="${kv#*=}"
    # If value is numeric, insert as number; otherwise as string
    if [[ "$val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
      data_json=$(echo "$data_json" | jq -c --arg k "$key" --argjson v "$val" '. + {($k): $v}')
    else
      data_json=$(echo "$data_json" | jq -c --arg k "$key" --arg v "$val" '. + {($k): $v}')
    fi
  done

  jq -cn \
    --arg ts "$ts" \
    --arg component "$component" \
    --arg event "$event" \
    --argjson data "$data_json" \
    '{"ts":$ts,"component":$component,"event":$event,"data":$data}' \
    >> "$RALPHA_QA_LOG" 2>/dev/null || true
}

# Start a timer (stores epoch seconds in a variable name)
qa_timer_start() {
  local varname="${1:-_QA_TIMER}"
  eval "$varname=$(date +%s)"
}

# Get elapsed seconds since timer start
qa_timer_elapsed() {
  local varname="${1:-_QA_TIMER}"
  local start_val
  eval "start_val=\$$varname"
  local now
  now=$(date +%s)
  echo $((now - start_val))
}
