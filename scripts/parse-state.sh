#!/bin/bash

# Shared helper: parse ralpha state file frontmatter.
# Source this file, then call ralpha_parse_field to extract values.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/../scripts/parse-state.sh"
#   ralpha_load_frontmatter
#   MY_VAR=$(ralpha_parse_field "field_name")

RALPHA_STATE_FILE=".claude/ralpha-team.local.md"
_RALPHA_FRONTMATTER=""

ralpha_load_frontmatter() {
  # Only extract lines between the FIRST two --- delimiters (n==1).
  # Any --- in the prompt body (n>=2) is ignored, preventing frontmatter contamination.
  _RALPHA_FRONTMATTER=$(awk '/^---$/{n++; next} n==1{print}' "$RALPHA_STATE_FILE")
}

# Extract a field value from frontmatter, stripping surrounding quotes.
# Requires ralpha_load_frontmatter to have been called first.
ralpha_parse_field() {
  if [[ -z "${_RALPHA_FRONTMATTER:-}" ]]; then
    echo "ERROR: ralpha_load_frontmatter must be called before ralpha_parse_field" >&2
    return 1
  fi
  local field="$1"
  echo "$_RALPHA_FRONTMATTER" | grep "^${field}:" | sed "s/${field}: *//" | sed 's/^"\(.*\)"$/\1/' | sed 's/\\"/"/g; s/\\\\/\\/g'
}

# Extract the prompt body (everything after the closing ---), trimming leading/trailing blank lines.
# IMPORTANT: n>=2 check comes BEFORE the --- pattern so that --- lines in the prompt are printed, not consumed.
# Requires ralpha_load_frontmatter to have been called first.
ralpha_parse_prompt() {
  if [[ -z "${_RALPHA_FRONTMATTER:-}" ]]; then
    echo "ERROR: ralpha_load_frontmatter must be called before ralpha_parse_prompt" >&2
    return 1
  fi
  awk 'BEGIN{n=0} n>=2{print; next} /^---$/{n++; next}' "$RALPHA_STATE_FILE" | sed '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}
