#!/bin/bash

# Edge case tests (10 tests)

setup_test_env

SETUP="$REPO_ROOT/scripts/setup-ralpha.sh"
STOP_HOOK="$REPO_ROOT/hooks/stop-hook.sh"

# ============================================================
# Edge: Promise with quotes — YAML roundtrip protection
# ============================================================

create_state "solo" 1 0 'ALL "TESTS" PASSING' "null"
TRANSCRIPT=$(create_transcript '<promise>ALL "TESTS" PASSING</promise>')
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "promise with quotes: detected" "Promise detected" "$OUTPUT"

# ============================================================
# Edge: Wrong promise text → loop continues
# ============================================================

create_state "solo" 1 0 "CORRECT" "null"
TRANSCRIPT=$(create_transcript "<promise>WRONG</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "wrong promise text → loop continues" '"block"' "$OUTPUT"

# ============================================================
# Edge: Mixed case promise matches — case-insensitivity
# ============================================================

create_state "solo" 1 0 "All Tests Passing" "null"
TRANSCRIPT=$(create_transcript "<promise>ALL TESTS PASSING</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "mixed case promise matches" "Promise detected" "$OUTPUT"

# ============================================================
# Edge: Frontmatter-like prompt survives bump_iteration
# ============================================================

rm -f "$TEST_TMPDIR/.claude/ralpha-team.local.md"
cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<'STATE'
---
active: true
mode: solo
iteration: 1
max_iterations: 0
completion_promise: null
verify_command: null
verify_passed: false
team_name: ralpha-test
team_size: 1
persona: null
started_at: "2026-02-26T08:00:00Z"
---

Fix the bug where:
iteration: counter resets to zero
verify_passed: should be checked earlier
STATE

TRANSCRIPT=$(create_transcript "working on the iteration fix")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e

source "$REPO_ROOT/scripts/parse-state.sh"
ralpha_load_frontmatter
assert_eq "frontmatter-like prompt: iteration bumped correctly" "2" "$(ralpha_parse_field "iteration")"

PROMPT=$(ralpha_parse_prompt)
assert_contains "frontmatter-like prompt: iteration: line preserved" "iteration: counter resets to zero" "$PROMPT"
assert_contains "frontmatter-like prompt: verify_passed: line preserved" "verify_passed: should be checked earlier" "$PROMPT"

# ============================================================
# Edge: verify_passed update completes despite frontmatter-like prompt
# ============================================================

rm -f "$TEST_TMPDIR/.claude/ralpha-team.local.md"
cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<'STATE'
---
active: true
mode: solo
iteration: 1
max_iterations: 0
completion_promise: "FIXED"
verify_command: "true"
verify_passed: false
team_name: ralpha-test
team_size: 1
persona: null
started_at: "2026-02-26T08:00:00Z"
---

Fix the bug where:
verify_passed: should be checked earlier
iteration: counter resets
STATE

TRANSCRIPT=$(create_transcript '<promise>FIXED</promise>')
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "verify_passed update completes" "verification passed" "$OUTPUT"

# ============================================================
# Edge: Dashes in prompt survive re-injection
# ============================================================

rm -f "$TEST_TMPDIR/.claude/ralpha-team.local.md"
cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<'STATE'
---
active: true
mode: solo
iteration: 1
max_iterations: 0
completion_promise: null
verify_command: null
verify_passed: false
team_name: ralpha-test
team_size: 1
persona: null
started_at: "2026-02-26T08:00:00Z"
---

Build API.
---
Add auth.
---
Write tests.
STATE

TRANSCRIPT=$(create_transcript "working on it")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "dashes in prompt: separator + content survive" "Add auth." "$OUTPUT"

# ============================================================
# Edge: Whitespace in promise detected
# ============================================================

create_state "solo" 2 0 "ALL DONE" "null"
TRANSCRIPT=$(create_transcript "<promise>  ALL DONE  </promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "whitespace in promise: detected" "Promise detected" "$OUTPUT"

# ============================================================
# Edge: Newline in promise survives YAML roundtrip (B1 fix)
# ============================================================

rm -f "$TEST_TMPDIR/.claude/ralpha-team.local.md"
bash "$SETUP" --mode solo "test" --completion-promise $'line1\nline2' --verify-command "true" --max-iterations 5 >/dev/null 2>&1
source "$REPO_ROOT/scripts/parse-state.sh"
ralpha_load_frontmatter
PROMISE=$(ralpha_parse_field "completion_promise")
assert_eq "newline in promise survives YAML roundtrip" $'line1\nline2' "$PROMISE"

teardown_test_env
