# web-research backend (self-hosted)

An optional backend for `/learn`: [elad12390/web-research-assistant](https://github.com/elad12390/web-research-assistant)
(16 search, crawl and lookup tools) plus SearXNG, run in Docker and exposed as a streamable-HTTP MCP server at
`http://<WRA_BIND_IP>:8765/mcp`. Upstream is pinned to commit `f41d3fb` and the SearXNG image to a digest (see
`docker-compose.yml`). The plugin works without it.

## Files you fill yourself

- `.env` (mode 600), copied from `.env.example`: `WRA_BIND_IP`, `WRA_TOKEN`, `SEARXNG_SECRET`, and optionally
  `PROXY_URL`, `EXA_API_KEY`, `PIXABAY_API_KEY`. Generate the token and secret with a random-string tool and write
  them straight into the file; never paste them in chat or commit them.
- `.token` (mode 600): the same `WRA_TOKEN` value alone, for `smoke.py --token-file`.
- Both are secrets. `.token` is git-ignored; `.env` matches the `*.env` ignore rule.

## Deploy

```bash
cd infra/web-research
cp .env.example .env && chmod 600 .env      # edit it
docker compose up -d --build
python3 smoke.py --url http://$WRA_BIND_IP:8765/mcp --token-file .token --case healthz tools_16 ssrf_blocked
```

`wra` publishes exactly one host port, `${WRA_BIND_IP}:8765`, and refuses to start with an empty `WRA_TOKEN`.
SearXNG publishes no port. Set `WRA_BIND_IP` to the Tailscale IP, never `0.0.0.0`.

In the plugin, set `web_research_url` (`http://<WRA_BIND_IP>:8765/mcp`) and `web_research_token` with
`/plugin configure learn-toolkit@learn-toolkit-marketplace`.

## Rotate the token

Write a new `WRA_TOKEN` into `.env` and `.token`, run `docker compose up -d` (recreates `wra`), then re-enter the
token in the plugin config. A wrong token shows as `needs authentication` in `/mcp`.

## Proxy (optional)

Evomi is optional. Without `PROXY_URL`, upstream escalates normal fetch, then stealth browser. With it, the order is
normal, normal+proxy, stealth, stealth+proxy, and the `country` argument geo-targets through the proxy. Copy the URL
from the Evomi dashboard in the form `http://user:pass@<evomi-host>:<port>` into `.env`, then
`docker compose up -d`. Buying the plan is your decision.

## Logs

`docker compose logs -f wra searxng`. `/app/data/usage.json` (named volume `wra-data`) holds the queries and URLs the tools were
called with; treat it as private. Read it with `docker compose exec wra cat /app/data/usage.json`;
`docker compose down -v` deletes it.

## Take it down

`docker compose down` keeps the `wra-data` volume; `docker compose down -v` deletes it. Remove
`.env` and `.token` to wipe the rest.

## Security notes

- Every request except `GET /healthz` needs `Authorization: Bearer <WRA_TOKEN>` (constant-time compare);
  DNS-rebinding protection is on with an allowed-host list.
- URL tools (`crawl_url`, `batch_crawl_urls`, `stealth_scrape`, `extract_data`, `api_docs` with a URL) refuse
  loopback, private, link-local, Tailscale/CGNAT, unspecified and unresolvable hosts, plus the compose service names
  `searxng` and `wra`. `country` must be a two-letter code.
- Residual risk, redirects: upstream follows redirects, so a public URL that redirects to an internal host is not caught.
- Residual risk, DNS rebinding: the guard resolves the name, then the fetcher resolves it again, so a rebinding DNS
  name can answer public once and internal the next time. The real fix (an egress firewall, or pinning the resolved
  IP into the fetch) is out of scope here.
- Residual risk, search-result URLs: some tools crawl URLs they get from search results (for example `api_docs`
  falls back to SearXNG hits, `server.py:1690-1700`). The wrapper cannot see those URLs, so a public hostname that
  resolves to an internal IP could be fetched. The real fix is an egress firewall: a `DOCKER-USER` iptables rule that
  drops traffic from the `wra` container to RFC1918, link-local and `100.64.0.0/10`. That is a follow-up and needs
  sudo on the dev server.
- Also refused: URLs containing a backslash, whitespace, control characters or userinfo (`user@host`), and
  `check_service_status` `service` and `api_docs` `api_name` values with characters other than letters, digits, space, dot, dash and underscore.
- The guard wraps FastMCP's private tool registry; re-check it when the upstream pin moves.
