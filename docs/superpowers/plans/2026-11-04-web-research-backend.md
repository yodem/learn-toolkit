# Web-research backend (SearXNG + Scrapling + residential proxy) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give learn-toolkit every feature of `elad12390/web-research-assistant` (16 tools, 5 resources, 5 prompts) as an optional fourth research backend. It is hosted on the dev server in Docker and reached over Tailscale, and it can route blocked fetches through an Evomi residential proxy.

**Architecture:** `infra/web-research/` holds a Docker Compose stack for the dev server: a pinned SearXNG container, reachable only on the compose network, and a `wra` container. The `wra` image is built from the upstream repo at a pinned commit plus a small launcher (`serve_http.py`). The launcher serves the upstream FastMCP app over streamable HTTP behind a bearer-token check and an SSRF guard. The plugin's `.mcp.json` adds an `http` server `web-research` whose URL and token come from `userConfig`. The `learn` skill detects it by tool-name suffix and routes to it through a new `references/web-research.md`. Upstream code is consumed, never forked.

**Tech Stack:** Docker Compose v5 (BuildKit `additional_contexts` from a git URL), SearXNG, Python 3.14 + upstream `web-research-assistant` 0.4.0 (mcp 1.29 FastMCP, Scrapling, Playwright Chromium), pure-ASGI middleware, Python 3 stdlib smoke client and unit tests, Claude Code plugin `.mcp.json` / `userConfig`, bash lint.

**Spec:** this plan's Goal, Global Constraints and Review Focus. They come from the 2026-11-04 /drive brainstorm, where [Q50] chose dev-server Docker over uvx-on-Mac and over porting the code, and from two zero-context plan reviews whose findings are folded in below.

## Global Constraints

- **Additive only (Yotam, 2026-11-04).** Nothing existing is removed or weakened. The Tavily (MCP + CLI), Exa, Exa Agent `--deep`, Sefaria, Trove scan + Phase 7 write offer, NotebookLM package, learning page and every existing roster role stay exactly as they are. web-research adds lanes next to them, its results flow through the same Phase 2 merge into NotebookLM and Trove, and it never replaces a lane. Check, run after T3 and T4: `scripts/additive-check.sh <base sha>`, a ~15-line script in the session scratchpad that is not committed. For each term in `tavily exa agent_run sefaria trove notebooklm Artifact`, it compares that term's case-insensitive occurrence count in `plugins/learn-toolkit/skills/` at the base sha against HEAD and exits 1 when any count drops. `git diff <base> --stat -- plugins/learn-toolkit/.mcp.json` must show additions only: `test "$(git diff <base> --numstat -- plugins/learn-toolkit/.mcp.json | awk '{print $2}')" -le 1`, which allows the one changed line before the new server entry.

- Upstream is pinned: `https://github.com/elad12390/web-research-assistant.git#f41d3fbba9e52d258b82390ec21a0382a1c28f2e`. The SearXNG image is pinned by the upstream digest `searxng/searxng@sha256:1f3720f59a0361592dc942e4be50e0ebb63c112d915883fcb78a011995fffb47`.
- Access control:
  - `wra` publishes exactly one host port, `${WRA_BIND_IP}:8765:8765`, and `WRA_BIND_IP=100.106.37.39` (the Tailscale IP) on the dev server. It never binds `0.0.0.0` or `[::]`, and SearXNG publishes no host port.
  - Every HTTP request except an exact `GET /healthz` needs `Authorization: Bearer ${WRA_TOKEN}`, or it gets a 401. The token is compared as bytes with `hmac.compare_digest(given.encode(), token.encode())`.
  - An empty `WRA_TOKEN` makes the launcher exit 1 at startup; it never runs open.
  - DNS-rebinding protection stays **on**, with `allowed_hosts` `["${WRA_BIND_IP}:8765", "localhost:8765", "127.0.0.1:8765"]`.
- SSRF guard:
  - The launcher wraps the URL-taking tools `crawl_url`, `batch_crawl_urls`, `stealth_scrape`, `extract_data`, and `api_docs` when given a URL. A URL is refused when any address its host resolves to is loopback, RFC1918, link-local (`169.254.0.0/16`, incl. the cloud metadata IP), CGNAT/Tailscale `100.64.0.0/10`, IPv6 loopback/ULA/link-local, or unspecified.
  - The compose service names `searxng` and `wra` are refused by name.
  - `country` must match `^[A-Za-z]{2}$` or be empty.
  - The wrap uses FastMCP's tool registry (`mcp._tool_manager`). That is a private API, safe only because upstream is pinned, and the code says so in a comment.
  - Residual risk, stated in the README: upstream follows redirects, so a public URL that redirects to an internal host is not caught.
- Secrets:
  - The secrets are `WRA_TOKEN`, `PROXY_URL`, `EXA_API_KEY`, `PIXABAY_API_KEY` and `SEARXNG_SECRET`. They live only in `~/dev/web-research/.env` on the dev server (mode 600) and in `~/dev/web-research/.token` (mode 600, `WRA_TOKEN` only).
  - Generated secrets go straight into those files and are never echoed. Yotam types the rest. No secret is printed, logged, committed, or put in memory, Trove, or a PR.
  - `wra` gets an explicit `environment:` list, not `env_file`, and never receives `SEARXNG_SECRET`. `searxng` receives only `SEARXNG_SECRET`.
  - The SearXNG `secret_key` line is deleted from settings, so the image's native `SEARXNG_SECRET` override applies and the upstream test value `bdd-test-runner-…` never ships.
- `wra` runs as non-root user `wra` (uid 10001) and has a `HEALTHCHECK` on `/healthz`.
- `PROXY_URL` is optional.
  - Upstream escalates normal → normal+proxy → stealth → stealth+proxy (`crawler.py:192`). Without a proxy URL, it runs normal → stealth.
  - With an Evomi URL, the `country` argument geo-targets through `_country-XX` in the password (`crawler.py:79`).
  - Buying the Evomi plan is Yotam's decision and action, not a build step.
- Plugin: server key `web-research`, `type: "http"`, URL `${user_config.web_research_url}`, header `Authorization: Bearer ${user_config.web_research_token}`.
  - Both settings are `required: false` and **both are `sensitive: true`**, which keeps lint check 8 (`lint-skill.sh:801-803`, every interpolated key sensitive) passing.
  - Their descriptions link `https://github.com/yodem/learn-toolkit/tree/main/infra/web-research`. A repo-relative path would not reach installed users, because `infra/` is outside the plugin root.
  - Verified 2026-11-04 by probe: with the URL unset, only that server fails, with `INVALID_CONFIG: its URL is unset or invalid`. A sibling server in the same `.mcp.json` still connects, and `claude plugin validate` passes.
- Detection: `HAS_WEB_RESEARCH` means a tool ending in `__batch_crawl_urls` exists on a server whose name contains `web-research`. The ToolSearch query is `batch_crawl_urls stealth_scrape`, with no hyphenated `+` term. There is never a hard-coded `mcp__` prefix, and lint check 9 is extended to cover `references/web-research.md`.
- Version 2.3.0 in `plugin.json`, `.claude-plugin/marketplace.json`, and SKILL.md `metadata.version`. SKILL.md `metadata.mcp-server` adds `web-research`, and `description` names it as an optional self-hosted backend.
- SKILL.md grows by at most 25 lines net (from 590 today). Routing detail goes in `references/web-research.md`.
- The only hard stop stays "zero search backends". `HAS_WEB_RESEARCH` now counts as a search backend alongside Tavily and Exa.
- No Terraform, and no change outside `~/dev/learn-toolkit` and `~/dev/web-research/` on the dev server. A systemd drop-in on the dev server (T2 Step 3) is the one exception, and it happens only if Yotam has sudo and approves it in that step.

## Review Focus

1. **A public user without the dev server.** With `web_research_url` blank, `web-research` fails with INVALID_CONFIG, Tavily/Exa still connect, and `/learn` runs as 2.2.1 does with `[Web research ✗]`. Pinned by T3 lint check `web-research-optional` and T4 Step 3, where the output must show an exa server connected and web-research failed.
2. **Stack up but token wrong.** Claude Code treats a 401 from an http MCP server as "needs authentication", so the tools never register. At Phase 0 a bad token looks the same as a blank URL, and the skill cannot print "token rejected". Instead, the `[Web research ✗]` matrix note always says: "if you configured it, run `/mcp`; `needs authentication` there means the token is wrong; re-enter it with `/plugin configure learn-toolkit@learn-toolkit-marketplace`". Pinned on the server by unit tests and smoke cases `no_token_401`, `wrong_token_401` and `empty_bearer_401`, and in the client by T4 Step 3b (a deliberately wrong token shows `needs authentication` / failed for web-research).
3. **Proxy unset; Chromium actually works.** With `PROXY_URL` empty, `stealth_scrape("https://quotes.toscrape.com/js/")` must return `Albert Einstein`, which appears only after JS runs. This proves Chromium works in the image under Python 3.14 as non-root (smoke case `stealth_js`). Upstream does not log escalation steps (`crawler.py:184-236`), so proof of the proxy path is manual (T2 Step 5).
4. **The tailnet is unreachable (Mac off Tailscale) or the server connects late.** The connect fails, and the backend is ✗ at Phase 0. Phase 0 re-runs the ToolSearch once after the other probes finish, which covers late async connects, and never retries per subagent. Pinned in T3's Phase 0 text.
5. **SearXNG engines blocked or empty.** `web_search` returns zero results while crawling works. The skill treats zero results like a failed lane and leans on Tavily/Exa. Smoke case `searxng_direct` queries SearXNG itself from inside `wra` (`format=json`, at least 1 `results[]` entry with a `url`), so a configured Exa key cannot mask a dead SearXNG. `search_results` parses at least 1 result line with an `https://` URL not on the `searxng` host.
6. **SSRF through a prompt-injected URL.** `crawl_url` on `http://searxng:8080/`, `http://169.254.169.254/latest/meta-data/` and `http://100.106.37.39:8765/healthz` must each return a refusal, not content. Pinned by unit tests and smoke case `ssrf_blocked`.

---

### Task T1: Compose stack, HTTP launcher (auth + SSRF guard), unit tests, smoke client

**Files:**
- Create: `infra/web-research/docker-compose.yml`, `infra/web-research/Dockerfile`, `infra/web-research/serve_http.py`, `infra/web-research/test_serve_http.py`, `infra/web-research/searxng/settings.yml`, `infra/web-research/.env.example`, `infra/web-research/smoke.py`, `infra/web-research/README.md`
- Modify: `.gitignore` (add `infra/web-research/data/` and `infra/web-research/.token`)

**Interfaces:**
- Produces:
  - The HTTP endpoint `http://<WRA_BIND_IP>:8765/mcp` (streamable HTTP), with `GET /healthz` → `200 ok`.
  - In `serve_http.py`: `guard_url(url: str) -> str | None` (a refusal text, or None), `BearerAuth(app, token: bytes)` (ASGI), and `build_app() -> ASGIApp`.
  - `smoke.py --url URL --token-file PATH --case NAME [NAME ...]`, which exits 0 when every case passes, 1 when one fails, and 2 when it cannot connect. Cases: `healthz`, `no_token_401`, `wrong_token_401`, `empty_bearer_401`, `tools_16`, `resources_prompts`, `search_results`, `stealth_js`, `ssrf_blocked`.

- [ ] **Step 1: Write `test_serve_http.py` (failing).**
  - Stdlib `unittest`, using starlette's `TestClient` (starlette ships with mcp).
  - `guard_url` cases:
    - `test_guard_refuses_internal` returns non-None for `http://169.254.169.254/`, `http://10.0.0.1/`, `http://192.168.1.5/`, `http://100.106.37.39:8765/`, `http://127.0.0.1/`, `http://[::1]/`, `http://searxng:8080/` and `http://wra:8765/`.
    - `test_guard_allows_public` returns None for `https://example.com/`.
    - `test_guard_rejects_non_http` refuses `file:///etc/passwd`.
  - Middleware cases: `test_auth_*` returns 401 for no header, `Bearer wrong`, `Bearer ` and a non-ASCII token; 200 for `/healthz` without a header; 401 for `/healthzX` and for `/mcp` without a header.
  - `test_empty_token_exits`: `build_app()` with `WRA_TOKEN=""` raises `SystemExit(1)`.
- [ ] **Step 2: Write `serve_http.py`** so those tests pass. Use the Global Constraints values. Run the app with `uvicorn.run(build_app(), host="0.0.0.0", port=8765)` (inside the container only).
- [ ] **Step 3: `Dockerfile`.**
  - BuildKit, `FROM python:3.14-slim`, with uv copied from `ghcr.io/astral-sh/uv:0.12.1`.
  - `COPY --from=upstream` brings in `requirements.txt pyproject.toml src/`, then the upstream install lines (requirements, `playwright install --with-deps chromium` with `PLAYWRIGHT_BROWSERS_PATH=/ms-playwright`, `--no-deps .`).
  - Create user `wra` (uid 10001) and give it ownership of `/ms-playwright` and `/app/data`. `COPY serve_http.py test_serve_http.py /app/`.
  - `USER wra`, `HEALTHCHECK` with `python -c` urllib on `http://127.0.0.1:8765/healthz`, and `CMD ["python", "/app/serve_http.py"]`.
- [ ] **Step 4: `docker-compose.yml`.**
  - `searxng`: the pinned digest, `./searxng:/etc/searxng:rw`, `environment: [SEARXNG_SECRET=${SEARXNG_SECRET:?}]`, the upstream healthcheck, `restart: unless-stopped`, and **no `ports:`**.
  - `wra`:
    - `build: {context: ., additional_contexts: {upstream: "<pinned git URL>"}}` and `ports: ["${WRA_BIND_IP:?}:8765:8765"]`.
    - An `environment:` list: `WRA_TOKEN=${WRA_TOKEN:?}`, `WRA_BIND_IP`, `PROXY_URL`, `EXA_API_KEY`, `PIXABAY_API_KEY`, `SEARCH_PROVIDER=${SEARCH_PROVIDER:-auto}`, `SEARXNG_BASE_URL=http://searxng:8080/search` and `MCP_USAGE_LOG=/app/data/usage.json`.
    - `./data:/app/data`, `restart: unless-stopped`, and `depends_on: {searxng: {condition: service_healthy}}`.
- [ ] **Step 5: `searxng/settings.yml`.** Copy upstream `searxng-config/settings.yml` and **delete** its `secret_key` line. Keep `formats: [html, json]` and `limiter: false`.
- [ ] **Step 6: `.env.example`.** Keys with empty values and one comment each: `WRA_BIND_IP=100.106.37.39`, `WRA_TOKEN=`, `SEARXNG_SECRET=`, `PROXY_URL=` (Evomi format `http://user:pass@<evomi-host>:<port>`, copied from the Evomi dashboard), `EXA_API_KEY=`, `PIXABAY_API_KEY=` and `SEARCH_PROVIDER=auto`.
- [ ] **Step 7: `smoke.py`.**
  - Stdlib only. It sends JSON-RPC `initialize`, then `notifications/initialized` with the `Mcp-Session-Id` header, then `tools/list`, `resources/templates/list`, `prompts/list` and `tools/call`, and parses a JSON or a `text/event-stream` body.
  - It reads the token from `--token-file` and never prints it or puts it in an error message.
  - Case assertions:
    - `tools_16`: the tool name set equals exactly `{web_search, batch_web_search, search_examples, search_images, crawl_url, batch_crawl_urls, stealth_scrape, package_info, package_search, github_repo, translate_error, api_docs, extract_data, compare_tech, get_changelog, check_service_status}`.
    - `resources_prompts`: at least 4 resource templates, and the prompt names include `{research_package, debug_error, compare_technologies, evaluate_repository, check_service_health}`.
    - `search_results`: `web_search(query="python asyncio tutorial", reasoning="smoke")` has `isError` false, and the text holds at least 1 `https://` URL whose host is not `searxng`.
    - `stealth_js`: `stealth_scrape(url="https://quotes.toscrape.com/js/", reasoning="smoke")` text contains `Albert Einstein`.
    - `ssrf_blocked`: `crawl_url` on each of the three URLs in Review Focus 6 returns text with the guard's refusal marker `blocked by ssrf guard`.
    - `no_token_401`, `wrong_token_401`, `empty_bearer_401`: a POST to `/mcp` gets HTTP 401.
- [ ] **Step 8: README.md.**
  - Deploy, rotate the token, add the proxy, read the logs, and take it down.
  - Name the files Yotam fills himself, say that Evomi is optional, and state the redirect residual risk.
  - Explain that `data/usage.json` holds queries and URLs.
- [ ] **Step 9: Checks.**
  - On the dev server, `docker compose -f infra/web-research/docker-compose.yml --env-file <scratch dummy env: WRA_BIND_IP=127.0.0.1 WRA_TOKEN=x SEARXNG_SECRET=y> config -q` exits 0. Rsync to a temp directory if needed.
  - `python3 -m py_compile infra/web-research/serve_http.py infra/web-research/smoke.py infra/web-research/test_serve_http.py`
  - `! grep -nE 'secret_key|bdd-test-runner' infra/web-research/searxng/settings.yml`
  - `! grep -nE 'env_file|0\.0\.0\.0:8765' infra/web-research/docker-compose.yml`
  - `git check-ignore -q infra/web-research/data/x && git check-ignore -q infra/web-research/.token`
- [ ] **Step 10: Commit** `feat(infra): web-research compose stack with auth + SSRF-guarded HTTP launcher`.

Model: `claude-sonnet-5-5`. The unit tests run in T2 Step 2, inside the built image.

### Task T2: Deploy on the dev server and prove it live

**Files:** none in the repo. The dev server gets `~/dev/web-research/` (rsync of `infra/web-research/`, excluding `.env`, `.token` and `data/`).

**Interfaces:** Consumes T1's files, tests and smoke cases. Produces a running stack and `~/dev/web-research/.token`.

- [ ] **Step 1: Copy the files and create the secrets.**
  - `rsync -a --exclude .env --exclude .token --exclude data infra/web-research/ yodem@100.106.37.39:dev/web-research/`.
  - On the server, under `umask 077`, create `.env` from `.env.example` and fill `WRA_TOKEN` and `SEARXNG_SECRET` with `openssl rand -hex 32` through `sed -i`, never echoed. Write `.token` from the same value.
  - Check: `test "$(stat -c %a .env)" = 600 && test "$(stat -c %a .token)" = 600`.
- [ ] **Step 2: Build, start and run the unit tests.**
  - `docker compose up -d --build`, in the foreground, in slices of up to 10 min.
  - Check: `docker compose ps --format json` shows `searxng` and `wra` both `healthy`, not just running, after a wait of up to 90 s.
  - `docker compose exec wra python -m unittest -v /app/test_serve_http.py` reports more than 0 tests and `OK`.
  - `docker compose exec wra id -u` prints `10001`.
- [ ] **Step 3: Access control.**
  - `ss -Hltn 'sport = :8765'` prints exactly one line, with local address `100.106.37.39:8765`. Check: `test "$(ss -Hltn 'sport = :8765' | awk '{print $4}')" = 100.106.37.39:8765`.
  - `! ss -Hltn | grep -E ':8080\b'`.
  - From the dev server, `curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://<its LAN IP>:8765/healthz` does not print `200`. The LAN IP comes from `ip -4 route get 1.1.1.1`.
  - Boot ordering: check whether `docker.service` already orders after `tailscaled.service` with `systemctl show docker -p After`. If it does not, **ask Yotam** before adding the drop-in `/etc/systemd/system/docker.service.d/after-tailscale.conf` (`After=tailscaled.service`, `Wants=tailscaled.service`). If he declines, record it in the README as a known gap: after a reboot, `docker compose up -d` may be needed once.
- [ ] **Step 4: SearXNG direct.** `docker compose exec wra python -c "import json,urllib.request;d=json.load(urllib.request.urlopen('http://searxng:8080/search?q=python+asyncio&format=json'));assert any(r.get('url') for r in d['results']),'no results';print(len(d['results']))"` exits 0.
- [ ] **Step 5: Live smoke from the Mac.**
  - Under `umask 077`, copy the token by ssh into `<scratch>/wra.token`, with a `trap 'rm -f <scratch>/wra.token' EXIT` in the same shell.
  - `python3 infra/web-research/smoke.py --url http://100.106.37.39:8765/mcp --token-file <scratch>/wra.token --case healthz no_token_401 wrong_token_401 empty_bearer_401 tools_16 resources_prompts search_results stealth_js ssrf_blocked` exits 0.
- [ ] **Step 6:** `manual`: whether to buy Evomi is Yotam's call.
  - If he buys it, he runs `ssh -t yodem@100.106.37.39 'cd dev/web-research && ${EDITOR:-nano} .env && docker compose up -d'` in his own terminal (the `!` prompt is not a TTY) and sets `PROXY_URL`.
  - Proof: on a site that blocks the dev server's IP, `crawl_url` or `stealth_scrape` returns content with `country="IL"` where it failed before. Upstream does not log the step, so this before/after comparison is the evidence.
  - This step is not a gate for close.

Model: lead (inline; ssh + ops).

### Task T3: Plugin wiring + skill routing

**Files:**
- Modify:
  - `plugins/learn-toolkit/.mcp.json`, `plugins/learn-toolkit/.claude-plugin/plugin.json` (userConfig + version) and `.claude-plugin/marketplace.json` (version).
  - `plugins/learn-toolkit/skills/learn/SKILL.md`: frontmatter description, `metadata.mcp-server` and version; Phase 0b; the matrix; the hard stop; Phase 1 token rules; Error Recovery.
  - `plugins/learn-toolkit/skills/learn/references/domains/{tech,philosophy,judaism}.md` and `plugins/learn-toolkit/scripts/lint-skill.sh`.
- Create: `plugins/learn-toolkit/skills/learn/references/web-research.md`

**Interfaces:** Consumes T1's 16 tool names. Produces the state flag `HAS_WEB_RESEARCH`, the matrix token `[Web research ✓/✗]`, and the roster role `web` (tech also gets `packages`).

- [ ] **Step 1: Lint first (failing).**
  - Add three checks to `lint-skill.sh` and set `TOTAL_CHECKS` to 13.
  - `web-research-optional`: `.mcp.json` `web-research` has `type` `http`, `url` exactly `${user_config.web_research_url}`, and the Bearer header with `${user_config.web_research_token}`. `plugin.json` declares both keys with `required:false` and `sensitive:true`.
  - `web-research-tools-known`: the script holds the 16-name list. It extracts every backticked identifier that sits within 40 characters of `web-research` or within a `references/web-research.md` table row, and fails on any that is not in the list. A self-test feeds it the string `` `web_searches` `` and expects a failure.
  - `web-research-in-matrix`: SKILL.md contains `[Web research ✓/✗]` and `HAS_WEB_RESEARCH`, and the hard-stop sentence names all three backends.
  - Extend check 9's (no hard-coded prefix) file set to include `references/web-research.md`.
  - Run `bash plugins/learn-toolkit/scripts/lint-skill.sh`. Expect exit 1, naming `web-research-optional` and `web-research-in-matrix`.
- [ ] **Step 2: `.mcp.json` + `plugin.json`.** Add the server and the two userConfig fields from Global Constraints, with the GitHub URL in their descriptions.
- [ ] **Step 3: `references/web-research.md` (≤ 120 lines).** Sections:
  - **Detection**, as in Global Constraints.
  - **Routing table**: all 16 tools, with when `/learn` uses each.
    - All domains: `batch_web_search` is the free extra search lane. `batch_crawl_urls` fetches keepers when Tavily/Exa extraction fails.
    - `stealth_scrape(country=...)` handles a page that returned 403, 429 or a captcha elsewhere. `extract_data` pulls tables, lists and JSON-LD for the learning page. `search_images` supplies learning-page images when a Pixabay key is set.
    - tech: `package_info`, `package_search`, `github_repo`, `api_docs`, `get_changelog`, `compare_tech` (when the subject names two or more technologies) and `search_examples`.
    - `translate_error` and `check_service_status`, plus the 5 resources and 5 prompts, are listed as available to the user directly, outside /learn.
  - **Batching rule**: one batch call per lane, never a loop of single calls.
  - **Failure handling**: Review Focus 2, 4 and 5, plus the SSRF refusal: report it and skip that URL.
  - **Return contract**: the SKILL.md digest JSON.
- [ ] **Step 4: SKILL.md.**
  - Phase 0b adds a 5th ToolSearch, `batch_crawl_urls stealth_scrape`, sets `HAS_WEB_RESEARCH`, and re-runs that one query once if it is still missing after the other probes.
  - The matrix gets `[Web research ✓/✗]` with the ✗ hint text from Review Focus 2.
  - The hard stop becomes "`HAS_TAVILY`, `HAS_EXA` and `HAS_WEB_RESEARCH` are all false".
  - Phase 1 gets one token rule pointing to `${CLAUDE_SKILL_DIR}/references/web-research.md`.
  - Error Recovery gets three rows: needs-auth/401, unreachable, and zero results.
  - The frontmatter `description`, `metadata.mcp-server` and version 2.3.0 are updated.
- [ ] **Step 5: Domain files.** Each new role is "only when HAS_WEB_RESEARCH".
  - tech: add **web** (`batch_web_search` with categories `it`/`general`, plus `batch_crawl_urls`) and **packages** (`package_info`/`github_repo`/`api_docs`/`get_changelog`/`compare_tech`).
  - philosophy and judaism: add **web** only.
- [ ] **Step 6: Checks.**
  - `bash plugins/learn-toolkit/scripts/lint-skill.sh` prints `lint-skill: 13/13 checks passed`.
  - `claude plugin validate plugins/learn-toolkit` prints `Validation passed`.
  - `test "$(jq -r '.mcpServers["web-research"].type' plugins/learn-toolkit/.mcp.json)" = http`
  - `test "$(jq -r '.userConfig.web_research_url.sensitive' plugins/learn-toolkit/.claude-plugin/plugin.json)" = true`
  - `test $(( $(wc -l < plugins/learn-toolkit/skills/learn/SKILL.md) - 590 )) -le 25`
  - `python3 -m pytest -q maintainer/tests` passes, with at least 14 tests collected.
- [ ] **Step 7: Commit** `feat(learn): optional self-hosted web-research backend (2.3.0)`.

Model: `claude-sonnet-5-5`.

### Task T4: Docs + end-to-end proof

**Files:** Modify `README.md`, `plugins/learn-toolkit/README.md`, `plugins/learn-toolkit/references/setup-guide.md` and `CLAUDE.md`. `CLAUDE.md` gets a new Step 3c, "web-research (optional, self-hosted)", and a row in the Step 4 table.

- [ ] **Step 1: Docs.**
  - What the backend adds: SearXNG, stealth crawling, an optional Evomi residential proxy with per-country routing, and the package, GitHub, changelog and API-docs tools.
  - How to self-host it, with a link to the GitHub `infra/web-research` URL. Say that it is optional and that a blank URL leaves only that server failed.
  - Never tell anyone to paste keys in chat.
  - Check: `lint-skill.sh` still passes 13/13.
- [ ] **Step 2:** `manual`: Yotam enters the URL `http://100.106.37.39:8765/mcp` and the token (`ssh yodem@100.106.37.39 cat dev/web-research/.token`, in his terminal) with `/plugin configure learn-toolkit@learn-toolkit-marketplace`, then runs `/reload-plugins`. The token lands in the keychain, typed by him.
- [ ] **Step 3: Blank and wrong config.**
  - (a) Copy the plugin to a scratch directory under a different plugin name, so no stored userConfig applies. `claude --plugin-dir <scratch copy> -p "Without calling tools, list MCP servers from plugin <name>, one per line, with connected/failed status." < /dev/null` must exit 0. Its output matches `grep -E 'exa: connected'` and `grep -E 'web-research: failed'`.
  - (b) The same copy, with `.mcp.json`'s url and token replaced by the real URL and the literal `wrong`, shows web-research failed or needs authentication.
- [ ] **Step 4: Live behaviour.**
  - After Step 2, run `/learn-toolkit:learn FastAPI dependency injection --no-notebook` in a fresh session.
  - The Phase 0 matrix shows `[Web research ✓]`, and the `packages` subagent's digests include at least one URL from `package_info` or `github_repo`, such as a `pypi.org` or `github.com` URL.
  - The lead reads the saved research file back and quotes that line.
- [ ] **Step 5: Commit** `docs: self-hosted web-research backend`.

Model: `claude-haiku-5-5` for Step 1; lead for Steps 3-4.

## Execution notes

- T1 → T2 run in order: T2 needs T1's files. T3 is independent of T1/T2 (disjoint paths) and runs in parallel with T1. T4 runs after T2 and T3.
- No agent fan-out above 3, so there is no Workflow and no token envelope.
- Gated on Yotam: the Evomi purchase (T2 Step 6), the systemd drop-in (T2 Step 3), plugin configure (T4 Step 2), and any push, merge or PR.
