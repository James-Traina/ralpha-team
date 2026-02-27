#!/bin/bash

# End-to-end: solo mode lifecycle
# setup → iterate (stop hook) → promise → complete

setup_test_env

SETUP="$REPO_ROOT/scripts/setup-ralpha.sh"
STOP_HOOK="$REPO_ROOT/hooks/stop-hook.sh"

# ============================================================
# E2E: Solo loop: setup → 3 iterations → promise → exit
# ============================================================

# Step 1: Setup
OUTPUT=$(bash "$SETUP" --mode solo "Fix the auth bug" --max-iterations 10 --completion-promise "BUG FIXED" --verify-command "true" 2>&1)
EXIT=$?
assert_exit "e2e solo: setup exits 0" 0 $EXIT
assert_file_exists "e2e solo: state created" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# Step 2: Iteration 1 - no promise → loop continues
TRANSCRIPT=$(create_transcript "I'm investigating the auth module...")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "e2e solo: iter 1 exits 0" 0 $EXIT
assert_contains "e2e solo: iter 1 blocks" '"block"' "$OUTPUT"
assert_contains "e2e solo: iter 1 shows iteration 2" "iteration 2" "$OUTPUT"

source "$REPO_ROOT/scripts/parse-state.sh"
ralpha_load_frontmatter
assert_eq "e2e solo: iteration bumped to 2" "2" "$(ralpha_parse_field "iteration")"

# Step 3: Iteration 2 - still no promise
TRANSCRIPT=$(create_transcript "Found the race condition, applying fix...")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "e2e solo: iter 2 blocks" '"block"' "$OUTPUT"
assert_contains "e2e solo: iter 2 shows iteration 3" "iteration 3" "$OUTPUT"

# Step 4: Iteration 3 - promise detected, verify passes → complete
TRANSCRIPT=$(create_transcript "Fix applied and tested. <promise>BUG FIXED</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "e2e solo: completion exits 0" 0 $EXIT
assert_contains "e2e solo: promise + verify pass" "verification passed" "$OUTPUT"
assert_file_not_exists "e2e solo: state cleaned up" "$TEST_TMPDIR/.claude/ralpha-team.local.md"
assert_file_exists "e2e solo: report generated" "$TEST_TMPDIR/ralpha-report.md"

# ============================================================
# E2E: Solo with promise-only (no verify command)
# ============================================================

OUTPUT=$(bash "$SETUP" --mode solo "Quick fix" --completion-promise "DONE" 2>&1)
TRANSCRIPT=$(create_transcript "<promise>DONE</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "e2e solo promise-only: exits 0" 0 $EXIT
assert_contains "e2e solo promise-only: confirmed" "Completion confirmed" "$OUTPUT"
assert_file_not_exists "e2e solo promise-only: state cleaned" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# ============================================================
# E2E: Solo max iterations reached
# ============================================================

OUTPUT=$(bash "$SETUP" --mode solo "long task" --max-iterations 2 --completion-promise "DONE" 2>&1)

# Iteration 1 - no promise
TRANSCRIPT=$(create_transcript "working...")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "e2e max iter: iter 1 blocks" '"block"' "$OUTPUT"

# Iteration 2 = max → session ends
TRANSCRIPT=$(create_transcript "still working...")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "e2e max iter: exits 0" 0 $EXIT
assert_contains "e2e max iter: max reached message" "Max iterations" "$OUTPUT"
assert_file_not_exists "e2e max iter: state cleaned" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# ============================================================
# E2E: Solo with failing verification → loop continues
# ============================================================

OUTPUT=$(bash "$SETUP" --mode solo "fix tests" --completion-promise "TESTS PASS" --verify-command "false" 2>&1)

TRANSCRIPT=$(create_transcript "<promise>TESTS PASS</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "e2e verify fail: blocks" '"block"' "$OUTPUT"
assert_contains "e2e verify fail: feedback" "VERIFICATION FAILED" "$OUTPUT"
assert_file_exists "e2e verify fail: state still exists" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# Next iteration with passing verify
# Update verify_command in state to "true"
TMPF="${TEST_TMPDIR}/.claude/ralpha-team.local.md.tmp"
sed 's/verify_command: "false"/verify_command: "true"/' "$TEST_TMPDIR/.claude/ralpha-team.local.md" > "$TMPF"
mv "$TMPF" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

TRANSCRIPT=$(create_transcript "<promise>TESTS PASS</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "e2e verify retry: passes" "verification passed" "$OUTPUT"
assert_file_not_exists "e2e verify retry: state cleaned" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# ============================================================
# E2E: No gates at all → infinite loop (until max)
# ============================================================

OUTPUT=$(bash "$SETUP" --mode solo "open loop" --max-iterations 3 2>&1)

for i in 1 2; do
  TRANSCRIPT=$(create_transcript "iteration $i work")
  set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
  assert_contains "e2e no gates: iter $i blocks" '"block"' "$OUTPUT"
done

TRANSCRIPT=$(create_transcript "iteration 3 work")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "e2e no gates: max reached" "Max iterations" "$OUTPUT"

teardown_test_env
