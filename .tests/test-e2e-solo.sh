#!/usr/bin/env bash
set -euo pipefail

# End-to-end: solo mode lifecycle (10 tests)

setup_test_env

SETUP="$REPO_ROOT/scripts/setup-ralpha.sh"
STOP_HOOK="$REPO_ROOT/hooks/stop-hook.sh"

# ============================================================
# E2E: Solo loop: setup → iterate → promise → exit
# ============================================================

# Step 1: Setup
OUTPUT=$(bash "$SETUP" --mode solo "Fix the auth bug" --max-iterations 10 --completion-promise "BUG FIXED" --verify-command "true" 2>&1)
EXIT=$?
assert_exit "setup exits 0 + state created" 0 $EXIT

# Step 2: Iteration 1 - no promise → loop continues
TRANSCRIPT=$(create_transcript "I'm investigating the auth module...")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "iter 1: blocks (no promise)" '"block"' "$OUTPUT"

source "$REPO_ROOT/scripts/parse-state.sh"
ralpha_load_frontmatter
assert_eq "iteration bumped to 2" "2" "$(ralpha_parse_field "iteration")"

# Step 3: Completion - promise detected, verify passes → complete
TRANSCRIPT=$(create_transcript "Fix applied and tested. <promise>BUG FIXED</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "completion: promise + verify pass → exit 0" 0 $EXIT
assert_file_not_exists "state cleaned up after completion" "$TEST_TMPDIR/.claude/ralpha-team.local.md"
assert_file_exists "report generated after completion" "$TEST_TMPDIR/ralpha-report.md"

# ============================================================
# E2E: Solo with promise-only (no verify command)
# ============================================================

OUTPUT=$(bash "$SETUP" --mode solo "Quick fix" --completion-promise "DONE" 2>&1)
TRANSCRIPT=$(create_transcript "<promise>DONE</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "promise-only (no verify): confirmed" "Completion confirmed" "$OUTPUT"

# ============================================================
# E2E: Solo max iterations reached
# ============================================================

OUTPUT=$(bash "$SETUP" --mode solo "long task" --max-iterations 1 --completion-promise "DONE" 2>&1)

TRANSCRIPT=$(create_transcript "working...")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "max iterations reached → stops" "Max iterations" "$OUTPUT"

# ============================================================
# E2E: Solo with failing verification → loop continues
# ============================================================

OUTPUT=$(bash "$SETUP" --mode solo "fix tests" --completion-promise "TESTS PASS" --verify-command "false" 2>&1)

TRANSCRIPT=$(create_transcript "<promise>TESTS PASS</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "verify fail: blocks with VERIFICATION FAILED" "VERIFICATION FAILED" "$OUTPUT"

# Next iteration with passing verify
TMPF="${TEST_TMPDIR}/.claude/ralpha-team.local.md.tmp"
sed 's/verify_command: "false"/verify_command: "true"/' "$TEST_TMPDIR/.claude/ralpha-team.local.md" > "$TMPF"
mv "$TMPF" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

TRANSCRIPT=$(create_transcript "<promise>TESTS PASS</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "verify retry: passes after fix" "verification passed" "$OUTPUT"

teardown_test_env
