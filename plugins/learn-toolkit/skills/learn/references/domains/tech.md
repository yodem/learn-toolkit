# Domain: tech

## Identity

Software, infrastructure, tooling, languages, frameworks, protocols, AI/ML engineering.
Prefer this domain when the answer lives in documentation, source code, or practitioner
discussion rather than in a text tradition.

## Subagent Roster

Four subagents, dispatched in one message:

1. **docs** — Tavily, official documentation and specifications.
2. **code** — Exa `web_search_exa` for code examples and `web_search_advanced_exa` with
   `includeDomains: ["github.com"]` and a query describing the ideal repository or README.
3. **community** — Tavily with `--include-domains reddit.com,news.ycombinator.com,stackoverflow.com
   --time-range year`, plus Exa `web_search_advanced_exa` with `category: "personal site"` for
   practitioner write-ups.
4. **library** — Trove (formerly CandleKeep; see `../trove-integration.md`).

Optional extra roles, dispatched in the same message only when `HAS_WEB_RESEARCH`:

- **web** — web-research `batch_web_search` with categories `it` and `general` (one batch
  call), plus `batch_crawl_urls` for the keepers; see `../web-research.md`.
- **packages** — web-research `package_info`, `github_repo`, `api_docs`, `get_changelog`,
  and `compare_tech` when the subject names two or more technologies.

## Source Ranking

official docs > source code / repos > library (Trove) > practitioner discussion > tutorials > blog posts

## Query Patterns

Tavily — one focused query per subagent, recency via parameter, never via query text:

`$OUT` is the subagent's own `mktemp -d` directory (see SKILL.md Phase 1); paste its
literal path.

```bash
tvly search "<subject> official documentation" --depth advanced --chunks-per-source 3 --max-results 6 --json -o "$OUT/docs.json"
tvly search "<subject> production issues" --depth advanced --chunks-per-source 3 --time-range year --include-domains reddit.com,news.ycombinator.com --max-results 6 --json -o "$OUT/community.json"
```

Exa — describe the ideal page, never keywords:

- GOOD: `"in-depth blog post explaining how <subject> works in production, with tradeoffs"`
- BAD: `"<subject> production tradeoffs"`
- GOOD: `"official reference documentation for <subject> configuration options"`
- BAD: `"<subject> documentation"`
- GOOD: `"well-maintained GitHub repository with a README showing a minimal <subject> example"`
- BAD: `"<subject> github"`

Fetching GitHub files: `web_fetch_exa` returns an empty page shell for blob URLs. Rewrite
`https://github.com/<o>/<r>/blob/<ref>/<path>` to
`https://raw.githubusercontent.com/<o>/<r>/<ref>/<path>` before fetching.

## Output Settings

- Language: `en`
- Learning ladder (Phase 2 synthesis and Phase 6b page): **Basics** — what it is, the
  problem it solves, the core concepts and a minimal working example; **Advanced usage** —
  real-world patterns, configuration, tradeoffs and pitfalls; **Related research** —
  official docs, source repos and practitioner discussion.
- NotebookLM artifact focus: implementation-oriented — code examples, pitfalls, action items.
