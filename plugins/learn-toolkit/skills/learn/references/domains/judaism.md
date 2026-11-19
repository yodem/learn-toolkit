# Domain: judaism

## Identity

Torah, Talmud, halakha, midrash, Jewish thought and its commentators. Prefer this domain
when a primary Jewish text is the thing being studied, even when the framing is
philosophical.

## Subagent Roster

Fixed roles, dispatched every run in the same message as the web lanes:

1. **primary** — Sefaria MCP. This is the authoritative source for this domain and always
   runs first: `mcp__claude_ai_Sefaria__text_search`,
   `mcp__claude_ai_Sefaria__english_semantic_search`,
   `mcp__claude_ai_Sefaria__get_topic_details`,
   `mcp__claude_ai_Sefaria__get_links_between_texts` for commentary chains.
2. **library** — Trove (formerly CandleKeep) Judaica books (see `../trove-integration.md`).
3. **web** — the free open search on the self-hosted web-research server (SearXNG):
   `batch_web_search` (one batch call), plus `batch_crawl_urls` for the keepers.
   It always runs when `HAS_WEB_RESEARCH`, on every run, and does not count toward `$WEB_LANES`; see
   `../web-research.md`.

Web lanes (default 2), **secondary only**: scholarship and shiurim that contextualise the
primary text, never used in place of Sefaria. Fill the lanes from the backends that are available, in the order below, one subagent per
backend; take the first `$WEB_LANES` (see SKILL.md Phase 0.5). A query intent whose
backend is not chosen moves to the first chosen lane, so a single lane still covers the
first two intents in order.

1. **exa** — `web_search_advanced_exa` with `category: "publication"` for academic articles.
2. **tavily** — shiurim, encyclopedic entries and community scholarship.
3. **firecrawl** — keyless Firecrawl `firecrawl_search` (at most 2 queries) plus
   `firecrawl_scrape` for up to 3 of its own results, favouring JS-heavy pages and public
   PDFs; see `../firecrawl.md`.

## Source Ranking

primary text (Sefaria) > classical commentators > library (Trove) > academic scholarship > shiurim and popular writing

## Query Patterns

Sefaria first. Resolve the topic to a citation before searching the open web, so that
secondary sources are evaluated against the text rather than substituting for it.

Exa secondary research — use `web_search_advanced_exa` with `category: "publication"`;
describe the ideal page:

- GOOD: `"academic article on the reception history of <text> among medieval commentators"`
- BAD: `"<text> commentary history"`

## Output Settings

- Language: `he`
- Learning ladder (Phase 2 synthesis and Phase 6b page): **Basics** — the primary text
  and its plain meaning, with key terms explained; **Advanced usage** — the commentators'
  positions, the sugya's structure and the practical halakha; **Related research** —
  academic scholarship, shiurim and library sources.
- NotebookLM artifact focus: text-and-commentary — sugya structure, positions of the
  commentators, practical halakhic upshot where relevant.
