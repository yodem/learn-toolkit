#!/usr/bin/env bash
# test-integrity.sh [base-ref]: fails when the diff against the base deletes test files or removes test
# cases/assertions, unless the PR body (PR_BODY env) or a commit message in the range says "tests-removed: <reason>".
set -euo pipefail
BASE="${1:-origin/main}"
RANGE="$BASE...HEAD"
if printf '%s\n%s' "${PR_BODY:-}" "$(git log --format=%B "$RANGE")" | grep -qiE '^tests-removed: *[^ ]'; then
  echo "test-integrity: override found (tests-removed), skipping"; exit 0
fi
bad=0
deleted=$(git diff --diff-filter=D --name-only "$RANGE" | grep -iE '(^|/)(tests?/|test_[^/]*|[^/]*_test\.[a-z]+|[^/]*\.(test|spec)\.[a-z]+)' || true)
if [ -n "$deleted" ]; then echo "test-integrity: test files deleted:"; echo "$deleted"; bad=1; fi
removed=$(git diff -U0 --diff-filter=M "$RANGE" -- $(git diff --name-only --diff-filter=M "$RANGE" | grep -iE '(^|/)(tests?/|test_[^/]*|[^/]*_test\.[a-z]+|[^/]*\.(test|spec)\.[a-z]+)' || echo /dev/null) 2>/dev/null \
  | grep -E '^-[[:space:]]*(def test_|it\(|test\(|assert|self\.assert|expect\()' || true)
if [ -n "$removed" ]; then
  added=$(git diff -U0 "$RANGE" | grep -cE '^\+[[:space:]]*(def test_|it\(|test\(|assert|self\.assert|expect\()' || true)
  nrem=$(printf '%s\n' "$removed" | wc -l | tr -d ' ')
  if [ "$added" -lt "$nrem" ]; then echo "test-integrity: $nrem test/assert lines removed, only $added added:"; echo "$removed"; bad=1; fi
fi
[ "$bad" = 0 ] && echo "test-integrity: OK"
exit "$bad"
