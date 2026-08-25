#!/usr/bin/env bash
# verify-artifacts.sh
# Stop hook: checks that expected learn-toolkit artifacts were generated this session.
# Reads session JSON from stdin. Exit 0 to allow stop, exit 2 to block with message.

set -euo pipefail

# Drain stdin; the payload is not needed, but leaving it unread can block the caller.
cat >/dev/null

shopt -s nullglob
STATE_FILES=(/tmp/learn-workflow-state-*.json)

# No state file: the learn workflow did not run this session.
if [[ ${#STATE_FILES[@]} -eq 0 ]]; then
  exit 0
fi

for STATE_FILE in "${STATE_FILES[@]}"; do
  TOPIC=$(jq -r '.topic // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")
  LOCAL_PATH=$(jq -r '.local_path // ""' "$STATE_FILE" 2>/dev/null || echo "")
  TOTAL_SOURCES=$(jq -r '.total_sources // 0' "$STATE_FILE" 2>/dev/null || echo "0")

  if [[ -n "$LOCAL_PATH" && ! -d "$LOCAL_PATH" ]]; then
    echo "WARNING: learn-toolkit ran for topic '$TOPIC' but local path '$LOCAL_PATH' was not created." >&2
  fi

  if [[ -n "$LOCAL_PATH" && ! -f "${LOCAL_PATH}/research-summary.md" ]]; then
    echo "WARNING: learn-toolkit ran for topic '$TOPIC' but research-summary.md was not generated." >&2
  fi

  if [[ "$TOTAL_SOURCES" -eq 0 ]]; then
    echo "WARNING: learn-toolkit state shows 0 sources for topic '$TOPIC'. The workflow may have failed silently." >&2
  fi
done

exit 0
