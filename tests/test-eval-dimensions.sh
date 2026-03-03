#!/bin/bash

# Tests for the 10-dimension quality evaluator (10 tests)

setup_test_env

EVAL_SCRIPT="$REPO_ROOT/scripts/eval-dimensions.sh"

# ============================================================
# Basic execution
# ============================================================

set +e
OUTPUT=$(bash "$EVAL_SCRIPT" 2>&1)
EXIT=$?
set -e
assert_eq "eval script exits with integer exit code" "true" "$( [[ $EXIT =~ ^[0-9]+$ ]] && echo true || echo false )"

# ============================================================
# Output file created
# ============================================================

assert_file_exists "output file created" "$REPO_ROOT/.claude/ralpha-eval.md"

EVAL_OUTPUT=$(cat "$REPO_ROOT/.claude/ralpha-eval.md")

# ============================================================
# All 10 dimension names present
# ============================================================

ALL_DIMS=true
for dim in Robust Genuine Minimal Autonomous Adversarial Rigorous Deterministic Reproducible Literate Curated; do
  if ! echo "$EVAL_OUTPUT" | grep -q "$dim"; then ALL_DIMS=false; fi
done
assert_eq "output contains all 10 dimension names" "true" "$ALL_DIMS"

# ============================================================
# Overall score line present with X.X format
# ============================================================

set +e
echo "$EVAL_OUTPUT" | grep -qE 'Overall: [0-9]\.[0-9] / 5\.0'
HAS_OVERALL=$?
set -e
assert_eq "overall score line present" 0 "$HAS_OVERALL"

# ============================================================
# Dimension filter works
# ============================================================

set +e
FILTERED=$(bash "$EVAL_SCRIPT" 1 2 2>&1)
set -e
FILTERED_COUNT=$(echo "$FILTERED" | grep -c "D0[0-9]" || echo 0)
assert_eq "dimension filter shows only selected dims" "2" "$FILTERED_COUNT"

# ============================================================
# All scores are integers 1-5
# ============================================================

ALL_VALID=true
while IFS= read -r score; do
  case "$score" in 1|2|3|4|5) ;; *) ALL_VALID=false ;; esac
done < <(echo "$EVAL_OUTPUT" | grep -oE '[0-9]+/5' | cut -d/ -f1)
assert_eq "all scores are integers 1-5" "true" "$ALL_VALID"

# ============================================================
# Sabotage test: hiding a file triggers failure
# ============================================================

# Temporarily move an agent file out of agents/ to trigger D09 check 4 (all agents have examples)
mv "$REPO_ROOT/agents/debugger.md" "$TEST_TMPDIR/debugger.md.bak"
set +e
bash "$EVAL_SCRIPT" 9 >/dev/null 2>&1
SABOTAGED_OUTPUT=$(cat "$REPO_ROOT/.claude/ralpha-eval.md")
mv "$TEST_TMPDIR/debugger.md.bak" "$REPO_ROOT/agents/debugger.md"
set -e
assert_contains "sabotage triggers failing check" "FAIL" "$SABOTAGED_OUTPUT"

# ============================================================
# Current repo scores >= 4.0 overall
# ============================================================

OVERALL_SCORE=$(echo "$EVAL_OUTPUT" | grep -oE 'Overall: [0-9]\.[0-9]' | grep -oE '[0-9]\.[0-9]')
ABOVE_4=$(awk "BEGIN{print ($OVERALL_SCORE >= 4.0) ? \"true\" : \"false\"}")
assert_eq "current repo scores >= 4.0 overall" "true" "$ABOVE_4"

# ============================================================
# Check count total >= 35
# ============================================================

CHECK_TOTAL=$(echo "$EVAL_OUTPUT" | grep -oE 'Checks: [0-9]+/[0-9]+' | grep -oE '/[0-9]+' | tr -d '/')
assert_eq "check count total >= 35" "true" "$( [[ $CHECK_TOTAL -ge 35 ]] && echo true || echo false )"

# ============================================================
# Exit code equals count of dimensions scoring below 5
# ============================================================

BELOW_5=$(echo "$EVAL_OUTPUT" | grep -oE '   [1-4]/5' | wc -l | tr -d ' ')
assert_eq "exit code = dimensions below 5" "$BELOW_5" "$EXIT"

teardown_test_env
