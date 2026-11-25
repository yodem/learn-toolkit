#!/usr/bin/env bash
# test-integrity.sh <base-ref>: fails when the diff against the base deletes, renames away or hollows out tests
# (removed test cases/assertions not matched by the same count of new ones in test files).
# Waiver: only a maintainer-applied PR label "tests-removed" (CI passes PR_LABELS); the PR author's body or commits cannot waive.
set -euo pipefail
BASE="${1:?usage: test-integrity.sh <base-ref>}"
RANGE="$BASE...HEAD"
git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null || { echo "test-integrity: base ref '$BASE' not found" >&2; exit 2; }
G=(git -c color.ui=never -c core.quotepath=off)
TESTRE='(^|/)(tests?/|__tests__/|spec/|test_[^/]*|tests?\.py$|[^/]*_(test|spec)\.[a-z]+$|[^/]*\.(test|spec)\.[a-z]+$)'
PAT='^[-+][[:space:]]*(async[[:space:]]+)?(def test_|it(\.[a-z]+)?\(|test(\.[a-z]+)?\(|self\.assert|assert[[:space:](]|expect\()'

status=$("${G[@]}" diff --name-status -M "$RANGE")   # a git failure aborts here (set -e)
bad=0
waived=0
if printf '%s' "${PR_LABELS:-}" | tr ',' '\n' | grep -qxF 'tests-removed'; then waived=1; fi

testfiles=()
while IFS=$'\t' read -r st a b; do
  [ -n "${st:-}" ] || continue
  case "$st" in
    D) if printf '%s\n' "$a" | grep -qiE "$TESTRE"; then echo "test-integrity: test file deleted: $a"; bad=1; fi ;;
    R*) if printf '%s\n' "$a" | grep -qiE "$TESTRE" && ! printf '%s\n' "$b" | grep -qiE "$TESTRE"; then echo "test-integrity: test file renamed out of test paths: $a -> $b"; bad=1; fi
        if printf '%s\n' "$b" | grep -qiE "$TESTRE"; then testfiles+=("$b"); fi ;;
    M) if printf '%s\n' "$a" | grep -qiE "$TESTRE"; then testfiles+=("$a"); fi ;;
  esac
done <<<"$status"

if [ "${#testfiles[@]}" -gt 0 ]; then
  patch=$("${G[@]}" diff --text -U0 -M "$RANGE" -- "${testfiles[@]}")
  removed=$(printf '%s\n' "$patch" | grep -E '^-' | grep -vE '^---' | grep -cE "${PAT#^[-+]}" || true)
  added=$(printf '%s\n' "$patch" | grep -E '^\+' | grep -vE '^\+\+\+' | grep -cE "${PAT#^[-+]}" || true)
  if [ "$added" -lt "$removed" ]; then echo "test-integrity: $removed test/assert lines removed in test files, only $added added"; bad=1; fi
fi
if "${G[@]}" diff --name-only "$RANGE" | grep -qx '.gitattributes'; then echo "test-integrity: .gitattributes changed, review that test files still diff as text"; bad=1; fi

if [ "$bad" != 0 ] && [ "$waived" = 1 ]; then echo "test-integrity: findings waived by the maintainer label tests-removed"; exit 0; fi
[ "$bad" = 0 ] && echo "test-integrity: OK"
exit "$bad"
