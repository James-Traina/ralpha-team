#!/usr/bin/env bash

# 10-dimension quality evaluator for ralpha-team.
# Runs 39 automated checks and produces a 1-5 scorecard per dimension.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$REPO_ROOT/.claude/ralpha-eval.md"
SELF="$(basename "${BASH_SOURCE[0]}")"
[[ -n "$SELF" ]] || SELF="eval-dimensions.sh"

# --- Scoring state ---
TOTAL_PASS=0 TOTAL_CHECKS=0 DIM_BELOW_5=0 SCORE_SUM=0 SCORE_COUNT=0
DIMENSION_LINES="" FAILURE_LINES=""
STRONGEST="" WEAKEST="" STRONGEST_SCORE=0 WEAKEST_SCORE=6
DIM_NAME="" DIM_NUM=0 DIM_PASS=0 DIM_TOTAL=0 DIM_FAILURES=""
SELECTED=("$@")

should_run() {
  if [[ ${#SELECTED[@]} -eq 0 ]]; then return 0; fi
  for s in "${SELECTED[@]}"; do [[ "$s" = "$1" ]] && return 0; done; return 1
}
begin_dim() { DIM_NUM="$1"; DIM_NAME="$2"; DIM_PASS=0; DIM_TOTAL=0; DIM_FAILURES=""; }
run_check() {
  local label="$1" fn="$2"; DIM_TOTAL=$((DIM_TOTAL + 1))
  if "$fn" >/dev/null 2>&1; then DIM_PASS=$((DIM_PASS + 1))
  else DIM_FAILURES="${DIM_FAILURES}- FAIL: ${label}\n"; fi
}
end_dim() {
  local score; if [[ $DIM_TOTAL -eq 0 ]]; then score=1
  elif [[ $DIM_PASS -eq $DIM_TOTAL ]]; then score=5
  else score=$((1 + (4 * DIM_PASS / DIM_TOTAL))); fi
  TOTAL_PASS=$((TOTAL_PASS + DIM_PASS)); TOTAL_CHECKS=$((TOTAL_CHECKS + DIM_TOTAL))
  local status=""; if [[ $score -eq 5 ]]; then status="PASS"; else DIM_BELOW_5=$((DIM_BELOW_5 + 1)); fi
  DIMENSION_LINES="${DIMENSION_LINES}| ${DIM_NUM} | $(printf '%-14s' "$DIM_NAME") |   ${score}/5 |  ${DIM_PASS}/${DIM_TOTAL}  | ${status} |\n"
  [[ -n "$DIM_FAILURES" ]] && FAILURE_LINES="${FAILURE_LINES}### D$(printf '%02d' "$DIM_NUM") ${DIM_NAME} (${score}/5)\n${DIM_FAILURES}\n"
  if [[ $score -gt $STRONGEST_SCORE ]]; then STRONGEST_SCORE=$score; STRONGEST="$DIM_NAME ($score)"
  elif [[ $score -eq $STRONGEST_SCORE && -n "$STRONGEST" ]]; then STRONGEST="$STRONGEST, $DIM_NAME ($score)"; fi
  if [[ $score -lt $WEAKEST_SCORE ]]; then WEAKEST_SCORE=$score; WEAKEST="$DIM_NAME ($score)"
  elif [[ $score -eq $WEAKEST_SCORE && -n "$WEAKEST" ]]; then WEAKEST="$WEAKEST, $DIM_NAME ($score)"; fi
  SCORE_SUM=$((SCORE_SUM + score)); SCORE_COUNT=$((SCORE_COUNT + 1))
  printf "  D%02d %-14s %d/5  (%d/%d)\n" "$DIM_NUM" "$DIM_NAME" "$score" "$DIM_PASS" "$DIM_TOTAL"
}

# --- D01 Robust (5 checks) ---
_d01_c1() { # set -euo pipefail in standalone scripts (skip sourced libraries without shebang)
  for f in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/hooks/*.sh; do
    [[ -f "$f" ]] || continue; head -1 "$f" | grep -q '^#!' || continue
    head -7 "$f" | grep -q "set -euo pipefail" || return 1
  done
}
_d01_c2() { # Frontmatter scoping: n==1 or n>=2 awk pattern >= 4 times
  local c=0; c=$((c + $(grep -c 'n==1\|n>=2' "$REPO_ROOT/scripts/parse-state.sh")))
  c=$((c + $(grep -c 'n==1\|n>=2' "$REPO_ROOT/hooks/stop-hook.sh"))); [[ $c -ge 4 ]]
}
_d01_c3() { grep -qF '^[0-9]+$' "$REPO_ROOT/hooks/stop-hook.sh"; }
_d01_c4() { grep -q "abort_with_warning()" "$REPO_ROOT/hooks/stop-hook.sh"; }
_d01_c5() { [[ $(grep -c "assert_" "$REPO_ROOT/.tests/test-edge-cases.sh") -ge 8 ]]; }
dim_01() {
  begin_dim 1 "Robust"
  run_check "set -euo pipefail in standalone scripts" _d01_c1
  run_check "frontmatter scoping pattern >= 4" _d01_c2
  run_check "numeric validation in stop-hook" _d01_c3
  run_check "abort_with_warning function exists" _d01_c4
  run_check "edge case tests have 8+ assertions" _d01_c5
  end_dim
}

# --- D02 Genuine (4 checks) ---
_d02_c1() { grep -q "<promise>" "$REPO_ROOT/hooks/stop-hook.sh" && grep -q "perl" "$REPO_ROOT/hooks/stop-hook.sh"; }
_d02_c2() { awk '/PROMISE_DETECTED.*=.*true/{f=1} f && /verify-completion/{ok=1} END{exit !ok}' "$REPO_ROOT/hooks/stop-hook.sh"; }
_d02_c3() {
  local c; c=$(awk '/PROMISE_DETECTED.*=.*true/{b=1} b && /complete_session.*completed/{c++} /^fi$/ && b{b=0} END{print c+0}' "$REPO_ROOT/hooks/stop-hook.sh")
  [[ $c -ge 2 ]]
}
_d02_c4() { grep -qi "false\|genuinely" "$REPO_ROOT/commands/team.md" && grep -qi "false\|genuinely" "$REPO_ROOT/commands/solo.md"; }
dim_02() {
  begin_dim 2 "Genuine"
  run_check "promise uses <promise> tag + perl" _d02_c1
  run_check "verify inside PROMISE_DETECTED block" _d02_c2
  run_check "complete_session guarded by promise" _d02_c3
  run_check "command files warn against false promises" _d02_c4
  end_dim
}

# --- D03 Minimal (4 checks) ---
_d03_c1() { # No source file exceeds 350 lines (exclude evaluator itself)
  for dir in scripts hooks commands agents; do
    for f in "$REPO_ROOT/$dir"/*; do [[ -f "$f" ]] || continue
      [[ "$(basename "$f")" = "$SELF" ]] && continue
      [[ $(wc -l < "$f" | tr -d ' ') -le 350 ]] || return 1
    done; done
}
_d03_c2() { # Every export -f function is used by at least one test file
  local funcs; funcs=$(grep "export -f" "$REPO_ROOT/.tests/test-runner.sh" | sed 's/export -f //' | tr ' ' '\n')
  for func in $funcs; do [[ "$func" = "_bump" ]] && continue
    grep -rq "$func" "$REPO_ROOT"/.tests/test-*.sh || return 1; done
}
_d03_c3() { # No 3+ consecutive commented-out code lines
  for f in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/hooks/*.sh; do [[ -f "$f" ]] || continue
    awk '/^[[:space:]]*# *(if |for |while |echo |local |set )/{n++; if(n>=3) exit 1; next} {n=0}' "$f" || return 1
  done
}
_d03_c4() { # Flat directory structure
  local d; d=$(find "$REPO_ROOT" -mindepth 3 -type f -not -path '*/.git/*' -not -path '*/.github/*' \
    -not -path '*/.claude/*' -not -path '*/.serena/*' -not -path '*/.claude-plugin/*' \
    -not -path '*/node_modules/*' -print 2>/dev/null | head -1 || true)
  [[ -z "$d" ]]
}
dim_03() {
  begin_dim 3 "Minimal"
  run_check "no source file exceeds 350 lines" _d03_c1
  run_check "no unused exported fixtures" _d03_c2
  run_check "no commented-out code blocks" _d03_c3
  run_check "flat directory structure" _d03_c4
  end_dim
}

# --- D04 Autonomous (4 checks) ---
_d04_c1() { grep -q "block_and_continue" "$REPO_ROOT/hooks/stop-hook.sh"; }
_d04_c2() { grep -q 'rm -f.*RALPHA_STATE_FILE' "$REPO_ROOT/hooks/stop-hook.sh"; }
_d04_c3() { grep -q "exit 2" "$REPO_ROOT/hooks/teammate-idle-hook.sh" && grep -q "TaskList" "$REPO_ROOT/hooks/teammate-idle-hook.sh"; }
_d04_c4() { grep -q "command -v" "$REPO_ROOT/scripts/setup-ralpha.sh" && grep -q "AGENT_TEAMS" "$REPO_ROOT/scripts/setup-ralpha.sh"; }
dim_04() {
  begin_dim 4 "Autonomous"
  run_check "stop hook loops via block_and_continue" _d04_c1
  run_check "stop hook cleans up state file" _d04_c2
  run_check "idle hook auto-nudges teammates" _d04_c3
  run_check "SessionStart validates env" _d04_c4
  end_dim
}

# --- D05 Adversarial (4 checks) ---
_d05_c1() { # Tests use create_state fixture (structured adversarial setup, not just ad-hoc strings)
  grep -q "create_state" "$REPO_ROOT/.tests/test-edge-cases.sh"; }
_d05_c2() { grep -q "iteration:" "$REPO_ROOT/.tests/test-edge-cases.sh" || grep -qF -- "---" "$REPO_ROOT/.tests/test-edge-cases.sh"; }
_d05_c3() { [[ $(grep -c "abort_with_warning" "$REPO_ROOT/hooks/stop-hook.sh") -ge 4 ]]; }
_d05_c4() { grep -qiE "quote|whitespace|case" "$REPO_ROOT/.tests/test-edge-cases.sh"; }
dim_05() {
  begin_dim 5 "Adversarial"
  run_check "edge cases use create_state fixture" _d05_c1
  run_check "tests exercise frontmatter injection" _d05_c2
  run_check "3+ abort paths in stop-hook" _d05_c3
  run_check "tests cover quote/whitespace cases" _d05_c4
  end_dim
}

# --- D06 Rigorous (4 checks) ---
_d06_c1() { [[ -f "$REPO_ROOT/.tests/test-self-verification.sh" ]] && grep -q "README" "$REPO_ROOT/.tests/test-self-verification.sh" && grep -q "count" "$REPO_ROOT/.tests/test-self-verification.sh"; }
_d06_c2() { grep -q "matcher" "$REPO_ROOT/.tests/test-self-verification.sh" && grep -q "timeout" "$REPO_ROOT/.tests/test-self-verification.sh"; }
_d06_c3() { grep -qi "promise" "$REPO_ROOT/.tests/test-e2e-solo.sh" && grep -qi "verif" "$REPO_ROOT/.tests/test-e2e-solo.sh" && grep -qi "promise" "$REPO_ROOT/.tests/test-e2e-team.sh" && grep -qi "verif" "$REPO_ROOT/.tests/test-e2e-team.sh"; }
_d06_c4() { # Every script in scripts/ is referenced by at least one test file
  for f in "$REPO_ROOT"/scripts/*.sh; do [[ -f "$f" ]] || continue
    grep -rq "$(basename "$f")" "$REPO_ROOT/.tests/" || return 1; done
}
dim_06() {
  begin_dim 6 "Rigorous"
  run_check "self-verification tests exist" _d06_c1
  run_check "tests validate hooks.json structure" _d06_c2
  run_check "E2E tests cover promise+verify" _d06_c3
  run_check "all scripts referenced by tests" _d06_c4
  end_dim
}

# --- D07 Deterministic (3 checks) ---
_d07_c1() { # No sleep, $RANDOM, $SRANDOM, date +%N (exclude evaluator itself)
  for f in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/hooks/*.sh; do [[ -f "$f" ]] || continue
    [[ "$(basename "$f")" = "$SELF" ]] && continue
    grep -qE '(sleep |[$]RANDOM|[$]SRANDOM|date [+]%N)' "$f" && return 1; done; return 0
}
_d07_c2() { # Test fixtures contain no RANDOM
  local t; t=$(sed -n '/^create_state\b/,/^}/p; /^create_transcript\b/,/^}/p' "$REPO_ROOT/.tests/test-runner.sh")
  echo "$t" | grep -qE 'RANDOM|SRANDOM' && return 1; return 0
}
_d07_c3() { grep -q "tr.*upper.*lower" "$REPO_ROOT/hooks/stop-hook.sh"; }
dim_07() {
  begin_dim 7 "Deterministic"
  run_check "no nondeterminism in scripts/hooks" _d07_c1
  run_check "test fixtures are deterministic" _d07_c2
  run_check "promise matching is case-insensitive" _d07_c3
  end_dim
}

# --- D08 Reproducible (4 checks) ---
_d08_c1() { # No hardcoded /Users/ or /home/ (exclude evaluator itself)
  local found; found=$(grep -rnE '/Users/|/home/' "$REPO_ROOT/scripts" "$REPO_ROOT/hooks" \
    "$REPO_ROOT/commands" "$REPO_ROOT/agents" "$REPO_ROOT/CLAUDE.md" "$REPO_ROOT/.claude-plugin" 2>/dev/null \
    | grep -v "$SELF" || true)
  [[ -z "$found" ]]
}
_d08_c2() { grep -q "command -v jq" "$REPO_ROOT/scripts/setup-ralpha.sh" && grep -q "perl" "$REPO_ROOT/scripts/setup-ralpha.sh"; }
_d08_c3() { for f in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/hooks/*.sh "$REPO_ROOT"/.tests/*.sh; do [[ -f "$f" ]] || continue
    grep -q '\[\[' "$f" && ! head -1 "$f" | grep -qE '#!/(usr/bin/env bash|bin/bash)' && return 1; done; return 0
}
_d08_c4() { grep -qE 'BASH_SOURCE|SCRIPT_DIR|CLAUDE_PLUGIN_ROOT' "$REPO_ROOT/scripts/parse-state.sh" && \
  grep -qE 'BASH_SOURCE|SCRIPT_DIR|CLAUDE_PLUGIN_ROOT' "$REPO_ROOT/hooks/stop-hook.sh" && \
  grep -qE 'BASH_SOURCE|SCRIPT_DIR|CLAUDE_PLUGIN_ROOT' "$REPO_ROOT/scripts/setup-ralpha.sh"; }
dim_08() {
  begin_dim 8 "Reproducible"
  run_check "no hardcoded personal paths" _d08_c1
  run_check "dependency checks for jq and perl" _d08_c2
  run_check "bash shebang on scripts using [[ ]]" _d08_c3
  run_check "dynamic path resolution" _d08_c4
  end_dim
}

# --- D09 Literate (4 checks) ---
_d09_c1() { for f in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/hooks/*.sh; do [[ -f "$f" ]] || continue
    sed -n '3p' "$f" | grep -q '^#' || return 1; done
}
_d09_c2() { local c; c=$(grep -rcE '# WHY:|# Note:|# intentional' "$REPO_ROOT/scripts/" | awk -F: '{s+=$NF} END{print s+0}'); [[ $c -ge 2 ]]; }
_d09_c3() { grep -qi "how it works" "$REPO_ROOT/README.md" && grep -qi "dual gate" "$REPO_ROOT/README.md"; }
_d09_c4() { [[ $(grep -rl "<example>" "$REPO_ROOT/agents/" | wc -l | tr -d ' ') -ge 5 ]]; }
dim_09() {
  begin_dim 9 "Literate"
  run_check "line 3 comment in all scripts" _d09_c1
  run_check "2+ design-decision comments" _d09_c2
  run_check "README has key sections" _d09_c3
  run_check "all agents have examples" _d09_c4
  end_dim
}

# --- D10 Curated (3 checks) ---
_d10_c1() { # task-completed exits 0 always (verification belongs at Stop, not mid-build)
  grep -q "exit 0" "$REPO_ROOT/hooks/task-completed-hook.sh" && ! grep -q "exit 2" "$REPO_ROOT/hooks/task-completed-hook.sh"; }
_d10_c2() { grep -qi "## Install" "$REPO_ROOT/README.md" && grep -qi "## Three modes" "$REPO_ROOT/README.md" && grep -qi "## Troubleshooting" "$REPO_ROOT/README.md"; }
_d10_c3() { # No TODO/FIXME/HACK/XXX (exclude evaluator itself)
  local found; found=$(grep -rnE 'TODO|FIXME|HACK|XXX' "$REPO_ROOT/scripts" "$REPO_ROOT/hooks" \
    "$REPO_ROOT/commands" "$REPO_ROOT/agents" "$REPO_ROOT/CLAUDE.md" "$REPO_ROOT/.claude-plugin" 2>/dev/null \
    | grep -v "$SELF" || true)
  [[ -z "$found" ]]
}
dim_10() {
  begin_dim 10 "Curated"
  run_check "task-completed exits 0 always (no mid-build gate)" _d10_c1
  run_check "README has Install + Three modes + Troubleshooting" _d10_c2
  run_check "no TODO/FIXME/HACK/XXX in source" _d10_c3
  end_dim
}

# ================================================================
# Main
# ================================================================
DIM_COUNT=0
echo ""; echo "ralpha-team Quality Evaluation"; echo "=============================="
for i in 1 2 3 4 5 6 7 8 9 10; do
  should_run "$i" || continue; DIM_COUNT=$((DIM_COUNT + 1))
  case $i in 1) dim_01;; 2) dim_02;; 3) dim_03;; 4) dim_04;; 5) dim_05;;
    6) dim_06;; 7) dim_07;; 8) dim_08;; 9) dim_09;; 10) dim_10;; esac
done
[[ $DIM_COUNT -gt 0 ]] || { echo "No dimensions selected."; exit 1; }

OVERALL=$(awk "BEGIN{printf \"%.1f\", $SCORE_SUM / $SCORE_COUNT}")

mkdir -p "$(dirname "$OUTPUT_FILE")"
{ echo "# ralpha-team Quality Evaluation"; echo ""
  echo "**Overall: ${OVERALL} / 5.0** | Checks: ${TOTAL_PASS}/${TOTAL_CHECKS} passed | Date: $(date -u +%Y-%m-%d)"
  echo ""; echo "## Scores"; echo ""
  echo "| # | Dimension      | Score | Passed | Status |"
  echo "|---|----------------|-------|--------|--------|"
  printf '%b' "$DIMENSION_LINES"; echo ""
  [[ -n "$FAILURE_LINES" ]] && { echo "## Failing Checks"; echo ""; printf '%b' "$FAILURE_LINES"; }
  echo "## Summary"; echo ""
  echo "Strongest: $STRONGEST"; echo "Weakest: $WEAKEST"
  echo "Next: Fix failing checks, then re-run: bash scripts/eval-dimensions.sh"
} > "$OUTPUT_FILE"

echo ""; echo "Overall: ${OVERALL} / 5.0  (${TOTAL_PASS}/${TOTAL_CHECKS} checks passed)"
echo "Output: $OUTPUT_FILE"; echo ""
exit "$DIM_BELOW_5"
