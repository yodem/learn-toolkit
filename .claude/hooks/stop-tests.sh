#!/usr/bin/env bash
# Stop gate: when the working tree has changes, run this repo's fast checks before Claude finishes.
# Exit 2 + stderr sends Claude back to fix; stop_hook_active lets it through on the second try (no loop).
input=$(cat)
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0
[ -z "$(git status --porcelain)" ] && exit 0
TEST_CMD='python3 -m unittest discover -s maintainer/tests'
out=$(bash -c "$TEST_CMD" 2>&1); rc=$?
[ "$rc" -eq 0 ] && exit 0
{ printf 'Stop gate: `%s` failed (exit %s). Fix it before finishing.\n' "$TEST_CMD" "$rc"; printf '%s\n' "$out" | tail -40; } >&2
exit 2
