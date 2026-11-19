# Domain: tech

## Identity

Software, infrastructure, tooling, languages, frameworks, protocols, AI/ML engineering.
Prefer this domain when the answer lives in documentation, source code, or practitioner
discussion rather than in a text tradition.

## Subagent Roster

Fixed roles, dispatched every run in the same message as the web lanes:

1. **library** — Trove (formerly CandleKeep; see `../trove-integration.md`).
2. **web** — the free open search on the self-hosted web-research server (SearXNG):
   `batch_web_search` with categories `it` and `general` (one batch call), `batch_crawl_urls`
   for the keepers, and the lookups `package_info`, `github_repo`, `api_docs`, `get_changelog`
   (plus `compare_tech` when the subject names two or more technologies).
   It always runs when `HAS_WEB_RESEARCH`, on every run, and does not count toward `$WEB_LANES`; see
   `../web-research.md`.

Web lanes (default 2). Fill the lanes from the backends that are available, in the order below, one subagent per
backend; take the first `$WEB_LANES` (see SKILL.md Phase 0.5). A query intent whose
backend is not chosen moves to the first chosen lane, so a single lane still covers the
first two intents in order.

1. **tavily** — official documentation and specifications, then community discussion with
   `--include-domains reddit.com,news.ycombinator.com,stackoverflow.com --time-range year`.
2. **exa** — code examples with `web_search_exa`, `web_search_advanced_exa` with
   `includeDomains: ["github.com"]` and a query describing the ideal repository or README,
   and `category: "personal site"` for practitioner write-ups.
3. **firecrawl** — keyless Firecrawl `firecrawl_search` (at most 2 queries) plus
   `firecrawl_scrape` for up to 3 of its own results, favouring JS-heavy pages and public
   PDFs; see `../firecrawl.md`.

## Source Ranking

official docs > source code / repos > library (Trove) > practitioner discussion > tutorials > blog posts

## Query Patterns

Tavily — one focused query per assigned intent (docs, community, and any intent moved to
this lane), recency via parameter, never via query text:

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
