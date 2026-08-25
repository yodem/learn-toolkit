#!/usr/bin/env bash
# verify-artifacts.sh
# Stop hook: checks that expected learn-toolkit artifacts were generated recently, and
# reaps stale state files. Reads session JSON from stdin. Exit 0 to allow stop, exit 2
# to block with message.
#
# SKILL.md never deletes its own state file — `rm` is deliberately not in the skill's
# allowed-tools, so cleanup happens here instead. To avoid resurrecting warnings for
# topics from long-past sessions, only state files modified within the last 12 hours are
# reported on; anything older is treated as stale, ignored for reporting, and then
# deleted by this hook so it never lingers indefinitely. Report first, reap second: a
# file inside the 12-hour window is never deleted, since an in-flight workflow spans
# turns and this Stop hook fires every turn.

set -euo pipefail

# Drain stdin; the payload is not needed, but leaving it unread can block the caller.
cat >/dev/null

# Only consider state files touched in the last 12 hours (720 minutes). `find` prints
# nothing when there are no matches, which the read loop below handles fine (empty
# array). Avoid `mapfile` for portability with bash 3.2 (macOS system bash). The
# trailing slash on /tmp/ matters: on macOS, /tmp is a symlink to /private/tmp, and BSD
# find's -maxdepth 1 silently returns nothing for a symlinked start path without it.
STATE_FILES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && STATE_FILES+=("$line")
done < <(find /tmp/ -maxdepth 1 -name 'learn-workflow-state-*.json' -mmin -720 2>/dev/null)

# Guard on count rather than an early `exit`, so the reap step below still runs even
# when there are no fresh state files to report on. (Iterating "${STATE_FILES[@]}"
# directly when the array is empty throws "unbound variable" under bash 3.2's set -u.)
if [[ ${#STATE_FILES[@]} -gt 0 ]]; then
  for STATE_FILE in "${STATE_FILES[@]}"; do
    [[ -f "$STATE_FILE" ]] || continue

    TOPIC=$(jq -r '.topic // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")
    LOCAL_PATH=$(jq -r '.local_path // ""' "$STATE_FILE" 2>/dev/null || echo "")
    TOTAL_SOURCES=$(jq -r '.total_sources // 0' "$STATE_FILE" 2>/dev/null || echo "0")

    # TOTAL_SOURCES may be non-numeric or empty if the state file was written badly;
    # never let an arithmetic/comparison error escape this Stop hook and block the user.
    if ! [[ "$TOTAL_SOURCES" =~ ^[0-9]+$ ]]; then
      TOTAL_SOURCES=0
    fi

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
fi

# Reap stale state files (older than 12 hours / 720 minutes) now that fresh ones have
# been reported on above. Never touch anything inside the 12-hour window.
find /tmp/ -maxdepth 1 -name 'learn-workflow-state-*.json' -mmin +720 -delete 2>/dev/null || true

exit 0
