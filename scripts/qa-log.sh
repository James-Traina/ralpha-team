#!/usr/bin/env bash

# QA Logger for ralpha-team
# Source this file, then call qa_log() to write structured JSONL entries.
# Always-on when a session is active (negligible overhead: one file append per call).
#
# Usage:
#   source "$SCRIPT_DIR/qa-log.sh"
#   qa_log "stop-hook" "promise_check" "detected=true" "expected=ALL DONE"
#
# Log format (JSONL, one entry per line):
#   {"ts":"2026-02-26T10:00:00Z","component":"stop-hook","event":"promise_check","data":{"detected":"true","expected":"ALL DONE"}}

RALPHA_QA_LOG=".claude/ralpha-qa.jsonl"

# Write a structured log entry. Numeric values are auto-detected and stored as numbers.
# Args: component event [key=value ...]
qa_log() {
  [[ -d .claude ]] || return 0

  local component="${1:-unknown}"
  local event="${2:-unknown}"
  shift 2 2>/dev/null || true

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Build all jq args and the data expression in one pass (1 jq call total)
  local jq_args=(--arg ts "$ts" --arg c "$component" --arg e "$event")
  local data_expr="{"
  local sep=""
  local i=0
  for kv in "$@"; do
    local key="${kv%%=*}"
    local val="${kv#*=}"
    if [[ "$val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
      jq_args+=(--argjson "v$i" "$val")
    else
      jq_args+=(--arg "v$i" "$val")
    fi
    data_expr+="${sep}\"${key}\":\$v${i}"
    sep=","
    i=$((i + 1))
  done
  data_expr+="}"

  jq -cn "${jq_args[@]}" \
    "{\"ts\":\$ts,\"component\":\$c,\"event\":\$e,\"data\":$data_expr}" \
    >> "$RALPHA_QA_LOG" 2>/dev/null || true
}

# Start a timer (stores epoch seconds in a global)
_QA_TIMER_START=""

qa_timer_start() {
  _QA_TIMER_START=$(date +%s)
}

# Get elapsed seconds since last qa_timer_start. Returns 0 if timer was never started.
qa_timer_elapsed() {
  [[ -n "$_QA_TIMER_START" ]] || { echo "0"; return; }
  local now
  now=$(date +%s)
  echo $(( now - _QA_TIMER_START ))
}
