# Domain: tech

## Identity

Software, infrastructure, tooling, languages, frameworks, protocols, AI/ML engineering.
Prefer this domain when the answer lives in documentation, source code, or practitioner
discussion rather than in a text tradition.

## Subagent Roster

Four subagents, dispatched in one message:

1. **docs** — Tavily, official documentation and specifications.
2. **code** — Exa `get_code_context_exa`, plus `web_search_advanced_exa` with `category: "github"`.
3. **community** — Tavily with `include_domains: ["reddit.com","news.ycombinator.com","stackoverflow.com"]`,
   plus Exa `web_search_advanced_exa` with `category: "personal site"`, plus `linkedin_search_exa`
   for practitioners writing about the subject.
4. **library** — CandleKeep (see `../candlekeep-integration.md`).

## Source Ranking

official docs > source code / repos > library (CandleKeep) > practitioner discussion > tutorials > blog posts

## Query Patterns

Tavily — one focused query per subagent, recency via parameter, never via query text:

```bash
tvly search "<subject> official documentation" --depth advanced --max-results 6 --json
tvly search "<subject> production issues" --time-range year --include-domains reddit.com,news.ycombinator.com --max-results 6 --json
```

Exa — describe the ideal page, never keywords:

- GOOD: `"in-depth blog post explaining how <subject> works in production, with tradeoffs"`
- BAD: `"<subject> production tradeoffs"`
- GOOD: `"official reference documentation for <subject> configuration options"`
- BAD: `"<subject> documentation"`

## Output Settings

- Language: `en`
- Playground (Phase 6b): **yes**
- NotebookLM artifact focus: implementation-oriented — code examples, pitfalls, action items.
