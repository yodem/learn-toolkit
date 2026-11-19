# Firecrawl Reference (free tier)

Firecrawl is one of the three web-lane backends (with Tavily and Exa); Phase 0.5 picks
`$WEB_LANES` of them per run. It runs on the free tier through one of two routes:

- **MCP (default):** the bundled `firecrawl` server at `https://mcp.firecrawl.dev/v2/mcp`,
  on the **keyless** free tier: no account, no API key, nothing in `userConfig`.
- **CLI (fallback):** the `firecrawl` CLI signed in to a free account (1,000 credits a
  month). The user installs it with `npx -y firecrawl-cli@latest init --all --browser` and
  signs in on the website; `/learn` never runs `firecrawl login`.

Its strength is clean markdown from pages and documents that other backends return thin
or broken: JavaScript-heavy sites and public PDF/DOCX URLs.

## Detection

- Phase 0 Step 0b runs `ToolSearch(query="+firecrawl firecrawl_search")`.
  `HAS_FIRECRAWL_MCP` is true when a tool ending in `__firecrawl_search` exists. Match by
  suffix and use the full discovered tool names in every subagent prompt; never hard-code a
  server prefix.
- Phase 0 Step 0a-2 sets `HAS_FIRECRAWL_CLI` when `firecrawl --status` reports
  `Authenticated`.
- `HAS_FIRECRAWL` is true when either is.
- The keyless tier exposes only `firecrawl_search`, `firecrawl_scrape` and
  `firecrawl_parse`. Crawl, map, extract, batch scrape, agent, monitor and Alexandria
  providers are never used by `/learn`.

## Routing table

| Route | Search | Scrape |
|-------|--------|--------|
| MCP | `firecrawl_search` with `query`, `limit` (≤ 5) and an `objective` sentence describing the ideal page; `includeDomains` for docs or repo targets | `firecrawl_scrape` with `url`, `formats: ["markdown"]`, `onlyMainContent: true` |
| CLI | `firecrawl search "<query>" --limit 5 --json -o "$OUT/fc-search.json"`, then read the file through a Python filter | `firecrawl scrape "<url>" -o "$OUT/fc-<n>.md"`, then read only the main sections |

`$OUT` is the subagent's own `mktemp -d` directory, as for Tavily; paste its literal path.
Use the MCP route when `HAS_FIRECRAWL_MCP`; switch to the CLI only when the MCP is missing
or refuses a call. The lane scrapes up to 3 keepers from its own search results,
favouring JS-heavy pages and public PDFs. `firecrawl_parse` is for a local document the
user handed to the run.

## Budget and limits

- Per subagent: at most 2 searches plus 3 scrapes, whichever route. The keyless tier is
  rate-limited per network, and the CLI spends free-account credits.
- Never request `screenshot`, `branding` or HTML formats; markdown only.
- A keyless refusal (`KEYLESS_*` error, HTTP 403 or 429, or "daily limit") moves the lane
  to the CLI when `HAS_FIRECRAWL_CLI`; otherwise it ends the Firecrawl lane for the run,
  and the Phase 1 gate exempts it and never re-dispatches it. A CLI out-of-credits error
  ends the lane the same way. Calls from VPNs and proxies may be refused outright.
- When the server's response ends with a sign-up line, report it once in the final report;
  never sign up or ask for a key during the run.
