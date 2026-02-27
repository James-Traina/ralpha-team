#!/bin/bash

# Tests for scripts/verify-completion.sh

setup_test_env

VERIFY="$REPO_ROOT/scripts/verify-completion.sh"

# --- Helper: create state file ---
create_state_with_verify() {
  local cmd="$1"
  local cmd_yaml
  if [[ "$cmd" = "null" ]]; then cmd_yaml="null"; else cmd_yaml="\"$cmd\""; fi
  cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<EOF
---
active: true
mode: solo
iteration: 1
max_iterations: 0
completion_promise: null
verify_command: $cmd_yaml
verify_passed: false
team_name: ralpha-test
team_size: 1
persona: null
started_at: "2026-02-26T08:00:00Z"
---

test
EOF
}

# ============================================================
# Test: No state file → exit 1
# ============================================================

set +e
OUTPUT=$(bash "$VERIFY" 2>&1)
EXIT=$?
set -e
assert_exit "no state file → exit 1" 1 $EXIT
assert_contains "no state message" "No active ralpha session" "$OUTPUT"

# ============================================================
# Test: No verify command → exit 0 (pass)
# ============================================================

create_state_with_verify "null"

set +e
OUTPUT=$(bash "$VERIFY" 2>&1)
EXIT=$?
set -e
assert_exit "no verify command → exit 0" 0 $EXIT
assert_contains "no verify message" "No verification command" "$OUTPUT"

# ============================================================
# Test: Passing verify command → exit 0
# ============================================================

create_state_with_verify "true"

set +e
OUTPUT=$(bash "$VERIFY" 2>&1)
EXIT=$?
set -e
assert_exit "passing verify → exit 0" 0 $EXIT
assert_contains "verify passed" "PASSED" "$OUTPUT"

# ============================================================
# Test: Failing verify command → exit non-zero
# ============================================================

create_state_with_verify "false"

set +e
OUTPUT=$(bash "$VERIFY" 2>&1)
EXIT=$?
set -e
assert_exit "failing verify → exit 1" 1 $EXIT
assert_contains "verify failed" "FAILED" "$OUTPUT"

# ============================================================
# Test: Verify command with output
# ============================================================

create_state_with_verify "echo 'test output' && true"

set +e
OUTPUT=$(bash "$VERIFY" 2>&1)
EXIT=$?
set -e
assert_exit "verify with output → exit 0" 0 $EXIT
assert_contains "captures command output" "test output" "$OUTPUT"

teardown_test_env
