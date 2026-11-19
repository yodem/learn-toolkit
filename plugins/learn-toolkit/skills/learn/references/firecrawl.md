# Firecrawl Reference (keyless free tier)

`firecrawl` is Firecrawl's hosted MCP server at `https://mcp.firecrawl.dev/v2/mcp`, used on
its **keyless free tier**: no account, no API key, nothing in `userConfig`. It is
**additive**: it never replaces a Tavily, Exa, Sefaria, Trove or NotebookLM lane (the one
exception is a run with no Tavily and no Exa; see SKILL.md Phase 0), and its
digests flow through the same Phase 2 merge. Its strength is clean markdown from pages and
documents that other backends return thin or broken: JavaScript-heavy sites and public
PDF/DOCX URLs.

## Detection

- Phase 0 Step 0b runs `ToolSearch(query="+firecrawl firecrawl_search")`.
- `HAS_FIRECRAWL` is true when a tool ending in `__firecrawl_search` exists. Match by
  suffix and use the full discovered tool names in every subagent prompt; never hard-code a
  server prefix.
- The keyless tier exposes only `firecrawl_search`, `firecrawl_scrape` and
  `firecrawl_parse`. Crawl, map, extract, batch scrape, agent, monitor and Alexandria
  providers need an account; `/learn` never calls them.

## Routing table

| Tool | When `/learn` uses it |
|------|-----------------------|
| `firecrawl_search` | The `firecrawl` lane: one or two discovery queries. Pass `query`, `limit` (≤ 5) and an `objective` sentence describing the ideal page. Use `includeDomains` for docs or repo targets |
| `firecrawl_scrape` | Fetch up to 3 keepers from the lane's own search results as markdown, favouring JS-heavy pages and public PDFs (it runs in parallel with the other lanes, so it never waits on their URLs). Pass `url`, `formats: ["markdown"]`, `onlyMainContent: true` |
| `firecrawl_parse` | A local document (PDF, DOCX, XLSX, HTML) the user handed to the run. Public document URLs go through `firecrawl_scrape` instead |

## Budget and limits

- Per subagent: at most 2 `firecrawl_search` plus 3 `firecrawl_scrape` calls. The free
  tier is rate-limited per network, and a parallel fan-out shares one limit.
- Never request `screenshot`, `branding` or HTML formats; markdown only.
- A refusal (`KEYLESS_*` error, HTTP 403 or 429, or "daily limit") ends the Firecrawl lane
  for the run; the Phase 1 gate exempts it and never re-dispatches it. Do not retry, and do not route around the limit through another client.
  Calls from VPNs and proxies may be refused outright.
- When the server's response ends with a sign-up line, report it once in the final report;
  never sign up or ask for a key during the run.
