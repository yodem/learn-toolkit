#!/usr/bin/env bash
# validate-output.sh
# PostToolUse hook: validates files written by learn-toolkit have correct structure.
# Reads tool use JSON from stdin. Exit 0 to allow, exit 2 to block with message.

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || true)

RESEARCH_ROOT="$HOME/dev/learn-research"

# Only validate learn-toolkit outputs: research files, or a topic-scoped state file.
case "$FILE_PATH" in
  "$RESEARCH_ROOT"/learn-*) ;;
  /tmp/learn-workflow-state-*.json) ;;
  *) exit 0 ;;
esac

# Validate README.md has a top-level heading
if [[ "$FILE_PATH" == */README.md ]]; then
  if ! grep -q "^#" "$FILE_PATH" 2>/dev/null; then
    echo "ERROR: $FILE_PATH is missing a top-level heading" >&2
    exit 2
  fi
fi

# Validate research-summary.md length. A 500-word synthesis is ~3000 chars;
# warn below 2500 rather than the old 500, which passed near-empty files.
if [[ "$FILE_PATH" == */research-summary.md ]]; then
  CHAR_COUNT=$(wc -c < "$FILE_PATH" 2>/dev/null || echo 0)
  if [[ "$CHAR_COUNT" -lt 2500 ]]; then
    echo "WARNING: $FILE_PATH looks too short (${CHAR_COUNT} chars) — expected ~3000 for a 500-word summary" >&2
  fi
fi

# Validate topic-scoped workflow state JSON
if [[ "$FILE_PATH" == /tmp/learn-workflow-state-*.json ]]; then
  if ! jq empty "$FILE_PATH" 2>/dev/null; then
    echo "ERROR: $FILE_PATH is not valid JSON" >&2
    exit 2
  fi
  for KEY in topic domain notebooks total_sources local_path; do
    if ! jq -e "has(\"$KEY\")" "$FILE_PATH" >/dev/null 2>&1; then
      echo "ERROR: $FILE_PATH is missing required key: $KEY" >&2
      exit 2
    fi
  done
fi

exit 0
