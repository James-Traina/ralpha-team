#!/bin/bash

# Self-verification tests: cross-references, count accuracy, and structural integrity.
# These tests verify that documentation matches the filesystem — catching
# the class of bugs where you add a component but forget to update the README.

setup_test_env

# ============================================================
# JSON validity
# ============================================================

echo "  -- JSON validity --"

set +e
jq empty "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null
EXIT=$?
set -e
assert_eq "plugin.json is valid JSON" 0 "$EXIT"

set +e
jq empty "$REPO_ROOT/hooks/hooks.json" 2>/dev/null
EXIT=$?
set -e
assert_eq "hooks.json is valid JSON" 0 "$EXIT"

# plugin.json required fields
for field in name version description license; do
  set +e
  jq -e "has(\"$field\")" "$REPO_ROOT/.claude-plugin/plugin.json" >/dev/null 2>&1
  EXIT=$?
  set -e
  assert_eq "plugin.json has '$field' field" 0 "$EXIT"
done

# ============================================================
# hooks.json structure
# ============================================================

echo "  -- hooks.json structure --"

# Every hook entry has matcher and timeout
set +e
HOOK_ISSUES=$(jq -r '
  .hooks | to_entries[] | .key as $event |
  .value[] |
  (if has("matcher") | not then "\($event): missing matcher" else empty end),
  (.hooks[] | if has("timeout") | not then "\($event): missing timeout" else empty end)
' "$REPO_ROOT/hooks/hooks.json" 2>/dev/null)
set -e
assert_eq "all hooks have matcher + timeout" "" "$HOOK_ISSUES"

# Valid event types
VALID_EVENTS="SessionStart SessionEnd PreToolUse PostToolUse Stop SubagentStop UserPromptSubmit PreCompact Notification TaskCompleted TeammateIdle"
set +e
INVALID_EVENTS=$(jq -r --arg valid "$VALID_EVENTS" '
  ($valid | split(" ")) as $v |
  .hooks | keys[] | select(. as $k | $v | index($k) | not)
' "$REPO_ROOT/hooks/hooks.json" 2>/dev/null)
set -e
assert_eq "all hook events are valid" "" "$INVALID_EVENTS"

# SessionStart uses portable CLAUDE_PLUGIN_ROOT path
set +e
SESSION_CMD=$(jq -r '
  .hooks.SessionStart[]?.hooks[] | select(.type == "command") | .command
' "$REPO_ROOT/hooks/hooks.json" 2>/dev/null)
set -e
assert_contains "SessionStart uses \${CLAUDE_PLUGIN_ROOT}" "CLAUDE_PLUGIN_ROOT" "$SESSION_CMD"

# ============================================================
# Cross-references: agents referenced in CLAUDE.md exist on disk
# ============================================================

echo "  -- CLAUDE.md cross-references --"

# Agent names mentioned in CLAUDE.md
CLAUDE_AGENTS=$(grep -oE '\b(architect|implementer|tester|reviewer|debugger)\b' "$REPO_ROOT/CLAUDE.md" | sort -u)
for agent in $CLAUDE_AGENTS; do
  assert_file_exists "CLAUDE.md agent '$agent' exists" "$REPO_ROOT/agents/$agent.md"
done

# Commands mentioned in CLAUDE.md (extract /ralpha-team:NAME patterns)
CLAUDE_CMDS=$(grep -oE '/ralpha-team:([a-z]+)' "$REPO_ROOT/CLAUDE.md" | sed 's|/ralpha-team:||' | sort -u)
for cmd in $CLAUDE_CMDS; do
  assert_file_exists "CLAUDE.md command '$cmd' exists" "$REPO_ROOT/commands/$cmd.md"
done

# ============================================================
# Cross-references: README references exist on disk
# ============================================================

echo "  -- README cross-references --"

# Agent names in README
README_AGENTS=$(grep -oE '\*\*(architect|implementer|tester|reviewer|debugger)\*\*' "$REPO_ROOT/README.md" | sed 's/\*\*//g' | sort -u)
for agent in $README_AGENTS; do
  assert_file_exists "README agent '$agent' exists" "$REPO_ROOT/agents/$agent.md"
done

# Commands in README
README_CMDS=$(grep -oE '/ralpha-team:([a-z]+)' "$REPO_ROOT/README.md" | sed 's|/ralpha-team:||' | sort -u)
for cmd in $README_CMDS; do
  assert_file_exists "README command '$cmd' exists" "$REPO_ROOT/commands/$cmd.md"
done

# ============================================================
# Count verification: README claims match filesystem
# ============================================================

echo "  -- count verification --"

# Agent count
ACTUAL_AGENTS=$(find "$REPO_ROOT/agents" -name "*.md" | wc -l | tr -d ' ')
README_AGENT_COUNT=$(grep -oE 'Agents \| [0-9]+' "$REPO_ROOT/README.md" | grep -oE '[0-9]+')
assert_eq "README agent count matches filesystem" "$ACTUAL_AGENTS" "$README_AGENT_COUNT"

# Command count
ACTUAL_CMDS=$(find "$REPO_ROOT/commands" -name "*.md" | wc -l | tr -d ' ')
README_CMD_COUNT=$(grep -oE 'Commands \| [0-9]+' "$REPO_ROOT/README.md" | grep -oE '[0-9]+')
assert_eq "README command count matches filesystem" "$ACTUAL_CMDS" "$README_CMD_COUNT"

# Hook count
ACTUAL_HOOKS=$(jq '.hooks | length' "$REPO_ROOT/hooks/hooks.json" 2>/dev/null)
README_HOOK_COUNT=$(grep -oE 'Hooks \| [0-9]+' "$REPO_ROOT/README.md" | grep -oE '[0-9]+')
assert_eq "README hook count matches filesystem" "$ACTUAL_HOOKS" "$README_HOOK_COUNT"

# Script count
ACTUAL_SCRIPTS=$(find "$REPO_ROOT/scripts" -name "*.sh" | wc -l | tr -d ' ')
README_SCRIPT_COUNT=$(grep -oE 'Scripts \| [0-9]+' "$REPO_ROOT/README.md" | grep -oE '[0-9]+')
assert_eq "README script count matches filesystem" "$ACTUAL_SCRIPTS" "$README_SCRIPT_COUNT"

# Skill count
ACTUAL_SKILLS=$(find "$REPO_ROOT/skills" -name "SKILL.md" | wc -l | tr -d ' ')
README_SKILL_COUNT=$(grep -oE 'Skills \| [0-9]+' "$REPO_ROOT/README.md" | grep -oE '[0-9]+')
assert_eq "README skill count matches filesystem" "$ACTUAL_SKILLS" "$README_SKILL_COUNT"

# Test file count
ACTUAL_TEST_FILES=$(find "$REPO_ROOT/test" -name "test-*.sh" -not -name "test-runner.sh" | wc -l | tr -d ' ')
README_TEST_COUNT=$(grep -oE '[0-9]+ test files' "$REPO_ROOT/README.md" | grep -oE '[0-9]+')
assert_eq "README test file count matches filesystem" "$ACTUAL_TEST_FILES" "$README_TEST_COUNT"

# ============================================================
# Content quality: no hardcoded paths or stale placeholders
# ============================================================

echo "  -- content quality --"

# No hardcoded personal paths in shipped files (excluding .gitignore and test files)
set +e
HARDCODED=$(grep -rn '/Users/jat406\|/home/jat406' \
  "$REPO_ROOT/agents" "$REPO_ROOT/commands" "$REPO_ROOT/hooks" \
  "$REPO_ROOT/scripts" "$REPO_ROOT/skills" "$REPO_ROOT/CLAUDE.md" \
  "$REPO_ROOT/README.md" "$REPO_ROOT/.claude-plugin" 2>/dev/null || true)
set -e
assert_eq "no hardcoded personal paths" "" "$HARDCODED"

# No TODO/FIXME/HACK in shipped files
set +e
TODOS=$(grep -rn -E '^\s*(#|//|<!--)\s*(TODO|FIXME|XXX|HACK)\b' \
  "$REPO_ROOT/agents" "$REPO_ROOT/commands" "$REPO_ROOT/hooks" \
  "$REPO_ROOT/scripts" "$REPO_ROOT/skills" 2>/dev/null || true)
set -e
assert_eq "no TODO/FIXME/HACK markers in shipped code" "" "$TODOS"

# No PLACEHOLDER/CHANGEME stubs
set +e
STUBS=$(grep -rn -E 'PLACEHOLDER|CHANGEME|FILL_IN|<insert ' \
  "$REPO_ROOT/agents" "$REPO_ROOT/commands" "$REPO_ROOT/hooks" \
  "$REPO_ROOT/scripts" "$REPO_ROOT/skills" 2>/dev/null || true)
set -e
assert_eq "no placeholder stubs" "" "$STUBS"

# ============================================================
# Agent depth: all agents should be substantive (>40 lines)
# ============================================================

echo "  -- agent depth --"

for agent_file in "$REPO_ROOT"/agents/*.md; do
  name=$(basename "$agent_file" .md)
  lines=$(wc -l < "$agent_file" | tr -d ' ')
  set +e
  [ "$lines" -ge 40 ]
  RESULT=$?
  set -e
  assert_eq "agent '$name' has sufficient depth (${lines} lines >= 40)" 0 "$RESULT"
done

# ============================================================
# Session-init.sh: functional checks
# ============================================================

echo "  -- session-init.sh --"

assert_file_exists "session-init.sh exists" "$REPO_ROOT/scripts/session-init.sh"

# Runs without error when env vars are missing
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_TMPDIR" CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="" bash "$REPO_ROOT/scripts/session-init.sh" 2>&1)
EXIT=$?
set -e
assert_eq "session-init.sh exits cleanly" 0 "$EXIT"

# Warns about missing agent teams env var (explicitly unset above)
assert_contains "session-init.sh warns about missing env var" "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$OUTPUT"

# Detects stale state file
mkdir -p "$TEST_TMPDIR/.claude"
echo "---" > "$TEST_TMPDIR/.claude/ralpha-team.local.md"
echo "active: true" >> "$TEST_TMPDIR/.claude/ralpha-team.local.md"
echo "---" >> "$TEST_TMPDIR/.claude/ralpha-team.local.md"

set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_TMPDIR" bash "$REPO_ROOT/scripts/session-init.sh" 2>&1)
set -e
assert_contains "session-init.sh warns about stale state" "previous session" "$OUTPUT"

teardown_test_env
