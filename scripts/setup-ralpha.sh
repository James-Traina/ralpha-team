#!/bin/bash

# Ralpha-Team Setup Script
# Creates state file for in-session ralpha loop (solo or team mode).
# Adapted from the official ralph-loop setup-ralph-loop.sh.

set -euo pipefail

# Parse arguments
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"
VERIFY_COMMAND="null"
MODE="team"
TEAM_SIZE=3
PERSONA="null"

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Ralpha-Team - Orchestrated iterative development with agent-teams

USAGE:
  /ralpha-team [PROMPT...] [OPTIONS]
  /ralpha-solo [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Objective description (can be multiple words without quotes)

OPTIONS:
  --mode <solo|team>             Execution mode (default: team)
  --max-iterations <n>           Max iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase signaling completion (USE QUOTES)
  --verify-command '<cmd>'       Verification command that must pass (USE QUOTES)
  --team-size <n>                Number of teammates in team mode (default: 3)
  --persona <name>               Persona for solo mode (architect|implementer|tester|reviewer|debugger)
  -h, --help                     Show this help

MODES:
  solo   Single-session ralph-loop. Good for focused tasks.
  team   Agent-team with parallel teammates. Good for complex tasks.

COMPLETION:
  The loop ends when BOTH conditions are met:
    1. Claude outputs <promise>YOUR_PHRASE</promise>
    2. The --verify-command exits with code 0 (if specified)

  Without --verify-command, the promise alone is sufficient.
  Without --completion-promise, only --max-iterations can stop the loop.

EXAMPLES:
  /ralpha-team Build a REST API --completion-promise 'DONE' --verify-command 'npm test' --max-iterations 30
  /ralpha-solo Fix the auth bug --completion-promise 'FIXED' --verify-command 'pytest' --max-iterations 15
  /ralpha-team --team-size 4 Refactor the data layer --max-iterations 25

MONITORING:
  /ralpha-status              # Check current state
  grep '^iteration:' .claude/ralpha-team.local.md  # Quick iteration check

STOPPING:
  /cancel-ralpha              # Cancel the active loop
HELP_EOF
      exit 0
      ;;
    --mode)
      if [[ -z "${2:-}" ]] || [[ "$2" != "solo" && "$2" != "team" ]]; then
        echo "Error: --mode must be 'solo' or 'team', got: '${2:-}'" >&2
        exit 1
      fi
      MODE="$2"
      shift 2
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations must be a positive integer, got: '${2:-}'" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --completion-promise requires a text argument" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    --verify-command)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --verify-command requires a command argument" >&2
        exit 1
      fi
      VERIFY_COMMAND="$2"
      shift 2
      ;;
    --team-size)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -lt 1 ]]; then
        echo "Error: --team-size must be a positive integer >= 1, got: '${2:-}'" >&2
        exit 1
      fi
      TEAM_SIZE="$2"
      shift 2
      ;;
    --persona)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --persona requires a name (architect|implementer|tester|reviewer|debugger)" >&2
        exit 1
      fi
      PERSONA="$2"
      shift 2
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

PROMPT="${PROMPT_PARTS[*]}"

if [[ -z "$PROMPT" ]]; then
  echo "Error: No prompt provided. Run with --help for usage." >&2
  exit 1
fi

# Create state directory
mkdir -p .claude

# Quote values for YAML
quote_yaml() {
  local val="$1"
  if [[ "$val" = "null" ]]; then
    echo "null"
  else
    echo "\"$val\""
  fi
}

TEAM_NAME="ralpha-$(date +%s | tail -c 7)"

cat > .claude/ralpha-team.local.md <<EOF
---
active: true
mode: $MODE
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $(quote_yaml "$COMPLETION_PROMISE")
verify_command: $(quote_yaml "$VERIFY_COMMAND")
verify_passed: false
team_name: $TEAM_NAME
team_size: $TEAM_SIZE
persona: $(quote_yaml "$PERSONA")
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# Output setup message
cat <<EOF
Ralpha-team activated!

Mode: $MODE
Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "$COMPLETION_PROMISE"; else echo "none"; fi)
Verify command: $(if [[ "$VERIFY_COMMAND" != "null" ]]; then echo "$VERIFY_COMMAND"; else echo "none"; fi)
$(if [[ "$MODE" = "team" ]]; then echo "Team size: $TEAM_SIZE"; fi)
$(if [[ "$PERSONA" != "null" ]]; then echo "Persona: $PERSONA"; fi)
Team name: $TEAM_NAME

EOF

echo "$PROMPT"

if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo ""
  echo "=== COMPLETION GATE ==="
  echo "To complete, output: <promise>$COMPLETION_PROMISE</promise>"
  if [[ "$VERIFY_COMMAND" != "null" ]]; then
    echo "AND the verification command must pass: $VERIFY_COMMAND"
    echo "Both gates must pass simultaneously."
  fi
  echo "Output the promise ONLY when the statement is genuinely TRUE."
  echo "======================="
fi
