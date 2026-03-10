#!/usr/bin/env bash
set -euo pipefail

# Tests for QA logging and analysis toolkit (10 tests)

setup_test_env

SETUP="$REPO_ROOT/scripts/setup-ralpha.sh"
STOP_HOOK="$REPO_ROOT/hooks/stop-hook.sh"
ANALYZE="$REPO_ROOT/scripts/qa-analyze.sh"
QA_LOG="$TEST_TMPDIR/.claude/ralpha-qa.jsonl"

# ============================================================
# Test: qa-log.sh writes valid JSONL
# ============================================================

source "$REPO_ROOT/scripts/qa-log.sh"
qa_log "test" "basic" "key1=value1" "key2=value2"

assert_file_exists "qa log file created" "$QA_LOG"

ENTRY=$(tail -1 "$QA_LOG")
set +e
echo "$ENTRY" | jq -e . >/dev/null 2>&1
JQ_EXIT=$?
set -e
assert_exit "qa log entry is valid JSON" 0 $JQ_EXIT

# Check fields
KEY1=$(echo "$ENTRY" | jq -r '.data.key1')
assert_eq "qa log stores data fields correctly" "value1" "$KEY1"

# ============================================================
# Test: Instrumented setup writes to QA log
# ============================================================

: > "$QA_LOG"  # Clear log
OUTPUT=$(bash "$SETUP" --mode solo "test task" --max-iterations 5 --completion-promise "DONE" --verify-command "true" 2>&1)

SESSION_STARTS=$(jq -r 'select(.event=="session_start") | .event' "$QA_LOG" | wc -l | tr -d ' ')
assert_eq "setup logs session_start event" "1" "$SESSION_STARTS"

# ============================================================
# Test: qa-analyze.sh on empty log → error
# ============================================================

rm -f "$QA_LOG"
set +e
ANALYZE_OUT=$(bash "$ANALYZE" "$QA_LOG" 2>&1)
ANALYZE_EXIT=$?
set -e
assert_exit "analyze: no log file → exit 1" 1 $ANALYZE_EXIT

# ============================================================
# Test: qa-analyze.sh on a healthy session log
# ============================================================

cat > "$QA_LOG" <<'HEALTHY_LOG'
{"ts":"2026-02-26T10:00:00Z","component":"setup","event":"session_start","data":{"mode":"solo","max_iterations":10,"team_size":1,"has_promise":"true","has_verify":"true"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"invoked","data":{"iteration":1,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"transcript_parsed","data":{"msg_length":200}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"decision","data":{"action":"block","system_msg":"iteration 2"}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"invoked","data":{"iteration":2,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"transcript_parsed","data":{"msg_length":250}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"decision","data":{"action":"block","system_msg":"iteration 3"}}
{"ts":"2026-02-26T10:00:03Z","component":"stop-hook","event":"invoked","data":{"iteration":3,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:03Z","component":"stop-hook","event":"transcript_parsed","data":{"msg_length":300}}
{"ts":"2026-02-26T10:00:03Z","component":"stop-hook","event":"promise_check","data":{"detected":"true","text":"ALL DONE","expected":"ALL DONE"}}
{"ts":"2026-02-26T10:00:03Z","component":"verify","event":"passed","data":{"command":"true","duration_s":0}}
{"ts":"2026-02-26T10:00:03Z","component":"stop-hook","event":"verify_after_promise","data":{"exit_code":0,"duration_s":0}}
{"ts":"2026-02-26T10:00:03Z","component":"stop-hook","event":"session_complete","data":{"reason":"completed"}}
{"ts":"2026-02-26T10:00:04Z","component":"report","event":"generated","data":{"file":"ralpha-report.md","completion_reason":"completed"}}
HEALTHY_LOG

set +e
ANALYZE_OUT=$(bash "$ANALYZE" "$QA_LOG" 2>&1)
ANALYZE_EXIT=$?
set -e
assert_exit "analyze: healthy session → exit 0" 0 $ANALYZE_EXIT

FINDINGS=$(cat "$TEST_TMPDIR/.claude/ralpha-qa-findings.md")
assert_contains "findings: health score present" "Health Score:" "$FINDINGS"

rm -f "$TEST_TMPDIR/.claude/ralpha-qa-findings.md"

# ============================================================
# Test: qa-analyze.sh detects stuck loop (MUST-FIX)
# ============================================================

cat > "$QA_LOG" <<'STUCK_LOG'
{"ts":"2026-02-26T10:00:00Z","component":"setup","event":"session_start","data":{"mode":"solo","max_iterations":10,"team_size":1,"has_promise":"true","has_verify":"true"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"invoked","data":{"iteration":1,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"decision","data":{"action":"block","system_msg":"iter 2"}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"invoked","data":{"iteration":2,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"decision","data":{"action":"block","system_msg":"iter 3"}}
{"ts":"2026-02-26T10:00:03Z","component":"stop-hook","event":"invoked","data":{"iteration":3,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:03Z","component":"stop-hook","event":"decision","data":{"action":"block","system_msg":"iter 4"}}
{"ts":"2026-02-26T10:00:04Z","component":"stop-hook","event":"invoked","data":{"iteration":4,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:04Z","component":"stop-hook","event":"decision","data":{"action":"block","system_msg":"iter 5"}}
{"ts":"2026-02-26T10:00:05Z","component":"stop-hook","event":"invoked","data":{"iteration":5,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:05Z","component":"stop-hook","event":"decision","data":{"action":"block","system_msg":"iter 6"}}
STUCK_LOG

set +e; bash "$ANALYZE" "$QA_LOG" >/dev/null 2>&1; set -e
FINDINGS=$(cat "$TEST_TMPDIR/.claude/ralpha-qa-findings.md")
assert_contains "stuck loop detected (MUST-FIX)" "Stuck loop" "$FINDINGS"

rm -f "$TEST_TMPDIR/.claude/ralpha-qa-findings.md"

# ============================================================
# Test: qa-analyze.sh detects verification never passes (MUST-FIX)
# ============================================================

cat > "$QA_LOG" <<'VERIFY_FAIL_LOG'
{"ts":"2026-02-26T10:00:00Z","component":"setup","event":"session_start","data":{"mode":"solo","max_iterations":10,"team_size":1,"has_promise":"true","has_verify":"true"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"invoked","data":{"iteration":1,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"promise_check","data":{"detected":"true","text":"DONE","expected":"DONE"}}
{"ts":"2026-02-26T10:00:01Z","component":"verify","event":"failed","data":{"command":"false","exit_code":1,"duration_s":0}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"verify_after_promise","data":{"exit_code":1,"duration_s":0}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"invoked","data":{"iteration":2,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"promise_check","data":{"detected":"true","text":"DONE","expected":"DONE"}}
{"ts":"2026-02-26T10:00:02Z","component":"verify","event":"failed","data":{"command":"false","exit_code":1,"duration_s":0}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"verify_after_promise","data":{"exit_code":1,"duration_s":0}}
VERIFY_FAIL_LOG

set +e; bash "$ANALYZE" "$QA_LOG" >/dev/null 2>&1; set -e
FINDINGS=$(cat "$TEST_TMPDIR/.claude/ralpha-qa-findings.md")
assert_contains "verify-never-passes detected (MUST-FIX)" "Verification never passes" "$FINDINGS"

rm -f "$TEST_TMPDIR/.claude/ralpha-qa-findings.md"

# ============================================================
# Test: qa-analyze.sh detects excessive iterations
# ============================================================

{
echo '{"ts":"2026-02-26T10:00:00Z","component":"setup","event":"session_start","data":{"mode":"solo","max_iterations":10,"team_size":1,"has_promise":"true","has_verify":"true"}}'
for i in $(seq 1 9); do
  echo "{\"ts\":\"2026-02-26T10:00:0${i}Z\",\"component\":\"stop-hook\",\"event\":\"invoked\",\"data\":{\"iteration\":$i,\"max_iterations\":10,\"mode\":\"solo\"}}"
  echo "{\"ts\":\"2026-02-26T10:00:0${i}Z\",\"component\":\"stop-hook\",\"event\":\"decision\",\"data\":{\"action\":\"block\",\"system_msg\":\"iter $((i+1))\"}}"
done
echo '{"ts":"2026-02-26T10:00:10Z","component":"stop-hook","event":"invoked","data":{"iteration":10,"max_iterations":10,"mode":"solo"}}'
echo '{"ts":"2026-02-26T10:00:10Z","component":"stop-hook","event":"max_iterations_reached","data":{"iteration":10,"max_iterations":10}}'
echo '{"ts":"2026-02-26T10:00:10Z","component":"stop-hook","event":"session_complete","data":{"reason":"max_iterations_reached"}}'
} > "$QA_LOG"

set +e; bash "$ANALYZE" "$QA_LOG" >/dev/null 2>&1; set -e
FINDINGS=$(cat "$TEST_TMPDIR/.claude/ralpha-qa-findings.md")
assert_contains "excessive iterations detected" "Excessive iterations" "$FINDINGS"

teardown_test_env
