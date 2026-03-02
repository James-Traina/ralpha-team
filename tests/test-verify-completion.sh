#!/bin/bash

# Tests for scripts/verify-completion.sh

setup_test_env

VERIFY="$REPO_ROOT/scripts/verify-completion.sh"

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

create_state "solo" 1 0 "null" "null"

set +e
OUTPUT=$(bash "$VERIFY" 2>&1)
EXIT=$?
set -e
assert_exit "no verify command → exit 0" 0 $EXIT
assert_contains "no verify message" "No verification command" "$OUTPUT"

# ============================================================
# Test: Passing verify command → exit 0
# ============================================================

create_state "solo" 1 0 "null" "true"

set +e
OUTPUT=$(bash "$VERIFY" 2>&1)
EXIT=$?
set -e
assert_exit "passing verify → exit 0" 0 $EXIT
assert_contains "verify passed" "PASSED" "$OUTPUT"

# ============================================================
# Test: Failing verify command → exit non-zero
# ============================================================

create_state "solo" 1 0 "null" "false"

set +e
OUTPUT=$(bash "$VERIFY" 2>&1)
EXIT=$?
set -e
assert_exit "failing verify → exit 1" 1 $EXIT
assert_contains "verify failed" "FAILED" "$OUTPUT"

# ============================================================
# Test: Verify command with output
# ============================================================

create_state "solo" 1 0 "null" "echo 'test output' && true"

set +e
OUTPUT=$(bash "$VERIFY" 2>&1)
EXIT=$?
set -e
assert_exit "verify with output → exit 0" 0 $EXIT
assert_contains "captures command output" "test output" "$OUTPUT"

teardown_test_env
