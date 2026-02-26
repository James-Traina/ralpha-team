#!/bin/bash

# Tests for hooks/stop-hook.sh
# The stop hook reads JSON from stdin, reads state file, and outputs JSON decision.

setup_test_env

STOP_HOOK="$REPO_ROOT/hooks/stop-hook.sh"

# --- Helper: create a mock transcript JSONL file ---
create_transcript() {
  local assistant_text="$1"
  local transcript_file="$TEST_TMPDIR/transcript.jsonl"
  # Write a minimal JSONL with one assistant message
  printf '{"role":"assistant","message":{"content":[{"type":"text","text":"%s"}]}}\n' "$assistant_text" > "$transcript_file"
  echo "$transcript_file"
}

# --- Helper: create hook input JSON ---
hook_input() {
  local transcript_path="$1"
  printf '{"transcript_path":"%s"}' "$transcript_path"
}

# --- Helper: create state file ---
create_state() {
  local mode="${1:-solo}" iteration="${2:-1}" max="${3:-0}" promise="${4:-null}" verify="${5:-null}"
  local promise_yaml verify_yaml
  if [[ "$promise" = "null" ]]; then promise_yaml="null"; else promise_yaml="\"$promise\""; fi
  if [[ "$verify" = "null" ]]; then verify_yaml="null"; else verify_yaml="\"$verify\""; fi

  cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<EOF
---
active: true
mode: $mode
iteration: $iteration
max_iterations: $max
completion_promise: $promise_yaml
verify_command: $verify_yaml
verify_passed: false
team_name: ralpha-test
team_size: 3
persona: null
started_at: "2026-02-26T08:00:00Z"
---

Test prompt for stop hook
EOF
}

# ============================================================
# Test: No state file → exit 0 (allow exit)
# ============================================================

TRANSCRIPT=$(create_transcript "hello world")
set +e
OUTPUT=$(echo '{"transcript_path":"'"$TRANSCRIPT"'"}' | bash "$STOP_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "no state file → allow exit" 0 $EXIT
assert_eq "no state file → no JSON output" "" "$OUTPUT"

# ============================================================
# Test: Max iterations reached → allow exit, cleanup state
# ============================================================

create_state "solo" 10 10 "null" "null"
TRANSCRIPT=$(create_transcript "still working")

set +e
OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "max iterations → exit 0" 0 $EXIT
assert_contains "max iterations message" "Max iterations" "$OUTPUT"
assert_file_not_exists "state file cleaned up" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# ============================================================
# Test: No promise set → continue loop, bump iteration
# ============================================================

create_state "solo" 3 0 "null" "null"
TRANSCRIPT=$(create_transcript "did some work")

set +e
OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "no promise → exit 0 (block via JSON)" 0 $EXIT
assert_contains "outputs block decision" '"decision"' "$OUTPUT"
assert_contains "outputs block decision value" '"block"' "$OUTPUT"
assert_contains "re-injects prompt" "Test prompt for stop hook" "$OUTPUT"
assert_contains "iteration in system message" "iteration 4" "$OUTPUT"

# Check iteration was bumped in state file
source "$REPO_ROOT/scripts/parse-state.sh"
ralpha_load_frontmatter
assert_eq "iteration bumped to 4" "4" "$(ralpha_parse_field "iteration")"

# ============================================================
# Test: Promise detected (exact match) → complete
# ============================================================

create_state "solo" 2 0 "ALL DONE" "null"
TRANSCRIPT=$(create_transcript "I have finished. <promise>ALL DONE</promise> That is all.")

set +e
OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "promise match → exit 0" 0 $EXIT
assert_contains "promise detected" "Promise detected" "$OUTPUT"
assert_file_not_exists "state cleaned up after promise" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# ============================================================
# Test: Promise detected (case-insensitive) → complete
# ============================================================

create_state "solo" 2 0 "ALL DONE" "null"
TRANSCRIPT=$(create_transcript "<promise>all done</promise>")

set +e
OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "case-insensitive promise → exit 0" 0 $EXIT
assert_contains "case-insensitive promise detected" "Promise detected" "$OUTPUT"
assert_file_not_exists "state cleaned up after ci promise" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# ============================================================
# Test: Promise detected (extra whitespace) → complete
# ============================================================

create_state "solo" 2 0 "ALL DONE" "null"
TRANSCRIPT=$(create_transcript "<promise>  ALL DONE  </promise>")

set +e
OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "whitespace-trimmed promise → exit 0" 0 $EXIT
assert_contains "whitespace promise detected" "Promise detected" "$OUTPUT"

# ============================================================
# Test: Wrong promise → continue loop
# ============================================================

create_state "solo" 2 0 "ALL DONE" "null"
TRANSCRIPT=$(create_transcript "<promise>NOT DONE YET</promise>")

set +e
OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "wrong promise → exit 0 (block)" 0 $EXIT
assert_contains "wrong promise → continues loop" '"block"' "$OUTPUT"

# ============================================================
# Test: Promise + verify passes → complete
# ============================================================

create_state "solo" 2 0 "FIXED" "true"
TRANSCRIPT=$(create_transcript "<promise>FIXED</promise>")

set +e
OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "promise + verify pass → exit 0" 0 $EXIT
assert_contains "both gates pass" "verification passed" "$OUTPUT"

# ============================================================
# Test: Promise + verify fails → continue loop with feedback
# ============================================================

create_state "solo" 2 0 "FIXED" "false"
TRANSCRIPT=$(create_transcript "<promise>FIXED</promise>")

set +e
OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "promise + verify fail → exit 0 (block)" 0 $EXIT
assert_contains "verify failed feedback" "VERIFICATION FAILED" "$OUTPUT"
assert_contains "verify failed → block" '"block"' "$OUTPUT"

# ============================================================
# Test: Team mode system message
# ============================================================

create_state "team" 1 0 "DONE" "null"
TRANSCRIPT=$(create_transcript "working on it")

set +e
OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "team mode → exit 0" 0 $EXIT
assert_contains "team mode in system message" "TEAM mode" "$OUTPUT"

# ============================================================
# Test: Corrupted state (bad iteration) → abort
# ============================================================

cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<'STATE'
---
active: true
mode: solo
iteration: abc
max_iterations: 10
completion_promise: null
verify_command: null
verify_passed: false
team_name: ralpha-test
team_size: 1
persona: null
started_at: "2026-02-26T08:00:00Z"
---

test
STATE

TRANSCRIPT=$(create_transcript "hello")

set +e
OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "corrupted iteration → exit 0 (abort)" 0 $EXIT
assert_contains "corruption warning" "corrupted" "$OUTPUT"
assert_file_not_exists "corrupted state cleaned up" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

teardown_test_env
