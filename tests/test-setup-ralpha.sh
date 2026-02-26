#!/bin/bash

# Tests for scripts/setup-ralpha.sh

setup_test_env

SETUP="$REPO_ROOT/scripts/setup-ralpha.sh"

# --- Basic invocation: team mode ---

OUTPUT=$(bash "$SETUP" --mode team "Build a REST API" --max-iterations 5 --completion-promise "DONE" --verify-command "npm test" --team-size 4 2>&1)
EXIT=$?
assert_exit "team mode exits 0" 0 $EXIT
assert_file_exists "state file created" "$TEST_TMPDIR/.claude/ralpha-team.local.md"
assert_contains "output says activated" "Ralpha-team activated!" "$OUTPUT"
assert_contains "output shows mode" "Mode: team" "$OUTPUT"
assert_contains "output shows prompt" "Build a REST API" "$OUTPUT"
assert_contains "output shows completion gate" "COMPLETION GATE" "$OUTPUT"

# Check state file content
source "$REPO_ROOT/scripts/parse-state.sh"
ralpha_load_frontmatter
assert_eq "state: mode" "team" "$(ralpha_parse_field "mode")"
assert_eq "state: iteration" "1" "$(ralpha_parse_field "iteration")"
assert_eq "state: max_iterations" "5" "$(ralpha_parse_field "max_iterations")"
assert_eq "state: completion_promise" "DONE" "$(ralpha_parse_field "completion_promise")"
assert_eq "state: verify_command" "npm test" "$(ralpha_parse_field "verify_command")"
assert_eq "state: team_size" "4" "$(ralpha_parse_field "team_size")"

PROMPT=$(ralpha_parse_prompt)
assert_eq "state: prompt" "Build a REST API" "$PROMPT"

rm "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# --- Solo mode ---

OUTPUT=$(bash "$SETUP" --mode solo "Fix the bug" 2>&1)
EXIT=$?
assert_exit "solo mode exits 0" 0 $EXIT
assert_file_exists "solo state file created" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

ralpha_load_frontmatter
assert_eq "solo: mode" "solo" "$(ralpha_parse_field "mode")"

rm "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# --- No prompt error ---

set +e
OUTPUT=$(bash "$SETUP" --mode solo 2>&1)
EXIT=$?
set -e
assert_exit "no prompt exits 1" 1 $EXIT
assert_contains "no prompt error message" "No prompt provided" "$OUTPUT"

# --- Invalid mode error ---

set +e
OUTPUT=$(bash "$SETUP" --mode invalid "test" 2>&1)
EXIT=$?
set -e
assert_exit "invalid mode exits 1" 1 $EXIT
assert_contains "invalid mode error" "must be 'solo' or 'team'" "$OUTPUT"

# --- Invalid max-iterations error ---

set +e
OUTPUT=$(bash "$SETUP" --max-iterations abc "test" 2>&1)
EXIT=$?
set -e
assert_exit "invalid max-iterations exits 1" 1 $EXIT

# --- Valid persona ---

OUTPUT=$(bash "$SETUP" --mode solo --persona implementer "test prompt" 2>&1)
EXIT=$?
assert_exit "valid persona exits 0" 0 $EXIT
assert_contains "persona in output" "Persona: implementer" "$OUTPUT"

ralpha_load_frontmatter
assert_eq "persona stored" "implementer" "$(ralpha_parse_field "persona")"

rm "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# --- Invalid persona error ---

set +e
OUTPUT=$(bash "$SETUP" --mode solo --persona nonexistent "test" 2>&1)
EXIT=$?
set -e
assert_exit "invalid persona exits 1" 1 $EXIT
assert_contains "invalid persona error" "Unknown persona" "$OUTPUT"
assert_contains "lists available personas" "implementer" "$OUTPUT"

# --- Defaults: no promise, no verify ---

OUTPUT=$(bash "$SETUP" --mode team "simple task" 2>&1)
EXIT=$?
assert_exit "defaults exit 0" 0 $EXIT
assert_not_contains "no completion gate without promise" "COMPLETION GATE" "$OUTPUT"

ralpha_load_frontmatter
assert_eq "default: completion_promise is null" "null" "$(ralpha_parse_field "completion_promise")"
assert_eq "default: verify_command is null" "null" "$(ralpha_parse_field "verify_command")"
assert_eq "default: max_iterations is 0" "0" "$(ralpha_parse_field "max_iterations")"

# --- Agent-teams env var warning ---

rm -f "$TEST_TMPDIR/.claude/ralpha-team.local.md"
OUTPUT=$(CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="" bash "$SETUP" --mode team "test task" 2>&1)
EXIT=$?
assert_exit "team without env var exits 0" 0 $EXIT
assert_contains "team without env var warns" "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$OUTPUT"

rm -f "$TEST_TMPDIR/.claude/ralpha-team.local.md"
OUTPUT=$(CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="" bash "$SETUP" --mode solo "test task" 2>&1)
EXIT=$?
assert_exit "solo without env var exits 0" 0 $EXIT
assert_not_contains "solo without env var no warning" "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$OUTPUT"

rm -f "$TEST_TMPDIR/.claude/ralpha-team.local.md"
OUTPUT=$(CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1" bash "$SETUP" --mode team "test task" 2>&1)
EXIT=$?
assert_exit "team with env var exits 0" 0 $EXIT
assert_not_contains "team with env var no warning" "Warning:" "$OUTPUT"

# --- Active session protection ---

# State file exists from defaults test above
set +e
OUTPUT=$(bash "$SETUP" --mode solo "new task" 2>&1)
EXIT=$?
set -e
assert_exit "active session blocks" 1 $EXIT
assert_contains "active session error" "already active" "$OUTPUT"
assert_contains "active session cancel hint" "cancel" "$OUTPUT"

# Clean up and verify fresh start works
rm -f "$TEST_TMPDIR/.claude/ralpha-team.local.md"
OUTPUT=$(bash "$SETUP" --mode solo "new task" 2>&1)
EXIT=$?
assert_exit "fresh start after cleanup" 0 $EXIT
assert_contains "fresh start activated" "activated" "$OUTPUT"

teardown_test_env
