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
  _RALPHA_FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPHA_STATE_FILE")
}

# Extract a field value from frontmatter, stripping surrounding quotes.
ralpha_parse_field() {
  local field="$1"
  echo "$_RALPHA_FRONTMATTER" | grep "^${field}:" | sed "s/${field}: *//" | sed 's/^"\(.*\)"$/\1/'
}

# Extract the prompt body (everything after the closing ---), trimming leading/trailing blank lines.
ralpha_parse_prompt() {
  awk '/^---$/{i++; next} i>=2' "$RALPHA_STATE_FILE" | sed '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}
