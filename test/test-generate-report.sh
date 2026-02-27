#!/bin/bash

# Tests for scripts/generate-report.sh

setup_test_env

REPORT="$REPO_ROOT/scripts/generate-report.sh"

# Initialize a git repo so generate-report.sh can run git log
git init -q "$TEST_TMPDIR" 2>/dev/null
git -C "$TEST_TMPDIR" config user.email "test@test.com"
git -C "$TEST_TMPDIR" config user.name "Test"

# --- Helper: create state file ---
create_report_state() {
  cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<'STATE'
---
active: true
mode: team
iteration: 5
max_iterations: 10
completion_promise: "ALL TESTS PASSING"
verify_command: "npm test"
verify_passed: true
team_name: ralpha-123456
team_size: 3
persona: null
started_at: "2026-02-26T08:00:00Z"
---

Build a REST API with auth and tests
STATE
}

# ============================================================
# Test: No state file → exit 1
# ============================================================

set +e
OUTPUT=$(bash "$REPORT" "completed" 2>&1)
EXIT=$?
set -e
assert_exit "no state file → exit 1" 1 $EXIT

# ============================================================
# Test: Generates report with correct content
# ============================================================

create_report_state

set +e
OUTPUT=$(bash "$REPORT" "completed" 2>&1)
EXIT=$?
set -e
assert_exit "report generation → exit 0" 0 $EXIT
assert_file_exists "report file created" "$TEST_TMPDIR/ralpha-report.md"

REPORT_CONTENT=$(cat "$TEST_TMPDIR/ralpha-report.md")
assert_contains "report: title" "ralpha-team Report" "$REPORT_CONTENT"
assert_contains "report: mode" "team" "$REPORT_CONTENT"
assert_contains "report: iterations" "5 / 10" "$REPORT_CONTENT"
assert_contains "report: team name" "ralpha-123456" "$REPORT_CONTENT"
assert_contains "report: completion reason" "completed" "$REPORT_CONTENT"
assert_contains "report: verification" "PASSED" "$REPORT_CONTENT"
assert_contains "report: objective" "Build a REST API" "$REPORT_CONTENT"
assert_contains "report: promise" "ALL TESTS PASSING" "$REPORT_CONTENT"
assert_contains "report: verify command" "npm test" "$REPORT_CONTENT"

# ============================================================
# Test: Report with cancelled reason
# ============================================================

create_report_state
rm -f "$TEST_TMPDIR/ralpha-report.md"

set +e
OUTPUT=$(bash "$REPORT" "cancelled" 2>&1)
EXIT=$?
set -e
assert_exit "cancelled report → exit 0" 0 $EXIT

REPORT_CONTENT=$(cat "$TEST_TMPDIR/ralpha-report.md")
assert_contains "cancelled report: reason" "cancelled" "$REPORT_CONTENT"

teardown_test_env
