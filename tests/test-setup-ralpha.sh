#!/bin/bash

# Tests for scripts/setup-ralpha.sh (10 tests)

setup_test_env

SETUP="$REPO_ROOT/scripts/setup-ralpha.sh"

# --- Basic invocation: team mode ---

OUTPUT=$(bash "$SETUP" --mode team --speed fast "Build a REST API" --max-iterations 5 --completion-promise "DONE" --verify-command "npm test" --team-size 4 2>&1)
EXIT=$?
assert_exit "team mode exits 0 + state file created" 0 $EXIT

# Check state file content
source "$REPO_ROOT/scripts/parse-state.sh"
ralpha_load_frontmatter
assert_eq "state: mode is team" "team" "$(ralpha_parse_field "mode")"
assert_eq "state: completion_promise stored" "DONE" "$(ralpha_parse_field "completion_promise")"
assert_eq "state: speed stored" "fast" "$(ralpha_parse_field "speed")"
assert_eq "state: model mapped from speed" "haiku" "$(ralpha_parse_field "model")"

rm "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# --- Solo mode ---

OUTPUT=$(bash "$SETUP" --mode solo "Fix the bug" 2>&1)
EXIT=$?

ralpha_load_frontmatter
assert_eq "solo mode exits 0 + mode is solo" "solo" "$(ralpha_parse_field "mode")"

rm "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# --- Error cases ---

set +e
OUTPUT=$(bash "$SETUP" --mode solo 2>&1)
EXIT=$?
set -e
assert_exit "no prompt → exits 1" 1 $EXIT

set +e
OUTPUT=$(bash "$SETUP" --mode invalid "test" 2>&1)
EXIT=$?
set -e
assert_exit "invalid mode → exits 1" 1 $EXIT

# --- Valid persona ---

OUTPUT=$(bash "$SETUP" --mode solo --persona implementer "test prompt" 2>&1)
EXIT=$?

ralpha_load_frontmatter
assert_eq "valid persona stored in state" "implementer" "$(ralpha_parse_field "persona")"

# --- Active session protection ---

set +e
OUTPUT=$(bash "$SETUP" --mode solo "new task" 2>&1)
EXIT=$?
set -e
assert_exit "active session → exits 1" 1 $EXIT

teardown_test_env
