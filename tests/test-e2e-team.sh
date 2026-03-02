#!/bin/bash

# End-to-end: team mode lifecycle (10 tests)

setup_test_env

SETUP="$REPO_ROOT/scripts/setup-ralpha.sh"
STOP_HOOK="$REPO_ROOT/hooks/stop-hook.sh"

# ============================================================
# E2E: Team mode setup
# ============================================================

OUTPUT=$(bash "$SETUP" --mode team "Build REST API" --team-size 4 --max-iterations 5 --completion-promise "ALL TESTS PASSING" --verify-command "true" 2>&1)
EXIT=$?
assert_exit "setup exits 0" 0 $EXIT
assert_contains "mode shown in output" "Mode: team" "$OUTPUT"

source "$REPO_ROOT/scripts/parse-state.sh"
ralpha_load_frontmatter
assert_eq "mode in state is team" "team" "$(ralpha_parse_field "mode")"
TEAM_NAME=$(ralpha_parse_field "team_name")
assert_contains "team_name has prefix ralpha-" "ralpha-" "$TEAM_NAME"

# ============================================================
# E2E: Team mode iteration
# ============================================================

TRANSCRIPT=$(create_transcript "Decomposed tasks, spawning teammates...")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "iter 1: TEAM mode in message" "TEAM mode" "$OUTPUT"
assert_contains "prompt re-injected in iteration" "Build REST API" "$OUTPUT"

# ============================================================
# E2E: Team mode completion with both gates
# ============================================================

TRANSCRIPT=$(create_transcript "All teammates done. Verified. <promise>ALL TESTS PASSING</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "completion: both gates pass" "verification passed" "$OUTPUT"
assert_file_not_exists "state cleaned after completion" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# ============================================================
# E2E: Agent files exist (representative check)
# ============================================================

assert_file_exists "agent files exist (architect)" "$REPO_ROOT/agents/architect.md"

# ============================================================
# E2E: Cancel flow
# ============================================================

OUTPUT=$(bash "$SETUP" --mode team "Some task" --max-iterations 10 2>&1)

# Simulate cancel: generate report then remove state
set +e
REPORT_OUTPUT=$(bash "$REPO_ROOT/scripts/generate-report.sh" "cancelled" 2>&1)
set -e
assert_file_exists "cancel: report generated" "$TEST_TMPDIR/ralpha-report.md"

teardown_test_env
