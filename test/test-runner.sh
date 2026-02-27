#!/bin/bash

# Ralpha-Team test runner
# Usage: ./test/test-runner.sh [test-file...]
# Runs all test-*.sh files in the test/ directory, or specific files if given.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# File-based counters (so subshells can update them)
RESULTS_DIR=$(mktemp -d)
echo 0 > "$RESULTS_DIR/pass"
echo 0 > "$RESULTS_DIR/fail"
: > "$RESULTS_DIR/errors"

export TESTS_DIR REPO_ROOT RESULTS_DIR

# --- Test helpers (sourced by test files) ---

_bump() {
  local file="$1"
  local val
  val=$(cat "$file")
  echo $((val + 1)) > "$file"
}

setup_test_env() {
  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  mkdir -p "$TEST_TMPDIR/.claude"
  export CLAUDE_PLUGIN_ROOT="$REPO_ROOT"
  cd "$TEST_TMPDIR"
}

teardown_test_env() {
  cd "$REPO_ROOT"
  rm -rf "$TEST_TMPDIR"
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" = "$actual" ]]; then
    _bump "$RESULTS_DIR/pass"
    printf "  \033[32m✓\033[0m %s\n" "$label"
  else
    _bump "$RESULTS_DIR/fail"
    echo "$label: expected '$expected', got '$actual'" >> "$RESULTS_DIR/errors"
    printf "  \033[31m✗\033[0m %s\n" "$label"
    printf "    expected: %s\n" "$expected"
    printf "    actual:   %s\n" "$actual"
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    _bump "$RESULTS_DIR/pass"
    printf "  \033[32m✓\033[0m %s\n" "$label"
  else
    _bump "$RESULTS_DIR/fail"
    echo "$label: '$needle' not found in output" >> "$RESULTS_DIR/errors"
    printf "  \033[31m✗\033[0m %s\n" "$label"
    printf "    needle:   %s\n" "$needle"
    printf "    haystack: %s\n" "$(echo "$haystack" | head -5)"
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if ! echo "$haystack" | grep -qF -- "$needle"; then
    _bump "$RESULTS_DIR/pass"
    printf "  \033[32m✓\033[0m %s\n" "$label"
  else
    _bump "$RESULTS_DIR/fail"
    echo "$label: '$needle' should not be in output" >> "$RESULTS_DIR/errors"
    printf "  \033[31m✗\033[0m %s\n" "$label"
  fi
}

assert_exit() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" = "$actual" ]]; then
    _bump "$RESULTS_DIR/pass"
    printf "  \033[32m✓\033[0m %s (exit %s)\n" "$label" "$expected"
  else
    _bump "$RESULTS_DIR/fail"
    echo "$label: expected exit $expected, got $actual" >> "$RESULTS_DIR/errors"
    printf "  \033[31m✗\033[0m %s (expected exit %s, got %s)\n" "$label" "$expected" "$actual"
  fi
}

assert_file_exists() {
  local label="$1" path="$2"
  if [[ -f "$path" ]]; then
    _bump "$RESULTS_DIR/pass"
    printf "  \033[32m✓\033[0m %s\n" "$label"
  else
    _bump "$RESULTS_DIR/fail"
    echo "$label: file not found: $path" >> "$RESULTS_DIR/errors"
    printf "  \033[31m✗\033[0m %s (file not found: %s)\n" "$label" "$path"
  fi
}

assert_file_not_exists() {
  local label="$1" path="$2"
  if [[ ! -f "$path" ]]; then
    _bump "$RESULTS_DIR/pass"
    printf "  \033[32m✓\033[0m %s\n" "$label"
  else
    _bump "$RESULTS_DIR/fail"
    echo "$label: file should not exist: $path" >> "$RESULTS_DIR/errors"
    printf "  \033[31m✗\033[0m %s (file should not exist: %s)\n" "$label" "$path"
  fi
}

export -f _bump assert_eq assert_contains assert_not_contains assert_exit assert_file_exists assert_file_not_exists setup_test_env teardown_test_env

# --- Run tests ---

if [[ $# -gt 0 ]]; then
  TEST_FILES=("$@")
else
  TEST_FILES=()
  for f in "$TESTS_DIR"/test-*.sh; do
    [[ "$(basename "$f")" = "test-runner.sh" ]] && continue
    TEST_FILES+=("$f")
  done
fi

echo ""
echo "Ralpha-Team Test Suite"
echo "======================"

for test_file in "${TEST_FILES[@]}"; do
  if [[ ! -f "$test_file" ]]; then
    echo "Warning: test file not found: $test_file" >&2
    continue
  fi
  test_name=$(basename "$test_file" .sh)
  printf "\n\033[1m%s\033[0m\n" "$test_name"
  (source "$test_file")
done

# --- Summary ---

PASS=$(cat "$RESULTS_DIR/pass")
FAIL=$(cat "$RESULTS_DIR/fail")
TOTAL=$((PASS + FAIL))

echo ""
echo "======================"
if [[ $FAIL -eq 0 ]]; then
  printf "\033[32mAll %d tests passed.\033[0m\n" "$TOTAL"
else
  printf "\033[31m%d/%d tests failed:\033[0m\n" "$FAIL" "$TOTAL"
  while IFS= read -r err; do
    printf "  - %s\n" "$err"
  done < "$RESULTS_DIR/errors"
fi
echo ""

rm -rf "$RESULTS_DIR"
exit $FAIL
