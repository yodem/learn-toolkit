#!/usr/bin/env bash
# verify-artifacts.sh
# Stop hook: checks that expected learn-toolkit artifacts were generated during the session.
# Reads session JSON from stdin. Exit 0 to allow stop, exit 2 to block with message.

set -euo pipefail

# Read stdin JSON (Stop hook payload)
INPUT=$(cat)

# Extract transcript or tool use history to detect if a /learn workflow ran
# Stop hooks receive the full session transcript in some runtimes.
# We use a lightweight heuristic: check if the workflow state file was written.

STATE_FILE="/tmp/learn-workflow-state.json"

# If no state file exists, the learn workflow didn't run this session — skip validation
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# State file exists — a learn workflow ran. Verify minimum artifacts.
TOPIC=$(jq -r '.topic // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")
LOCAL_PATH=$(jq -r '.local_path // ""' "$STATE_FILE" 2>/dev/null || echo "")
TOTAL_SOURCES=$(jq -r '.total_sources // 0' "$STATE_FILE" 2>/dev/null || echo "0")

# Check that local research directory exists
if [[ -n "$LOCAL_PATH" && ! -d "$LOCAL_PATH" ]]; then
  echo "WARNING: learn-toolkit ran for topic '$TOPIC' but local path '$LOCAL_PATH' was not created." >&2
  # Don't block stop — just warn
fi

# Check minimum: research-summary.md should exist
if [[ -n "$LOCAL_PATH" && ! -f "${LOCAL_PATH}/research-summary.md" ]]; then
  echo "WARNING: learn-toolkit ran for topic '$TOPIC' but research-summary.md was not generated." >&2
fi

# If sources count is 0 and state file exists, something went wrong early
if [[ "$TOTAL_SOURCES" -eq 0 ]]; then
  echo "WARNING: learn-toolkit state file shows 0 sources for topic '$TOPIC'. The workflow may have failed silently." >&2
fi

exit 0
