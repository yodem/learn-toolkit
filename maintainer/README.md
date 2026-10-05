# Maintainer tooling (not part of the plugin)

The marketplace installs only `plugins/learn-toolkit/`, so nothing in this folder reaches
plugin users.

## Drift checker

`python3 maintainer/check-backends.py` compares the plugin with the live Exa and Tavily
MCP tool lists, Exa's own tool registry (deprecations parsed from
`exa-mcp-server/src/toolRegistry.ts`), published package versions and both
`llms.txt` documentation indexes, against `maintainer/backend-snapshot.json`. It is
stdlib-only and never reads an API key.

- `--offline` runs only the static checks (`lint-skill.sh`, snapshot sanity).
- `--update-snapshot` accepts the current live versions, tools and documentation links.
- `--json` prints `{status, findings, snapshot}`.

Exit codes: `0` clean, `1` breaking drift, `2` informational drift, `3` a probe could not run.

Tests: `python3 -m unittest discover -s maintainer/tests`.

The weekly job that runs this checker and opens a draft PR on drift lives only on the
maintainer's machine; it is deliberately not in this repository.
