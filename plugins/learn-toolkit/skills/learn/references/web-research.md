# web-research Reference (optional fourth search backend)

`web-research` is a self-hosted MCP server that adds 16 tools next to Tavily and Exa. It
is **additive**: it never replaces a Tavily, Exa, Sefaria, Trove or NotebookLM lane, and
its digests flow through the same Phase 2 merge into NotebookLM and Trove. Setup for the
server lives at https://github.com/yodem/learn-toolkit/tree/main/infra/web-research.

## Detection

- Phase 0 Step 0b runs `ToolSearch(query="batch_crawl_urls stealth_scrape")`. No hyphenated
  `+` term, because the hyphen would be read as an operator.
- `HAS_WEB_RESEARCH` is true when a tool ending in `__batch_crawl_urls` exists on a server
  whose name contains `web-research`. Match by suffix and use the full discovered tool
  names in every subagent prompt; never hard-code a server prefix.
- If that one query finds nothing while the other probes found their backends, re-run it
  once after all probes finish (an http server can connect late). Never retry per subagent.
- A blank URL fails only this server (`INVALID_CONFIG`); Tavily and Exa still connect.
- A wrong token returns 401, which Claude Code shows as `needs authentication`, so the tools
  never register and Phase 0 cannot tell it from a blank URL. That is why the `✗` note
  always tells the user to check `/mcp`.

## Routing table

| Tool | When `/learn` uses it |
|------|-----------------------|
| `batch_web_search` | Every domain: the free extra search lane (up to 20 queries in one call). For tech use categories it/general |
| `web_search` | A single follow-up query when only one is needed |
| `batch_crawl_urls` | Every domain: fetch the keepers (up to 20 URLs) when Tavily/Exa extraction fails or returns thin text |
| `crawl_url` | One URL, when only one page needs fetching |
| `stealth_scrape` | A page that returned 403, 429 or a captcha elsewhere; pass `country` (ISO alpha-2) to route the proxy |
| `extract_data` | Tables, lists and JSON-LD from a page, for the learning page |
| `search_images` | Learning-page images, only when the server has a Pixabay key |
| `package_info` | Tech: registry metadata for a named package |
| `package_search` | Tech: find packages for a need |
| `github_repo` | Tech: repo health, stars, activity, README |
| `api_docs` | Tech: official API documentation for a named library |
| `get_changelog` | Tech: release notes and breaking changes |
| `compare_tech` | Tech, when the subject names two or more technologies |
| `search_examples` | Tech: code examples |
| `translate_error` | Not used by `/learn`; available to the user directly |
| `check_service_status` | Not used by `/learn`; available to the user directly |

Also available to the user directly, outside `/learn`: the five prompts `research_package`,
`debug_error`, `compare_technologies`, `evaluate_repository` and `check_service_health`,
and the resources `package://{registry}/{name}`, `github://{owner}/{repo}`,
`status://{service}`, `changelog://{registry}/{package}` and `domain-health://report`.

Most tools take an optional `reasoning` string (default empty); passing a one-line reason for the call is recommended.
`crawl_url`, `batch_crawl_urls` and `stealth_scrape` take an optional `country` (two
letters, e.g. `US`); leave it out unless geo-targeting matters.

## Batching rule

One batch call per lane, never a loop of single calls. A subagent that has several queries
sends them in one `batch_web_search`; one that has several URLs sends them in one
`batch_crawl_urls`. Keep each batch at 20 items or fewer and split above that.

## Failure handling

- `needs authentication`, 401 or an unreachable server: the backend is `✗`; carry on with
  Tavily, Exa and the other lanes. Never ask the user to paste the token in chat.
- Zero results from `batch_web_search` (SearXNG engines blocked or empty): treat it like a
  failed lane and lean on Tavily and Exa. Do not retry with the same query.
- A URL refused as internal or private (the server's SSRF guard): report it and skip that
  URL. Do not try to route around the refusal.
- One batch item failing does not fail the batch; keep the items that returned content.
- A tool error on one call: log it, skip that call, continue the lane.

## Return contract

A web-research subagent returns digests like every other subagent, never raw pages, aiming
for roughly 1,000-2,000 tokens in total:

```json
[{"url": "...", "title": "...", "kind": "official_docs|tutorial|discussion|library|primary_text|deep_research",
  "why_it_matters": "one sentence", "key_claims": ["...", "..."]}]
```

Use the same `kind` values and the domain's `## Source Ranking`; a page's rank comes from
what it is, not from which backend fetched it. Dedupe by URL in Phase 2 as usual.
