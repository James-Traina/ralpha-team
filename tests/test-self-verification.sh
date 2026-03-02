#!/bin/bash

# Self-verification tests: cross-references, count accuracy, and structural integrity (10 tests)

setup_test_env

# ============================================================
# JSON validity
# ============================================================

set +e
jq empty "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null
EXIT=$?
set -e
assert_eq "plugin.json is valid JSON" 0 "$EXIT"

set +e
jq -e 'has("name")' "$REPO_ROOT/.claude-plugin/plugin.json" >/dev/null 2>&1
EXIT=$?
set -e
assert_eq "plugin.json has name field" 0 "$EXIT"

# ============================================================
# hooks.json structure
# ============================================================

set +e
HOOK_ISSUES=$(jq -r '
  .hooks | to_entries[] | .key as $event |
  .value[] |
  (if has("matcher") | not then "\($event): missing matcher" else empty end),
  (.hooks[] | if has("timeout") | not then "\($event): missing timeout" else empty end)
' "$REPO_ROOT/hooks/hooks.json" 2>/dev/null)
set -e
assert_eq "all hooks have matcher + timeout" "" "$HOOK_ISSUES"

# ============================================================
# Count verification: README claims match filesystem
# ============================================================

echo "  -- count verification --"

ACTUAL_AGENTS=$(find "$REPO_ROOT/agents" -name "*.md" | wc -l | tr -d ' ')
README_AGENT_COUNT=$(grep -oE 'Agents \| [0-9]+' "$REPO_ROOT/README.md" | grep -oE '[0-9]+')
assert_eq "README agent count matches filesystem" "$ACTUAL_AGENTS" "$README_AGENT_COUNT"

ACTUAL_CMDS=$(find "$REPO_ROOT/commands" -name "*.md" | wc -l | tr -d ' ')
README_CMD_COUNT=$(grep -oE 'Commands \| [0-9]+' "$REPO_ROOT/README.md" | grep -oE '[0-9]+')
assert_eq "README command count matches filesystem" "$ACTUAL_CMDS" "$README_CMD_COUNT"

ACTUAL_HOOKS=$(jq '.hooks | length' "$REPO_ROOT/hooks/hooks.json" 2>/dev/null)
README_HOOK_COUNT=$(grep -oE 'Hooks \| [0-9]+' "$REPO_ROOT/README.md" | grep -oE '[0-9]+')
assert_eq "README hook count matches filesystem" "$ACTUAL_HOOKS" "$README_HOOK_COUNT"

ACTUAL_TEST_FILES=$(find "$REPO_ROOT/tests" -name "test-*.sh" -not -name "test-runner.sh" | wc -l | tr -d ' ')
README_TEST_COUNT=$(grep -oE '[0-9]+ test files' "$REPO_ROOT/README.md" | grep -oE '[0-9]+')
assert_eq "README test file count matches filesystem" "$ACTUAL_TEST_FILES" "$README_TEST_COUNT"

# ============================================================
# Content quality
# ============================================================

set +e
HARDCODED=$(grep -rn '/Users/jat406\|/home/jat406' \
  "$REPO_ROOT/agents" "$REPO_ROOT/commands" "$REPO_ROOT/hooks" \
  "$REPO_ROOT/scripts" "$REPO_ROOT/skills" "$REPO_ROOT/CLAUDE.md" \
  "$REPO_ROOT/README.md" "$REPO_ROOT/.claude-plugin" 2>/dev/null || true)
set -e
assert_eq "no hardcoded personal paths" "" "$HARDCODED"

# ============================================================
# Session-init.sh: functional checks
# ============================================================

set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_TMPDIR" CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="" bash "$REPO_ROOT/scripts/session-init.sh" 2>&1)
EXIT=$?
set -e
assert_eq "session-init.sh exits cleanly" 0 "$EXIT"

assert_contains "session-init.sh warns about missing env var" "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$OUTPUT"

teardown_test_env
