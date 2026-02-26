#!/bin/bash

# Edge case tests

setup_test_env

SETUP="$REPO_ROOT/scripts/setup-ralpha.sh"
STOP_HOOK="$REPO_ROOT/hooks/stop-hook.sh"

create_transcript() {
  local text="$1"
  local f="$TEST_TMPDIR/transcript.jsonl"
  # Use jq -c for compact JSONL (matches stop-hook.sh grep pattern)
  jq -cn --arg t "$text" '{"role":"assistant","message":{"content":[{"type":"text","text":$t}]}}' > "$f"
  echo "$f"
}

hook_input() {
  printf '{"transcript_path":"%s"}' "$1"
}

create_state() {
  local mode="${1:-solo}" iteration="${2:-1}" max="${3:-0}" promise="${4:-null}" verify="${5:-null}"
  local promise_yaml verify_yaml
  if [[ "$promise" = "null" ]]; then promise_yaml="null"; else promise_yaml="\"$promise\""; fi
  if [[ "$verify" = "null" ]]; then verify_yaml="null"; else verify_yaml="\"$verify\""; fi
  cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<EOF
---
active: true
mode: $mode
iteration: $iteration
max_iterations: $max
completion_promise: $promise_yaml
verify_command: $verify_yaml
verify_passed: false
team_name: ralpha-test
team_size: 1
persona: null
started_at: "2026-02-26T08:00:00Z"
---

Test prompt
EOF
}

# ============================================================
# Edge: Promise with special characters
# ============================================================

create_state "solo" 1 0 'ALL "TESTS" PASSING' "null"
TRANSCRIPT=$(create_transcript '<promise>ALL "TESTS" PASSING</promise>')
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "edge: promise with quotes exits 0" 0 $EXIT
# The perl regex should handle quotes in the promise text
assert_contains "edge: quoted promise detected" "Promise detected" "$OUTPUT"

# ============================================================
# Edge: Prompt with special characters
# ============================================================

OUTPUT=$(bash "$SETUP" --mode solo 'Fix the "auth" module & tests' --completion-promise "DONE" 2>&1)
EXIT=$?
assert_exit "edge: special chars in prompt exits 0" 0 $EXIT

source "$REPO_ROOT/scripts/parse-state.sh"
PROMPT=$(ralpha_parse_prompt)
assert_contains "edge: prompt preserves ampersand" "&" "$PROMPT"

rm -f "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# ============================================================
# Edge: Missing transcript file
# ============================================================

create_state "solo" 1 0 "DONE" "null"
set +e; OUTPUT=$(echo '{"transcript_path":"/nonexistent/path.jsonl"}' | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "edge: missing transcript exits 0" 0 $EXIT
assert_contains "edge: missing transcript warning" "Transcript file not found" "$OUTPUT"
assert_file_not_exists "edge: missing transcript cleans state" "$TEST_TMPDIR/.claude/ralpha-team.local.md"

# ============================================================
# Edge: Empty transcript (no assistant messages)
# ============================================================

create_state "solo" 1 0 "DONE" "null"
EMPTY_TRANSCRIPT="$TEST_TMPDIR/empty-transcript.jsonl"
echo '{"role":"user","message":{"content":[{"type":"text","text":"hello"}]}}' > "$EMPTY_TRANSCRIPT"
set +e; OUTPUT=$(hook_input "$EMPTY_TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "edge: no assistant msgs exits 0" 0 $EXIT
assert_contains "edge: no assistant msgs warning" "No assistant messages" "$OUTPUT"

# ============================================================
# Edge: Corrupted max_iterations
# ============================================================

cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<'STATE'
---
active: true
mode: solo
iteration: 1
max_iterations: xyz
completion_promise: null
verify_command: null
verify_passed: false
team_name: ralpha-test
team_size: 1
persona: null
started_at: "2026-02-26T08:00:00Z"
---

test
STATE

TRANSCRIPT=$(create_transcript "hello")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "edge: corrupted max_iterations exits 0" 0 $EXIT
assert_contains "edge: corrupted max_iterations warning" "corrupted" "$OUTPUT"

# ============================================================
# Edge: Multiple promise tags (first one wins)
# ============================================================

create_state "solo" 1 0 "FIRST" "null"
TRANSCRIPT=$(create_transcript "<promise>FIRST</promise> and <promise>SECOND</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "edge: first promise wins" "Promise detected" "$OUTPUT"

# ============================================================
# Edge: Promise tag without matching text
# ============================================================

create_state "solo" 1 0 "CORRECT" "null"
TRANSCRIPT=$(create_transcript "<promise>WRONG</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "edge: wrong promise text → loop" '"block"' "$OUTPUT"

# ============================================================
# Edge: Iteration at max-1 → one more allowed, then stops
# ============================================================

create_state "solo" 4 5 "null" "null"
TRANSCRIPT=$(create_transcript "iteration 4 work")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
# iteration=4, max=5, so 4 < 5 → continue
assert_contains "edge: iter 4/5 continues" '"block"' "$OUTPUT"

# Now iteration is 5, max is 5 → 5 >= 5 → stop
TRANSCRIPT=$(create_transcript "iteration 5 work")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "edge: iter 5/5 stops" "Max iterations" "$OUTPUT"

# ============================================================
# Edge: Help flag
# ============================================================

set +e
OUTPUT=$(bash "$SETUP" --help 2>&1)
EXIT=$?
set -e
assert_exit "edge: --help exits 0" 0 $EXIT
assert_contains "edge: help shows usage" "USAGE" "$OUTPUT"

# ============================================================
# Edge: Mixed casing in promise
# ============================================================

create_state "solo" 1 0 "All Tests Passing" "null"
TRANSCRIPT=$(create_transcript "<promise>ALL TESTS PASSING</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_contains "edge: mixed case promise matches" "Promise detected" "$OUTPUT"

# ============================================================
# Edge: Prompt with frontmatter-like lines survives bump_iteration
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
assert_exit "edge: frontmatter-like prompt exits 0" 0 $EXIT

# Verify the frontmatter was updated correctly
source "$REPO_ROOT/scripts/parse-state.sh"
ralpha_load_frontmatter
assert_eq "edge: frontmatter iteration bumped" "2" "$(ralpha_parse_field "iteration")"

# Verify the prompt body was NOT corrupted
PROMPT=$(ralpha_parse_prompt)
assert_contains "edge: prompt iteration: line preserved" "iteration: counter resets to zero" "$PROMPT"
assert_contains "edge: prompt verify_passed: line preserved" "verify_passed: should be checked earlier" "$PROMPT"

# ============================================================
# Edge: verify_passed update survives frontmatter-like prompt body
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
assert_exit "edge: verify_passed update exits 0" 0 $EXIT
assert_contains "edge: verify_passed completes" "verification passed" "$OUTPUT"

# ============================================================
# Edge: Prompt with --- lines survives re-injection
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
assert_exit "edge: dashes prompt exits 0" 0 $EXIT
# The re-injected prompt (in "reason" field) must contain the --- lines
assert_contains "edge: dashes prompt has separator" "---" "$OUTPUT"
assert_contains "edge: dashes prompt has auth line" "Add auth." "$OUTPUT"
assert_contains "edge: dashes prompt has tests line" "Write tests." "$OUTPUT"

# ============================================================
# Edge: Pretty-printed JSON transcript (spaces around colons)
# ============================================================

create_state "solo" 1 0 "DONE" "null"
PRETTY_TRANSCRIPT="$TEST_TMPDIR/pretty-transcript.jsonl"
printf '{"role" : "assistant", "message" : {"content" : [{"type" : "text", "text" : "<promise>DONE</promise>"}]}}\n' > "$PRETTY_TRANSCRIPT"
set +e; OUTPUT=$(hook_input "$PRETTY_TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "edge: pretty JSON exits 0" 0 $EXIT
assert_contains "edge: pretty JSON promise detected" "Promise detected" "$OUTPUT"

# ============================================================
# Edge: JSON with extra whitespace variations
# ============================================================

create_state "solo" 1 0 "null" "null"
SPACED_TRANSCRIPT="$TEST_TMPDIR/spaced-transcript.jsonl"
printf '{ "role":"assistant" , "message":{"content":[{"type":"text","text":"just working"}]}}\n' > "$SPACED_TRANSCRIPT"
set +e; OUTPUT=$(hook_input "$SPACED_TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); EXIT=$?; set -e
assert_exit "edge: mixed spacing exits 0" 0 $EXIT
assert_contains "edge: mixed spacing continues loop" '"block"' "$OUTPUT"

teardown_test_env
