#!/usr/bin/env bash
# verify.sh: the gate CI runs first (CI then runs test-integrity.sh on pull requests). Lint, compile, tests, manifests. Stops at the first failure.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

step() { printf '\n== %s ==\n' "$1"; }

step "lint (ruff)"
if ruff --version >/dev/null 2>&1; then RUFF=(ruff); elif python3 -m ruff --version >/dev/null 2>&1; then RUFF=(python3 -m ruff); else echo "ruff not installed (pip install ruff)"; exit 1; fi
"${RUFF[@]}" check --select E9,F63,F7,F82 maintainer infra plugins  # syntax errors + pyflakes F63/F7/F82
bash plugins/learn-toolkit/scripts/lint-skill.sh

step "type check (no typed code; syntax compile)"
PYTHONDONTWRITEBYTECODE=1 python3 -m compileall -q maintainer infra plugins

step "tests"
python3 -m unittest discover -s maintainer/tests

step "build (plugin manifests)"
python3 - <<'PY'
import json
for p in ("plugins/learn-toolkit/.claude-plugin/plugin.json", "plugins/learn-toolkit/hooks/hooks.json", ".claude-plugin/marketplace.json"):
    print("checking", p)
    with open(p) as f: d = json.load(f)
    assert isinstance(d, dict) and d, p + " must be a non-empty object"
    print("ok", p)
PY

echo; echo "verify: OK"
