#!/bin/bash

# Tests for scripts/parse-state.sh (10 tests)

setup_test_env

# --- Helper: fixed state for parse testing ---
create_parse_test_state() {
  cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<'STATE'
---
active: true
mode: team
iteration: 3
max_iterations: 10
completion_promise: "ALL TESTS PASSING"
verify_command: "npm test"
verify_passed: false
team_name: ralpha-123456
team_size: 3
persona: null
started_at: "2026-02-26T08:00:00Z"
---

Build a REST API with auth and tests
STATE
}

create_parse_test_state
source "$REPO_ROOT/scripts/parse-state.sh"

# Test: load frontmatter fields
ralpha_load_frontmatter
assert_eq "parse mode" "team" "$(ralpha_parse_field "mode")"
assert_eq "parse iteration" "3" "$(ralpha_parse_field "iteration")"
assert_eq "parse max_iterations" "10" "$(ralpha_parse_field "max_iterations")"
assert_eq "parse completion_promise (strip quotes)" "ALL TESTS PASSING" "$(ralpha_parse_field "completion_promise")"
assert_eq "parse verify_command (strip quotes)" "npm test" "$(ralpha_parse_field "verify_command")"

# Test: parse prompt body
PROMPT=$(ralpha_parse_prompt)
assert_eq "parse prompt body" "Build a REST API with auth and tests" "$PROMPT"

# Test: multiline prompt
cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<'STATE'
---
active: true
mode: solo
iteration: 1
max_iterations: 0
completion_promise: null
verify_command: null
verify_passed: false
team_name: ralpha-999999
team_size: 1
persona: "implementer"
started_at: "2026-02-26T09:00:00Z"
---

Fix the login bug.
Also update the tests.
Make sure CI passes.
STATE

ralpha_load_frontmatter
PROMPT=$(ralpha_parse_prompt)
assert_contains "multiline prompt: line 1" "Fix the login bug." "$PROMPT"

# Test: prompt containing --- lines (frontmatter scoping invariant)
cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<'STATE'
---
active: true
mode: solo
iteration: 1
max_iterations: 5
completion_promise: "DONE"
verify_command: null
verify_passed: false
team_name: ralpha-999999
team_size: 1
persona: null
started_at: "2026-02-26T09:00:00Z"
---

Build a REST API.
---
Add authentication.
---
Write tests.
STATE

ralpha_load_frontmatter
assert_eq "dashes in prompt: mode" "solo" "$(ralpha_parse_field "mode")"

PROMPT=$(ralpha_parse_prompt)
assert_contains "dashes in prompt: first line" "Build a REST API." "$PROMPT"
assert_contains "dashes in prompt: separator preserved" "---" "$PROMPT"

teardown_test_env
