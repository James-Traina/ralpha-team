#!/bin/bash

# End-to-end: team mode lifecycle
# setup → iterate (stop hook with team context) → complete

setup_test_env

SETUP="$REPO_ROOT/scripts/setup-ralpha.sh"
STOP_HOOK="$REPO_ROOT/hooks/stop-hook.sh"

create_transcript() {
  local text="$1"
  local f="$TEST_TMPDIR/transcript.jsonl"
  printf '{"role":"assistant","message":{"content":[{"type":"text","text":"%s"}]}}\n' "$text" > "$f"
  echo "$f"
}

hook_input() {
  printf '{"transcript_path":"%s"}' "$1"
}

# ============================================================
# E2E: Team mode setup
# ============================================================

OUTPUT=$(bash "$SETUP" --mode team "Build REST API" --team-size 4 --max-iterations 5 --completion-promise "ALL TESTS PASSING" --verify-command "true" 2>&1)
EXIT=$?
assert_exit "e2e team: setup exits 0" 0 $EXIT
assert_contains "e2e team: mode shown" "Mode: team" "$OUTPUT"
assert_contains "e2e team: team size shown" "Team size: 4" "$OUTPUT"

source "$REPO_ROOT/scripts/parse-state.sh"
ralpha_load_frontmatter
assert_eq "e2e team: mode in state" "team" "$(ralpha_parse_field "mode")"
assert_eq "e2e team: team_size in state" "4" "$(ralpha_parse_field "team_size")"
TEAM_NAME=$(ralpha_parse_field "team_name")
assert_contains "e2e team: team_name has prefix" "ralpha-" "$TEAM_NAME"

# ============================================================
# E2E: Team mode iteration shows TEAM mode
# ============================================================

TRANSCRIPT=$(create_transcript "Decomposed tasks, spawning teammates...")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "e2e team: iter 1 exits 0" 0 $EXIT
assert_contains "e2e team: TEAM mode in message" "TEAM mode" "$OUTPUT"
assert_contains "e2e team: prompt re-injected" "Build REST API" "$OUTPUT"

# ============================================================
# E2E: Team mode completion with both gates
# ============================================================

TRANSCRIPT=$(create_transcript "All teammates done. Verified. <promise>ALL TESTS PASSING</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "e2e team: completion exits 0" 0 $EXIT
assert_contains "e2e team: both gates pass" "verification passed" "$OUTPUT"
assert_file_not_exists "e2e team: state cleaned" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# ============================================================
# E2E: Team mode with persona in agents/ dir accessible
# ============================================================

# Verify agent files exist (the lead should be able to read them)
assert_file_exists "e2e team: architect agent exists" "$REPO_ROOT/agents/architect.md"
assert_file_exists "e2e team: implementer agent exists" "$REPO_ROOT/agents/implementer.md"
assert_file_exists "e2e team: tester agent exists" "$REPO_ROOT/agents/tester.md"
assert_file_exists "e2e team: reviewer agent exists" "$REPO_ROOT/agents/reviewer.md"
assert_file_exists "e2e team: debugger agent exists" "$REPO_ROOT/agents/debugger.md"

# Verify each agent file has the expected frontmatter
for persona in architect implementer tester reviewer debugger; do
  CONTENT=$(cat "$REPO_ROOT/agents/$persona.md")
  assert_contains "e2e team: $persona has name" "name: $persona" "$CONTENT"
  assert_contains "e2e team: $persona has description" "description:" "$CONTENT"
done

# ============================================================
# E2E: Cancel flow
# ============================================================

OUTPUT=$(bash "$SETUP" --mode team "Some task" --max-iterations 10 2>&1)
assert_file_exists "e2e cancel: state exists" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# Simulate cancel: generate report then remove state
set +e
REPORT_OUTPUT=$(bash "$REPO_ROOT/scripts/generate-report.sh" "cancelled" 2>&1)
REPORT_EXIT=$?
set -e
assert_exit "e2e cancel: report exits 0" 0 $REPORT_EXIT
assert_file_exists "e2e cancel: report generated" "$TEST_TMPDIR/ralpha-report.md"

REPORT_CONTENT=$(cat "$TEST_TMPDIR/ralpha-report.md")
assert_contains "e2e cancel: report shows cancelled" "cancelled" "$REPORT_CONTENT"

rm "$TEST_TMPDIR/.claude/ralpha-team.local.md"
assert_file_not_exists "e2e cancel: state removed" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

teardown_test_env
