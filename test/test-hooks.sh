#!/bin/bash

# Tests for task-completed-hook.sh and teammate-idle-hook.sh

setup_test_env

TASK_HOOK="$REPO_ROOT/hooks/task-completed-hook.sh"
IDLE_HOOK="$REPO_ROOT/hooks/teammate-idle-hook.sh"

# --- Helper ---
create_state() {
  local mode="$1" verify="$2"
  local verify_yaml
  if [[ "$verify" = "null" ]]; then verify_yaml="null"; else verify_yaml="\"$verify\""; fi
  cat > "$TEST_TMPDIR/.claude/ralpha-team.local.md" <<EOF
---
active: true
mode: $mode
iteration: 1
max_iterations: 0
completion_promise: null
verify_command: $verify_yaml
verify_passed: false
team_name: ralpha-test
team_size: 3
persona: null
started_at: "2026-02-26T08:00:00Z"
---

test prompt
EOF
}

# ============================================================
# task-completed-hook: no state → allow
# ============================================================

set +e
OUTPUT=$(echo '{}' | bash "$TASK_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "task-completed: no state → exit 0" 0 $EXIT

# ============================================================
# task-completed-hook: no verify → allow
# ============================================================

create_state "team" "null"

set +e
OUTPUT=$(echo '{}' | bash "$TASK_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "task-completed: no verify → exit 0" 0 $EXIT

# ============================================================
# task-completed-hook: verify passes → allow
# ============================================================

create_state "team" "true"

set +e
OUTPUT=$(echo '{}' | bash "$TASK_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "task-completed: verify passes → exit 0" 0 $EXIT

# ============================================================
# task-completed-hook: verify fails → block (exit 2)
# ============================================================

create_state "team" "false"

set +e
OUTPUT=$(echo '{}' | bash "$TASK_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "task-completed: verify fails → exit 2" 2 $EXIT
assert_contains "task-completed: block message" "verification command failed" "$OUTPUT"

# ============================================================
# teammate-idle-hook: no state → allow
# ============================================================

rm -f "$TEST_TMPDIR/.claude/ralpha-team.local.md"

set +e
OUTPUT=$(echo '{}' | bash "$IDLE_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "idle: no state → exit 0" 0 $EXIT

# ============================================================
# teammate-idle-hook: solo mode → allow
# ============================================================

create_state "solo" "null"

set +e
OUTPUT=$(echo '{}' | bash "$IDLE_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "idle: solo mode → exit 0" 0 $EXIT

# ============================================================
# teammate-idle-hook: team mode → block with task list nudge
# ============================================================

create_state "team" "null"

set +e
OUTPUT=$(echo '{}' | bash "$IDLE_HOOK" 2>&1)
EXIT=$?
set -e
assert_exit "idle: team mode → exit 2" 2 $EXIT
assert_contains "idle: nudge mentions TaskList" "TaskList" "$OUTPUT"

teardown_test_env
