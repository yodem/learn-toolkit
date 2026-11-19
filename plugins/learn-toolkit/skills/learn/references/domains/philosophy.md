# Domain: philosophy

## Identity

Philosophical concepts, arguments, thinkers, and traditions — analytic or continental,
ancient or modern. Prefer this domain when the answer lives in argument and secondary
literature rather than in documentation or in a religious text tradition.

## Subagent Roster

Fixed roles, dispatched every run in the same message as the web lanes:

1. **library** — Trove (formerly CandleKeep), prioritising per-author humanities books
   (see `../trove-integration.md`).
2. **web** — the free open search on the self-hosted web-research server (SearXNG):
   `batch_web_search` (one batch call), plus `batch_crawl_urls` for the keepers.
   It always runs when `HAS_WEB_RESEARCH`, on every run, and does not count toward `$WEB_LANES`; see
   `../web-research.md`.

Web lanes (default 2). Fill the lanes from the backends that are available, in the order below, one subagent per
backend; take the first `$WEB_LANES` (see SKILL.md Phase 0.5). A query intent whose
backend is not chosen moves to the first chosen lane, so a single lane still covers the
first two intents in order.

1. **exa** — literature: `web_search_advanced_exa` with `category: "publication"` for papers,
   plus `category: "personal site"` for essays. Exa's personal-site index is its documented
   strength; use it rather than domain-filtered Tavily here.
2. **tavily** — overview: encyclopedic and orienting material (SEP, IEP, university course
   pages).
3. **firecrawl** — keyless Firecrawl `firecrawl_search` (at most 2 queries) plus
   `firecrawl_scrape` for up to 3 of its own results, favouring JS-heavy pages and public
   PDFs; see `../firecrawl.md`.

## Source Ranking

primary texts > peer-reviewed literature > library (Trove) > encyclopedic overviews (SEP/IEP) > essays > blog posts

## Query Patterns

Exa — describe the ideal page:

- GOOD: `"scholarly article analysing <thinker>'s argument about <concept> and its critics"`
- BAD: `"<thinker> <concept> criticism"`
- GOOD: `"clear introductory essay explaining the <concept> debate for a graduate reader"`
- BAD: `"<concept> introduction"`

Tavily:

`$OUT` is the subagent's own `mktemp -d` directory (see SKILL.md Phase 1); paste its
literal path.

```bash
tvly search "<subject> Stanford Encyclopedia of Philosophy overview" --depth advanced --chunks-per-source 3 --max-results 6 --json -o "$OUT/overview.json"
```

## Output Settings

- Language: `he`
- Learning ladder (Phase 2 synthesis and Phase 6b page): **Basics** — the question in
  plain words, why it matters and the key terms; **Advanced usage** — the main positions,
  their arguments, objections and replies; **Related research** — primary texts, SEP-style
  overviews and secondary literature.
- NotebookLM artifact focus: argument structure — positions, objections, replies.
