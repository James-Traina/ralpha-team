#!/bin/bash

# Tests for QA logging and analysis toolkit

setup_test_env

SETUP="$REPO_ROOT/scripts/setup-ralpha.sh"
STOP_HOOK="$REPO_ROOT/hooks/stop-hook.sh"
ANALYZE="$REPO_ROOT/scripts/qa-analyze.sh"
QA_LOG="$TEST_TMPDIR/.claude/ralpha-qa.jsonl"

create_transcript() {
  local text="$1"
  local f="$TEST_TMPDIR/transcript.jsonl"
  jq -cn --arg t "$text" '{"role":"assistant","message":{"content":[{"type":"text","text":$t}]}}' > "$f"
  echo "$f"
}

hook_input() {
  printf '{"transcript_path":"%s"}' "$1"
}

# ============================================================
# Test: qa-log.sh writes valid JSONL
# ============================================================

source "$REPO_ROOT/scripts/qa-log.sh"
qa_log "test" "basic" "key1=value1" "key2=value2"

assert_file_exists "qa log file created" "$QA_LOG"

ENTRY=$(tail -1 "$QA_LOG")
# Validate it's valid JSON
set +e
echo "$ENTRY" | jq -e . >/dev/null 2>&1
JQ_EXIT=$?
set -e
assert_exit "qa log entry is valid JSON" 0 $JQ_EXIT

# Check fields
COMPONENT=$(echo "$ENTRY" | jq -r '.component')
EVENT=$(echo "$ENTRY" | jq -r '.event')
KEY1=$(echo "$ENTRY" | jq -r '.data.key1')
assert_eq "qa log: component" "test" "$COMPONENT"
assert_eq "qa log: event" "basic" "$EVENT"
assert_eq "qa log: data.key1" "value1" "$KEY1"

# Test qa_log_num with numeric values
qa_log_num "test" "numeric" "count=42" "label=hello"
ENTRY=$(tail -1 "$QA_LOG")
COUNT=$(echo "$ENTRY" | jq '.data.count')
assert_eq "qa log_num: numeric value" "42" "$COUNT"

# ============================================================
# Test: Instrumented setup writes to QA log
# ============================================================

: > "$QA_LOG"  # Clear log
OUTPUT=$(bash "$SETUP" --mode solo "test task" --max-iterations 5 --completion-promise "DONE" --verify-command "true" 2>&1)

assert_file_exists "qa log exists after setup" "$QA_LOG"
SESSION_STARTS=$(jq -r 'select(.event=="session_start") | .event' "$QA_LOG" | wc -l | tr -d ' ')
assert_eq "setup logged session_start" "1" "$SESSION_STARTS"

START_MODE=$(jq -r 'select(.event=="session_start") | .data.mode' "$QA_LOG")
assert_eq "session_start mode" "solo" "$START_MODE"

# ============================================================
# Test: Instrumented stop-hook writes to QA log
# ============================================================

TRANSCRIPT=$(create_transcript "working on it")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); set -e

INVOCATIONS=$(jq -r 'select(.component=="stop-hook" and .event=="invoked") | .event' "$QA_LOG" | wc -l | tr -d ' ')
assert_eq "stop-hook logged invocation" "1" "$INVOCATIONS"

DECISIONS=$(jq -r 'select(.component=="stop-hook" and .event=="decision") | .event' "$QA_LOG" | wc -l | tr -d ' ')
assert_eq "stop-hook logged decision" "1" "$DECISIONS"

TRANSCRIPT_PARSED=$(jq -r 'select(.component=="stop-hook" and .event=="transcript_parsed") | .event' "$QA_LOG" | wc -l | tr -d ' ')
assert_eq "stop-hook logged transcript_parsed" "1" "$TRANSCRIPT_PARSED"

# ============================================================
# Test: Promise check logged
# ============================================================

TRANSCRIPT=$(create_transcript "<promise>DONE</promise>")
set +e; OUTPUT=$(hook_input "$TRANSCRIPT" | bash "$STOP_HOOK" 2>&1); set -e

PROMISE_DETECTED_LOGS=$(jq -r 'select(.component=="stop-hook" and .event=="promise_check" and .data.detected=="true") | .event' "$QA_LOG" | wc -l | tr -d ' ')
assert_eq "promise detected logged" "1" "$PROMISE_DETECTED_LOGS"

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

# Create a synthetic healthy session log
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
assert_file_exists "findings file created" "$TEST_TMPDIR/ralpha-qa-findings.md"

FINDINGS=$(cat "$TEST_TMPDIR/ralpha-qa-findings.md")
assert_contains "findings: health score" "Health Score:" "$FINDINGS"
assert_contains "findings: shows mode" "solo" "$FINDINGS"
assert_contains "findings: no issues" "No issues detected" "$FINDINGS"

rm -f "$TEST_TMPDIR/ralpha-qa-findings.md"

# ============================================================
# Test: qa-analyze.sh detects stuck loop
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
FINDINGS=$(cat "$TEST_TMPDIR/ralpha-qa-findings.md")
assert_contains "stuck loop detected" "Stuck loop" "$FINDINGS"
assert_contains "stuck loop is MUST-FIX" "MUST-FIX" "$FINDINGS"

rm -f "$TEST_TMPDIR/ralpha-qa-findings.md"

# ============================================================
# Test: qa-analyze.sh detects verification never passes
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
FINDINGS=$(cat "$TEST_TMPDIR/ralpha-qa-findings.md")
assert_contains "verify-never-passes detected" "Verification never passes" "$FINDINGS"
assert_contains "verify-never-passes is MUST-FIX" "MUST-FIX" "$FINDINGS"

rm -f "$TEST_TMPDIR/ralpha-qa-findings.md"

# ============================================================
# Test: qa-analyze.sh detects excessive iterations
# ============================================================

# Build log with 9/10 iterations used
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
FINDINGS=$(cat "$TEST_TMPDIR/ralpha-qa-findings.md")
assert_contains "excessive iterations detected" "Excessive iterations" "$FINDINGS"
assert_contains "excessive iterations is SHOULD-FIX" "SHOULD-FIX" "$FINDINGS"

rm -f "$TEST_TMPDIR/ralpha-qa-findings.md"

# ============================================================
# Test: qa-analyze.sh detects idle waste
# ============================================================

cat > "$QA_LOG" <<'IDLE_LOG'
{"ts":"2026-02-26T10:00:00Z","component":"setup","event":"session_start","data":{"mode":"team","max_iterations":10,"team_size":3,"has_promise":"true","has_verify":"true"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"invoked","data":{"iteration":1,"max_iterations":10,"mode":"team"}}
{"ts":"2026-02-26T10:00:01Z","component":"idle-hook","event":"nudge","data":{"mode":"team"}}
{"ts":"2026-02-26T10:00:02Z","component":"idle-hook","event":"nudge","data":{"mode":"team"}}
{"ts":"2026-02-26T10:00:03Z","component":"idle-hook","event":"nudge","data":{"mode":"team"}}
{"ts":"2026-02-26T10:00:04Z","component":"stop-hook","event":"invoked","data":{"iteration":2,"max_iterations":10,"mode":"team"}}
{"ts":"2026-02-26T10:00:04Z","component":"stop-hook","event":"promise_check","data":{"detected":"true","text":"DONE","expected":"DONE"}}
{"ts":"2026-02-26T10:00:04Z","component":"verify","event":"passed","data":{"command":"true","duration_s":0}}
{"ts":"2026-02-26T10:00:04Z","component":"stop-hook","event":"session_complete","data":{"reason":"completed"}}
IDLE_LOG

set +e; bash "$ANALYZE" "$QA_LOG" >/dev/null 2>&1; set -e
FINDINGS=$(cat "$TEST_TMPDIR/ralpha-qa-findings.md")
assert_contains "idle waste detected" "Idle teammate waste" "$FINDINGS"

rm -f "$TEST_TMPDIR/ralpha-qa-findings.md"

# ============================================================
# Test: qa-analyze.sh detects flaky verification
# ============================================================

cat > "$QA_LOG" <<'FLAKY_LOG'
{"ts":"2026-02-26T10:00:00Z","component":"setup","event":"session_start","data":{"mode":"solo","max_iterations":10,"team_size":1,"has_promise":"true","has_verify":"true"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"invoked","data":{"iteration":1,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"promise_check","data":{"detected":"true","text":"DONE","expected":"DONE"}}
{"ts":"2026-02-26T10:00:01Z","component":"verify","event":"failed","data":{"command":"npm test","exit_code":1,"duration_s":2}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"invoked","data":{"iteration":2,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"promise_check","data":{"detected":"true","text":"DONE","expected":"DONE"}}
{"ts":"2026-02-26T10:00:02Z","component":"verify","event":"passed","data":{"command":"npm test","duration_s":2}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"session_complete","data":{"reason":"completed"}}
FLAKY_LOG

set +e; bash "$ANALYZE" "$QA_LOG" >/dev/null 2>&1; set -e
FINDINGS=$(cat "$TEST_TMPDIR/ralpha-qa-findings.md")
assert_contains "flaky verify detected" "Flaky verification" "$FINDINGS"
assert_contains "flaky verify is SHOULD-FIX" "SHOULD-FIX" "$FINDINGS"

rm -f "$TEST_TMPDIR/ralpha-qa-findings.md"

# ============================================================
# Test: qa-analyze.sh detects mismatched promise
# ============================================================

cat > "$QA_LOG" <<'MISMATCH_LOG'
{"ts":"2026-02-26T10:00:00Z","component":"setup","event":"session_start","data":{"mode":"solo","max_iterations":10,"team_size":1,"has_promise":"true","has_verify":"true"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"invoked","data":{"iteration":1,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"promise_check","data":{"detected":"false","text":"ALMOST DONE","expected":"ALL DONE"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"decision","data":{"action":"block","system_msg":"iter 2"}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"invoked","data":{"iteration":2,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"promise_check","data":{"detected":"true","text":"ALL DONE","expected":"ALL DONE"}}
{"ts":"2026-02-26T10:00:02Z","component":"verify","event":"passed","data":{"command":"true","duration_s":0}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"session_complete","data":{"reason":"completed"}}
MISMATCH_LOG

set +e; bash "$ANALYZE" "$QA_LOG" >/dev/null 2>&1; set -e
FINDINGS=$(cat "$TEST_TMPDIR/ralpha-qa-findings.md")
assert_contains "mismatched promise detected" "Mismatched promise" "$FINDINGS"

rm -f "$TEST_TMPDIR/ralpha-qa-findings.md"

# ============================================================
# Test: qa-analyze.sh detects task gate blocking
# ============================================================

cat > "$QA_LOG" <<'GATE_LOG'
{"ts":"2026-02-26T10:00:00Z","component":"setup","event":"session_start","data":{"mode":"team","max_iterations":10,"team_size":3,"has_promise":"true","has_verify":"true"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"invoked","data":{"iteration":1,"max_iterations":10,"mode":"team"}}
{"ts":"2026-02-26T10:00:01Z","component":"task-completed","event":"gate_blocked","data":{"exit_code":1,"duration_s":1}}
{"ts":"2026-02-26T10:00:02Z","component":"task-completed","event":"gate_blocked","data":{"exit_code":1,"duration_s":1}}
{"ts":"2026-02-26T10:00:03Z","component":"task-completed","event":"gate_blocked","data":{"exit_code":1,"duration_s":1}}
{"ts":"2026-02-26T10:00:04Z","component":"stop-hook","event":"invoked","data":{"iteration":2,"max_iterations":10,"mode":"team"}}
{"ts":"2026-02-26T10:00:04Z","component":"stop-hook","event":"promise_check","data":{"detected":"true","text":"DONE","expected":"DONE"}}
{"ts":"2026-02-26T10:00:04Z","component":"verify","event":"passed","data":{"command":"true","duration_s":0}}
{"ts":"2026-02-26T10:00:04Z","component":"stop-hook","event":"session_complete","data":{"reason":"completed"}}
GATE_LOG

set +e; bash "$ANALYZE" "$QA_LOG" >/dev/null 2>&1; set -e
FINDINGS=$(cat "$TEST_TMPDIR/ralpha-qa-findings.md")
assert_contains "task gate blocking detected" "Task gate blocking" "$FINDINGS"
assert_contains "task gate blocking is SHOULD-FIX" "SHOULD-FIX" "$FINDINGS"

rm -f "$TEST_TMPDIR/ralpha-qa-findings.md"

# ============================================================
# Test: qa-analyze.sh detects slow verification
# ============================================================

cat > "$QA_LOG" <<'SLOW_LOG'
{"ts":"2026-02-26T10:00:00Z","component":"setup","event":"session_start","data":{"mode":"solo","max_iterations":10,"team_size":1,"has_promise":"true","has_verify":"true"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"invoked","data":{"iteration":1,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"promise_check","data":{"detected":"true","text":"DONE","expected":"DONE"}}
{"ts":"2026-02-26T10:00:01Z","component":"verify","event":"passed","data":{"command":"npm test","duration_s":45}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"session_complete","data":{"reason":"completed"}}
SLOW_LOG

set +e; bash "$ANALYZE" "$QA_LOG" >/dev/null 2>&1; set -e
FINDINGS=$(cat "$TEST_TMPDIR/ralpha-qa-findings.md")
assert_contains "slow verify detected" "Slow verification" "$FINDINGS"

rm -f "$TEST_TMPDIR/ralpha-qa-findings.md"

# ============================================================
# Test: Health score calculation
# ============================================================

# Healthy: 100/100
cat > "$QA_LOG" <<'PERFECT_LOG'
{"ts":"2026-02-26T10:00:00Z","component":"setup","event":"session_start","data":{"mode":"solo","max_iterations":10,"team_size":1,"has_promise":"true","has_verify":"true"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"invoked","data":{"iteration":1,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"decision","data":{"action":"block","system_msg":"iter 2"}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"invoked","data":{"iteration":2,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:02Z","component":"stop-hook","event":"decision","data":{"action":"block","system_msg":"iter 3"}}
{"ts":"2026-02-26T10:00:03Z","component":"stop-hook","event":"invoked","data":{"iteration":3,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:03Z","component":"stop-hook","event":"promise_check","data":{"detected":"true","text":"DONE","expected":"DONE"}}
{"ts":"2026-02-26T10:00:03Z","component":"verify","event":"passed","data":{"command":"true","duration_s":0}}
{"ts":"2026-02-26T10:00:03Z","component":"stop-hook","event":"session_complete","data":{"reason":"completed"}}
PERFECT_LOG

set +e; bash "$ANALYZE" "$QA_LOG" >/dev/null 2>&1; set -e
FINDINGS=$(cat "$TEST_TMPDIR/ralpha-qa-findings.md")
assert_contains "perfect health score" "100/100" "$FINDINGS"

rm -f "$TEST_TMPDIR/ralpha-qa-findings.md"

# ============================================================
# Test: Next action section present
# ============================================================

cat > "$QA_LOG" <<'NEXT_LOG'
{"ts":"2026-02-26T10:00:00Z","component":"setup","event":"session_start","data":{"mode":"solo","max_iterations":10,"team_size":1,"has_promise":"true","has_verify":"true"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"invoked","data":{"iteration":1,"max_iterations":10,"mode":"solo"}}
{"ts":"2026-02-26T10:00:01Z","component":"stop-hook","event":"decision","data":{"action":"block","system_msg":"iter 2"}}
NEXT_LOG

set +e; bash "$ANALYZE" "$QA_LOG" >/dev/null 2>&1; set -e
FINDINGS=$(cat "$TEST_TMPDIR/ralpha-qa-findings.md")
assert_contains "next action section" "Next Action" "$FINDINGS"
assert_contains "self-improvement command" "ralpha-team:solo" "$FINDINGS"

teardown_test_env
