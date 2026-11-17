# Working in this repo (all coding agents)

This repo is a Claude Code plugin marketplace with one plugin, `plugins/learn-toolkit/`.
Install guidance for end users lives in `CLAUDE.md` and `plugins/learn-toolkit/references/setup-guide.md`.

## Checks (run before you call a change done)

- `bash plugins/learn-toolkit/scripts/lint-skill.sh` — 13 static checks on the skill, its references and `.mcp.json`. Required after any change under `plugins/learn-toolkit/`.
- `python3 -m unittest discover -s maintainer/tests` — maintainer tests. CI (`.github/workflows/ci.yml`) runs them on every PR and push to `main`; the Claude Code Stop hook in `.claude/` runs them when the tree is dirty.
- `claude plugin validate plugins/learn-toolkit` — manifest, hooks and MCP config.
- `python3 maintainer/check-backends.py --offline` — static drift checks; drop `--offline` to compare against live Exa/Tavily.

## Rules

- A release bumps the version in both `plugins/learn-toolkit/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, plus the version mentioned in the READMEs and setup guide.
- Never put API keys or tokens in files, examples or chat; keys come from plugin `userConfig` (keychain).
- Name MCP tools without a hardcoded `mcp__…` prefix in the skill; discover them with `ToolSearch` (the lint enforces it).
- `maintainer/`, `infra/` and `docs/` are not shipped to plugin users; only `plugins/learn-toolkit/` is.
- Backend drift PRs (`backend-drift/YYYY-MM-DD`) come from a weekly job on the maintainer's machine; a newer one supersedes older open ones.
