#!/usr/bin/env bash
set -euo pipefail

# ralpha-team PostToolUse Validation Hook
#
# Runs typecheck and/or lint after source file modifications.
# Opt-in per project: create .ralpha-validate.conf in the project root.
#
# .ralpha-validate.conf example:
#   TYPECHECK_CMD="npx tsc --noEmit 2>&1"
#   LINT_CMD="npx eslint src/ --quiet 2>&1"
#
# The hook exits non-zero to block the agent from continuing if validation fails.
# Keep commands fast (<10s) — this runs after every Edit/Write on a source file.

CONF=".ralpha-validate.conf"

# Opt-in only — do nothing if no project config exists
[ ! -f "$CONF" ] && exit 0

# Parse the edited file path from the tool result JSON (piped via stdin)
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Skip if file path is unavailable
[ -z "$FILE" ] && exit 0

# Skip non-source files — these don't need typecheck/lint
case "$FILE" in
  *.md|*.txt|*.json|*.yml|*.yaml|*.toml|*.env|*.conf|*.lock|*.sum|*.gitignore)
    exit 0 ;;
esac

# Load project-specific validation commands
# shellcheck source=/dev/null
source "$CONF"

FAILED=0

if [ -n "${TYPECHECK_CMD:-}" ]; then
  set +e; RESULT=$(eval "$TYPECHECK_CMD" 2>&1); STATUS=$?; set -e
  if [ $STATUS -ne 0 ]; then
    echo "TYPECHECK FAILED (after editing ${FILE##*/}):"
    echo "$RESULT" | tail -20
    FAILED=1
  fi
fi

if [ -n "${LINT_CMD:-}" ]; then
  set +e; RESULT=$(eval "$LINT_CMD" 2>&1); STATUS=$?; set -e
  if [ $STATUS -ne 0 ]; then
    echo "LINT FAILED (after editing ${FILE##*/}):"
    echo "$RESULT" | tail -20
    FAILED=1
  fi
fi

exit $FAILED
