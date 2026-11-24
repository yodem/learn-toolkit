---
name: learn
description: "Domain-aware deep learning workflow. Researches a subject across Tavily, Exa, keyless Firecrawl, Sefaria and Trove (formerly CandleKeep), plus the self-hosted open-search (web-research) server on every run, with two web-search subagents by default (one for a simple subject, three for a complex one), then optionally builds a NotebookLM package and files findings into a Trove field-research book. Routes by domain: tech, philosophy, judaism. Do NOT use for quick factual lookups or for a single URL — use a direct web search instead."
argument-hint: "<subject> [--domain tech|philosophy|judaism] [--language <code>] [--no-notebook] [--deep[=low|medium|high|xhigh]] [--gemini[=N]]"
allowed-tools: Task, Write, Read, Artifact, Bash(tvly *), Bash(firecrawl *), Bash(uv tool list), Bash(uv tool upgrade tavily-cli), Bash(pipx upgrade tavily-cli), Bash(mktemp *), Bash(python3 *), Bash(trove *), Bash(ck *), Bash(echo *), Bash(mkdir *), Bash(test *), Bash(cat *), Bash(cp *)
metadata:
  author: Yotam Fromm
  version: 2.5.0
  mcp-server: tavily, exa, exa-agent, firecrawl, web-research, notebooklm-mcp
  category: learning
  tags: [research, domains, tavily, exa, firecrawl, sefaria, trove, notebooklm]
---

# Learn Workflow

## Important

`/learn <subject>` routes research across exactly three domains: **tech**, **philosophy**,
**judaism**. The domain is inferred from the subject unless `--domain <domain>` is passed,
in which case the flag always wins. Each domain has a language default —
`tech` → `en`; `philosophy` → `he`; `judaism` → `he` — overridden by `--language <code>`
when present. Do not hardcode a language anywhere in this workflow; always use the
resolved value from Phase 0.5.

NotebookLM notebooks cap at 100 sources. Track the running count in the state file and
overflow to a new notebook before the cap is hit (see
`${CLAUDE_SKILL_DIR}/references/notebooklm-loading.md`).

**Teach basics first.** Everything this workflow shows the user — the synthesis, the
learning page, the final report — runs in one order: **basics → advanced usage →
related research**. Assume the user is new to the subject. Define every term before using
it, say what problem the subject solves before how it works, and give one small concrete
example before any generalization. No numbers, benchmarks, version tables or comparison
grids in the basics; when a number appears later, say in the same sentence what it
measures and why it matters. A table is never the first thing the user sees.

CRITICAL: follow the phases in order. Each phase has a verification gate — do not
proceed until it passes. The **only** hard stop in this entire workflow is zero
available search backends (Phase 0). Every other missing tool — NotebookLM, Trove,
Sefaria, one of the search backends — degrades the run instead of stopping it.

## Instructions

### Phase 0: Discover Available Tools

**Mandatory. Do not skip.**

#### Step 0a: Tavily CLI

```bash
tvly --version 2>/dev/null && echo "TAVILY_CLI=true" || echo "TAVILY_CLI=false"
```

If found, check authentication with `tvly auth --json` and read its `authenticated` field.
`tvly auth` exits 0 even when signed out, so its exit code says nothing; do not use
`tvly --status` either, whose two-part banner drops the auth line when piped:

```bash
tvly auth --json 2>/dev/null | python3 -c "import json,sys; d=json.loads(sys.stdin.read() or '{}'); print('TAVILY_CLI_AUTH=' + ('true' if d.get('authenticated') is True else 'false'))" || echo "TAVILY_CLI_AUTH=false"
```

The CLI ships from npm as `@tavily/cli` (version 1.0 and up, Node.js 20.1+). A version
below 1.0 is the PyPI `tavily-cli`, which is deprecated and frozen at 0.2.2; it still
works (its notice goes to stderr only). Show it in the matrix as `[Tavily CLI ✓ (PyPI, deprecated)]`
and tell the user to switch with `npx @tavily/cli init`, then `uv tool uninstall tavily-cli`; never migrate it yourself.
Below version 0.1.8, which has no `tvly update`, try one upgrade and re-check `tvly --version` once:
`uv tool upgrade tavily-cli` if `uv tool list` shows `tavily-cli`, otherwise `pipx upgrade
tavily-cli`. Never pipe the installer script to a shell. Report it in the matrix as `[Tavily CLI ✓ (upgraded <old>→<new>)]`.
Search and extract work from 0.1.6, so set `HAS_TAVILY_SKILLS=true` whenever `tvly` runs, whether or not the
upgrade worked. Set `HAS_TAVILY_RESEARCH_CLI=true` only at 0.1.8 or newer, because `--deep` needs `tvly research
<query> --citation-format --no-wait`. Set `HAS_TAVILY_CLI_AUTH=true` only when the probe prints `TAVILY_CLI_AUTH=true`; otherwise set it false.

#### Step 0a-2: Firecrawl CLI

```bash
firecrawl --status 2>/dev/null
```

Set `HAS_FIRECRAWL_CLI=true` when the output contains `Authenticated` (a signed-in free
account); otherwise, or when the command is missing, set it false. Never run
`firecrawl login` yourself.

#### Step 0b: MCP backends

Run these `ToolSearch` calls in parallel:

1. `ToolSearch(query="+tavily tavily_search")` — match tools ending in
   `__tavily_search` / `__tavily_extract`.
2. `ToolSearch(query="+exa web_search_advanced_exa")` and
   `ToolSearch(query="agent_run")`. Plugin tools are namespaced
   `mcp__plugin_learn-toolkit_<server>__<tool>`; a user may also have their own server,
   so match by suffix. `HAS_EXA` means a tool ending in `__web_search_advanced_exa`
   exists. `HAS_EXA_AGENT` means a tool ending in `__agent_run` exists on a server
   whose name contains `exa`. Use the full discovered tool names in every subagent prompt.
   This workflow uses `web_search_advanced_exa`, `web_search_exa`, and
   `web_fetch_exa`; it uses `agent_run` only with `--deep`.
3. `ToolSearch(query="+sefaria text search")` — look for
   `mcp__claude_ai_Sefaria__text_search`. Only needed if the domain resolves to
   `judaism`, but cheap to check now alongside the others.
4. `ToolSearch(query="+notebooklm")` — look for `mcp__notebooklm-mcp__notebook_create`,
   `source_add`, `studio_create`, `studio_status`. Also look for `research_start`,
   `research_status` and `research_import`, used only by the `--deep` NotebookLM lane.
5. `ToolSearch(query="batch_crawl_urls stealth_scrape")` — the optional self-hosted
   web-research server; details in `${CLAUDE_SKILL_DIR}/references/web-research.md`. If it
   finds nothing, re-run this one query once after the other probes finish; never retry per subagent.
6. `ToolSearch(query="+firecrawl firecrawl_search")` — the keyless (free tier) Firecrawl
   server; match tools ending in `__firecrawl_search`, `__firecrawl_scrape` and
   `__firecrawl_parse`. Details in `${CLAUDE_SKILL_DIR}/references/firecrawl.md`.
7. `ToolSearch(query="+claude-in-chrome tabs_context")` — match a tool ending in
   `__tabs_context_mcp`. Only matters with `--gemini`.

Also note whether the `Artifact` tool is in your tool list (it is a built-in Claude Code
tool, not an MCP server, so no `ToolSearch` is needed).

Set:
- `HAS_TAVILY_MCP` = true if a tool ending in `__tavily_search` was found.
- `HAS_TAVILY` = true if `HAS_TAVILY_MCP` OR `HAS_TAVILY_SKILLS`.
- `HAS_EXA` = true if a tool ending in `__web_search_advanced_exa` was found.
- `HAS_EXA_AGENT` = true if `agent_run` was found on a server whose name contains `exa`.
  No `__agent_run` but a tool ending in `__authenticate` on a server whose name contains
  `exa-agent` means it needs auth: show `[Exa Agent ✗ (needs auth / Exa key)]`, not "not found".
- `HAS_SEFARIA` = true if `mcp__claude_ai_Sefaria__text_search` was found.
- `HAS_NOTEBOOKLM` = true if the NotebookLM tools were found.
- `HAS_NOTEBOOKLM_RESEARCH` = true if `HAS_NOTEBOOKLM` and the three research tools were found.
- `HAS_ARTIFACT` = true if the `Artifact` tool is available.
- `HAS_WEB_RESEARCH` = true if a tool ending in `__batch_crawl_urls` exists on a server whose name contains `web-research`.
- `HAS_FIRECRAWL_MCP` = true if a tool ending in `__firecrawl_search` was found.
- `HAS_FIRECRAWL` = true if `HAS_FIRECRAWL_MCP` OR `HAS_FIRECRAWL_CLI`.
- `HAS_CHROME` = true if a tool ending in `__tabs_context_mcp` was found.

If a Tavily MCP call returns an error containing `Invalid Tavily API key`, set
`HAS_TAVILY_MCP=false` and continue with the `tvly` CLI if available. Keyless CLI search
and extract work without login; `tvly login` or `tvly init --agent claude-code` enables
full CLI access.

With no `__tavily_search` tool, show `[Tavily MCP ✗ (key rejected or blank: /plugin configure learn-toolkit@learn-toolkit-marketplace)]`.

#### Step 0c: Trove CLI

```bash
if command -v trove >/dev/null 2>&1; then echo "TROVE_CLI=true"
elif command -v ck >/dev/null 2>&1; then echo "TROVE_CLI=legacy"
else echo "TROVE_CLI=false"; fi
```

Set `HAS_TROVE = true` only when `trove` exists. If only the legacy `ck` CLI exists
(`TROVE_CLI=legacy`), report "found the legacy `ck` CLI; install/upgrade to `trove`", set
`HAS_TROVE = false` and treat Trove as unavailable. Missing is not an error.

#### Report the matrix

```
Research backends: [Tavily MCP ✓/✗] [Tavily CLI ✓/✗] [Tavily CLI auth ✓/✗] [Exa ✓/✗] [Exa Agent ✓/✗] [Sefaria ✓/✗] [Trove ✓/✗] [NotebookLM ✓/✗] [NotebookLM research ✓/✗] [Artifact ✓/✗] [Web research ✓/✗] [Firecrawl MCP ✓/✗] [Firecrawl CLI ✓/✗] [Chrome ✓/✗]
```

When `$GEMINI_RUNS` is set, add `(Gemini lane: N runs)` after the Chrome entry.

When `[Web research ✗]` and `/mcp` shows `INVALID_CONFIG`, the URL is blank: that's expected if you don't self-host, so add nothing. Otherwise add: "if you configured it, run `/mcp`; `failed` with `AUTH_HEADER_REJECTED` there means the
token is wrong; re-enter it with `/plugin configure learn-toolkit@learn-toolkit-marketplace`".

**The only hard stop in the workflow:** if `HAS_TAVILY`, `HAS_EXA`, `HAS_FIRECRAWL` and `HAS_WEB_RESEARCH` are all false,
halt before Phase 0.5 (see the Error Recovery table below for the exact directive). Show
setup instructions for every missing backend and end with "Run `/learn-toolkit:learn $ARGUMENTS` again
after fixing the above." Do not fall back to bare `WebSearch`.

**web-research runs on every run.** It is the free open search (SearXNG) on the user's own
server, so its `web` role is dispatched whenever `HAS_WEB_RESEARCH` is true and never counts
toward `$WEB_LANES`. When it is false, print the `[Web research ✗]` note below in bold so the
user sees that the run lost its free lane, then continue.

When `HAS_TAVILY` and `HAS_EXA` are both false, the web lanes come from Firecrawl alone (see
Phase 0.5) plus web-research. A run that then finds nothing at all is stopped by the
Phase 1 verification gate.

If Tavily is missing:
> **Tavily is not connected.**
> **Option A — CLI** (Node.js 20.1+): `curl -fsSL https://cli.tavily.com/install.sh | bash`
> (installs `@tavily/cli` from npm), then `tvly init --agent claude-code` (or `tvly login`).
> **Option B — MCP:** enter your key with `/plugin configure learn-toolkit@learn-toolkit-marketplace`.
> A blank Tavily key leaves the MCP unusable; `/learn` uses the `tvly` CLI (keyless
> search and extract work without login; `tvly login` or `tvly init --agent claude-code`
> enables full access).
> Do not paste your API key in this chat.

> **Exa is not connected.** It works keyless; if it is missing, run `/mcp` and reconnect
> `plugin:learn-toolkit:exa`. To raise rate limits and enable `--deep`, run
> `/plugin configure learn-toolkit@learn-toolkit-marketplace` and enter your Exa key,
> then `/reload-plugins` or restart.

> **Firecrawl is not connected.** It runs on Firecrawl's keyless free tier; if it is
> missing, run `/mcp` and reconnect `plugin:learn-toolkit:firecrawl`. Calls from a VPN
> or proxy may be refused.
> For the signed-in free-account fallback: `npx -y firecrawl-cli@latest init --all --browser`
> and sign in on the website.

Every other backend degrades instead of stopping:
- `HAS_SEFARIA = false` — only matters if the resolved domain is `judaism`; note it in
  the domain announcement and let the web lanes carry more weight.
- `HAS_TROVE = false` — the library subagent and Phase 7 offer are skipped silently.
- `HAS_NOTEBOOKLM = false` — see Phase 3-5.
- `HAS_ARTIFACT = false` — the Phase 6b learning page is still written locally, just not
  published (see Phase 6b).

### Phase 0.5: Resolve Domain

Determine `$DOMAIN`:

1. If `--domain tech|philosophy|judaism` was passed, use it. The flag always wins over
   inference.
2. Otherwise, infer from the subject by matching it against each domain's `## Identity`
   paragraph in `${CLAUDE_SKILL_DIR}/references/domains/<domain>.md`:
   - Software, infrastructure, tooling, languages, frameworks, protocols, AI/ML
     engineering, or anything better answered from documentation/source code/practitioner
     discussion → `tech`.
   - A primary Jewish text (Torah, Talmud, halakha, midrash) is the thing being studied,
     even when the framing is philosophical → `judaism`.
   - Philosophical concepts, arguments, or thinkers answered from argument and secondary
     literature, with no primary Jewish text at the center → `philosophy`.
   - If genuinely ambiguous, default to `tech` and say so plainly in the announcement —
     the user can correct with `--domain`.

Resolve `$LANGUAGE`: `--language <code>` if passed, else the domain default (`tech` →
`en`; `philosophy`/`judaism` → `he`).

Derive `$SUBJECT`: `$ARGUMENTS` with every `--flag value` pair (`--domain <x>`,
`--language <x>`, `--no-notebook`, `--deep`, `--deep=<effort>`, `--gemini`, `--gemini=<N>`) stripped out, leaving only the subject text. This is
the value handed to every subagent in Phase 1 and stored as `"topic"` in the state file
in Phase 2.

Parse deep mode before deriving the subject: bare `--deep` sets `$DEEP_EFFORT=medium`;
`--deep=low|medium|high|xhigh` sets that effort. The effort is only read from the
`--deep=<effort>` form: in `--deep high` the word `high` stays part of the subject. Any other
`--deep=` value prints the allowed values and uses `medium`. Without the flag, leave
`$DEEP_EFFORT` unset.

Parse the Gemini lane the same way: bare `--gemini` sets `$GEMINI_RUNS=1`; `--gemini=N` sets
N for N in 1..3 (any other value prints the allowed values and uses 1). `--gemini` alone
implies deep mode: if `$DEEP_EFFORT` is unset, set it to `medium`. Without the flag, leave
`$GEMINI_RUNS` unset; the Gemini lane never runs without `--gemini`.

Read `${CLAUDE_SKILL_DIR}/references/domains/$DOMAIN.md` in full before doing anything
else — it defines the Phase 1 roster, Source Ranking, Query Patterns, and Output
Settings used by every later phase.

**Size the web lanes.** The web lanes are the Tavily, Exa and Firecrawl subagents; Trove,
Sefaria and web-research are fixed roles and never count. Set `$WEB_LANES`:

- **2 by default.**
- **1** when the subject is simple: one narrow, well-defined term, tool, option or text
  with settled sources (e.g. "Python walrus operator", "what is a CRDT").
- **3** when the subject is complex: it compares two or more technologies or positions,
  spans several subsystems or schools, is an open debate, or `--deep` is set.

Never more than 3. Pick the lanes from the domain file's web-lane order, skipping
backends that are unavailable (`HAS_TAVILY`, `HAS_EXA`, `HAS_FIRECRAWL`); with fewer
available backends than `$WEB_LANES`, run the ones there are. Set `$LANES` to the chosen
backends.

**Announce before spending any research call:**

```
Domain: <name> (inferred|--domain) — <primary sources for this domain, one clause>. Override with --domain.
Web lanes: <n> (<default|simple|complex>: <one-clause reason>) — <backends in $LANES>, plus web-research.
```

Example: `Domain: tech (inferred) — official docs, source repos, practitioner discussion. Override with --domain.`
followed by `Web lanes: 2 (default) — tavily, exa, plus web-research.`

**Verification gate:** domain announced, lane count and backends announced, resolved
language known, domain file read.

### Phase 1: Parallel Research Fan-Out

Dispatch the domain's fixed roles whose backend is available plus one subagent per
backend in `$LANES` **in a single message** (one `Task` call each, all in the same turn —
this is a real fan-out, not a sequence). A query intent of a backend that is not in
`$LANES` moves to the first lane, as the domain file says. For each subagent, hand it:

1. The subject (`$SUBJECT`, derived in Phase 0.5).
2. Its roster entry — role name and which backend/tools it owns, verbatim from the
   domain file.
3. That backend's `## Query Patterns` from the same domain file — the exact query
   shapes, flags, and (for Exa) the "describe the ideal page" framing.
4. The return contract below, reproduced in the subagent's prompt.
5. For a web lane: any query intents moved to it from a backend not in `$LANES`, spelled
   out with their query patterns. For the Firecrawl lane: `HAS_FIRECRAWL_MCP`,
   `HAS_FIRECRAWL_CLI` and the discovered tool names, so it can pick its route.

**Return contract — every subagent returns digests, never raw pages, targeting roughly
1,000-2,000 tokens of distilled findings total (a target to aim for, not a hard count to
enforce):**

```json
[{"url": "...", "title": "...", "kind": "official_docs|tutorial|discussion|library|primary_text|deep_research",
  "why_it_matters": "one sentence", "key_claims": ["...", "..."]}]
```

A subagent that dumps full page text or raw HTML back into the parent context has
failed its contract — tell it explicitly to summarize, not paste. This budget is what
keeps the orchestrator's context clean across a multi-subagent fan-out instead of
accumulating every subagent's raw exploration.

**Token-economy rules — include in every subagent's prompt:**

- Tavily CLI subagents first run `mktemp -d` in its own Bash call and keep the printed
  path as `OUT=<printed path>` (shell variables do not survive between tool calls, so paste the literal
  path into every later command). They run `tvly search … --json -o "$OUT/<name>.json"`
  and read that file through a Python filter (the `tavily-dynamic-search` pattern). Use
  `--depth advanced --chunks-per-source 3` for research and `--depth fast` for quick
  checks. Extract keepers with `tvly extract <url> --query "<subject>"
  --chunks-per-source 3 --json`. A `tvly` exit code 3 means auth: return
  `{"error":"tavily-auth"}` and never run `tvly login`. Without CLI auth, use only
  search and extract; do not use crawl, map, or research. Those additional CLI features
  require authentication.
- Exa subagents use the discovered full tool names ending in
  `__web_search_advanced_exa`, `__web_search_exa`, and `__web_fetch_exa`. Use advanced
  search for targeted queries (category, domains, date filters, highlights with a
  `highlightsQuery`) and regular search for broad checks. On advanced search set `type`:
  `"lite"` for triage and broad checks (cheapest, cached content; it accepts only query,
  numResults, category, domain and published-date filters, userLocation, moderation,
  textMaxCharacters and the highlights fields, and answers HTTP 400 for anything else),
  `"auto"` whenever the call needs `additionalQueries`, `subpages`, summaries or
  `maxAgeHours`. Never use the legacy `fast` or `instant`. Cap highlights with
  `highlightsMaxCharacters` (the sentence and per-URL highlight fields are deprecated).
  Regular search requires an `objective` next to `query`. Triage on highlights, then fetch
  the 3-5 keepers with `maxCharacters: 4000`; request one content view per call. Allowed
  categories: `publication`, `personal site`, `news`, `company`, `people`, and
  financial report. Put recency in query wording; use published-date filters only for
  explicit windows and `maxAgeHours` only when a fresh crawl is needed. Rewrite GitHub
  `/blob/<ref>/` URLs to `raw.githubusercontent.com/<o>/<r>/<ref>/<path>` before fetching.
- Keyless Exa budget: the skill cannot read the Exa key, so whenever `HAS_TAVILY` is false,
  or a rate-limit error was seen in Phase 1 (on re-dispatch), each subagent gets at most 2
  Exa searches plus 3 fetches, prefers web-research `batch_web_search` when `HAS_WEB_RESEARCH`,
  and says so in its digest.
- Firecrawl subagents (only when `firecrawl` is in `$LANES`) follow
  `${CLAUDE_SKILL_DIR}/references/firecrawl.md`: MCP on the keyless free tier, or the
  signed-in CLI when the MCP is missing or refused; either way at most 2
  `firecrawl_search` calls and 3 `firecrawl_scrape` calls (on its own search results) per subagent, markdown only,
  main content only; digests only. On a keyless limit or refusal (`KEYLESS_*`, 403,
  429, "daily limit") switch to the CLI when `HAS_FIRECRAWL_CLI` (the same budget, counted
  across both routes); otherwise, or when the CLI also fails or is out of credits, stop
  calling Firecrawl and return what you have.
- web-research subagents (only when `HAS_WEB_RESEARCH`) follow
  `${CLAUDE_SKILL_DIR}/references/web-research.md`: one batch call per lane, digests only.
- Sefaria subagents (domain `judaism` only) resolve the topic to a citation first, then
  pull commentary chains — never substitute open-web search for the primary text.
- Trove `library` subagents follow
  `${CLAUDE_SKILL_DIR}/references/trove-integration.md` — `trove items list --json`,
  match up to 3 items by topic keywords, `trove items toc` then `trove items read` for the
  relevant pages, and return the same digest contract (`kind: "library"`).

**Verification gate:** every dispatched subagent returned at least one digest entry, and
combined the roster produced at least 5 unique URLs/sources. If not, run **one** recovery
round, then proceed. If the whole roster (Sefaria and Trove included) still returned zero
sources after it, stop with the Phase 0 setup instructions instead of synthesizing from
nothing; if only the web side came back empty, continue on the primary and library
sources with a one-line degraded-web notice.

1. A web lane that failed or came back empty is replaced by the next available backend
   not in `$LANES` (domain order): update `$LANES` to swap it in first, then dispatch it
   with that lane's query intents and the handoff items above.
2. Otherwise (no lane failed, or no spare backend), re-dispatch the weakest subagent once
   with a broadened query.
   A lane whose backend was refused (for Firecrawl: both MCP and CLI routes) is never
   re-dispatched in the same run; pick the weakest of the other subagents instead.
 Report the fan-out as `k of N subagents returned`
in the final report, naming any lane that was refused or empty.

### Deep research (only with --deep)

This is Phase 1b; it runs after the regular search fan-out.

Skip silently unless `$DEEP_EFFORT` is set. If `HAS_EXA_AGENT` is false and
`HAS_TAVILY_RESEARCH_CLI` and `HAS_TAVILY_CLI_AUTH` are both true, use the CLI fallback.
`--output-schema` takes a file path, not inline JSON: run `mktemp -d`, Write the
outputSchema below to `<that dir>/schema.json`, then run
`tvly research "<question>" --model pro --citation-format numbered --no-wait
--output-schema <that dir>/schema.json --json`. Then make one blocking call,
`tvly research poll <request_id> --poll-interval 30 --timeout 300 --json` (Bash timeout
330000 ms); it polls on its own until `completed` or `failed`. If its JSON status is
timeout, report the request ID and continue without deep results.
If `HAS_EXA_AGENT` is false and the authenticated Tavily CLI fallback is unavailable,
print one notice: `--deep` needs an Exa key — run
`/plugin configure learn-toolkit@learn-toolkit-marketplace`, then continue.

Otherwise dispatch one deep subagent using the discovered `agent_run` tool. Its concrete
question is: “What are the core concepts, current best practices and open debates in
<subject>, as explained by <domain primary sources>?” Set `effort` to `$DEEP_EFFORT` and
`systemPrompt` to the domain's `## Source Ranking` line followed by “prefer primary and
official sources; every claim must be supported by a cited page; answer in <$LANGUAGE>”.
Set `outputSchema` to:

```json
{"type":"object","required":["basics","findings","open_questions"],"properties":{"basics":{"type":"string","description":"what it is and the problem it solves, for a newcomer"},"findings":{"type":"array","items":{"type":"object","required":["claim","why_it_matters"],"properties":{"claim":{"type":"string"},"why_it_matters":{"type":"string"}}}},"open_questions":{"type":"array","items":{"type":"string"}}}}
```

If `agent_run` returns `status: "running"` with an `id`, call it again with
the run ID as the `runId` argument (at most 6 re-calls). Read `output` only when status
is `completed`.
On `failed`, `cancelled`, or the poll cap, report the degraded run in the matrix and
continue without deep results. Map each finding to a `deep_research` digest. For Exa,
take its URLs from `output.grounding[].citations[]` for that field; for Tavily, take them
from the response's `sources[]`. Drop a finding only when the run returned no citations or
sources at all. Keep the run ID as `DEEP_RUN_ID=<run id>`; Phase 2 writes it to the state file as
`deep_run_id`, and a follow-up deep run may pass it as `previousRunId`.

#### NotebookLM Deep Research

Runs after the Exa/Tavily deep run, in the same Phase 1b, only when `$DEEP_EFFORT` is set,
`HAS_NOTEBOOKLM_RESEARCH` is true and `--no-notebook` was not passed. It creates the topic
notebook `[Topic] - Core Learning` early and records it in the state file's `notebooks[]`.
It then runs three scoped NotebookLM Deep Research jobs one after another (core concepts,
best practices, debates and failure modes), imports each report plus its top 12 sources
under the 98-source budget, and reads each report back as `deep_research` digests for
Phase 2. A failed, timed-out or quota-limited job is recorded in the state key
`notebooklm_research` and skipped; the run never stops. Follow
`${CLAUDE_SKILL_DIR}/references/notebooklm-deep-research.md`.

#### Gemini app Deep Research (only with --gemini)

Runs after the NotebookLM lane, in the same Phase 1b, only when `$GEMINI_RUNS` is set and
`HAS_CHROME` is true. Google Support has told users that automating the Gemini app is not
permitted, and the lane drives the user's signed-in Google account, so it is opt-in only.
Through Claude in Chrome it opens a new tab, starts Gemini Deep Research and runs up to
`$GEMINI_RUNS` reports strictly one at a time (concurrent runs fail). Each report can take
up to 60 minutes; past that it is recorded as `running` with its chat URL and skipped. Each
finished report is saved under `~/dev/learn-research/learn-<topic-slug>/gemini-reports/`,
added to the notebook as a text source, and distilled into `deep_research` digests for
Phase 2. With `--no-notebook` or no NotebookLM, reports stay local and still feed the
digests. State goes in `gemini_research`. A failed step is recorded and the run continues.
Follow `${CLAUDE_SKILL_DIR}/references/gemini-deep-research.md`.

### Phase 2: Merge and Synthesize

1. Collect every subagent's digest array. Deduplicate by URL (library/primary-text
   entries dedupe by id instead).
2. Rank by the resolved domain's `## Source Ranking` order. A `deep_research` entry takes
   the tier of its cited source; when that is unclear, rank it just below the domain's
   first tier. Digests from the NotebookLM Deep Research lane merge with the other
   `deep_research` entries.
3. Write a synthesis of at least ~500 words (~3000 characters — the validation hook
   warns below 2500), drawing only from the digests' `why_it_matters` and `key_claims`,
   not from re-fetching pages. It has one section per tier of the
   resolved domain's `## Output Settings` → Learning ladder line, in this order:
   - A `## Basics` section — what the subject is, the problem it solves, the core terms (each
     defined in plain words), one mental model, one minimal example. No numbers or
     tables.
   - A `## Advanced usage` section — how it is used in depth: patterns, tradeoffs, pitfalls, edge
     cases, building only on terms the Basics already defined.
   - A `## Related research` section — what the sources add: the strongest sources and their key
     claims, where they disagree, open questions.
4. Save the workflow state file. The validation hook requires five keys — `topic`,
   `domain`, `notebooks`, `total_sources`, `local_path` — and rejects the file if any is
   missing. Also write a sixth top-level key, `candlekeep` (`read_ids`, `write_id`; the key keeps its
   legacy name because it is persisted on disk): the
   hook ignores it, but Phase 7 reads and updates `candlekeep.write_id` when filing
   findings, so it must be present from the start. When Phase 1b already wrote the file
(either the NotebookLM or the Gemini lane), Read it and write it back with these keys, keeping its
`notebooks`, `total_sources`, `notebooklm_research` and `gemini_research` values; never overwrite them with empty values. Also write
`notebooklm_research` and `gemini_research` (lists, empty when that lane did not run) and
`deep_run_id`:

```bash
echo "{\"topic\":\"$SUBJECT\",\"domain\":\"$DOMAIN\",\"notebooks\":[],\"total_sources\":0,\"candlekeep\":{\"read_ids\":[],\"write_id\":null},\"deep_run_id\":\"${DEEP_RUN_ID:-}\",\"notebooklm_research\":[],\"gemini_research\":[],\"local_path\":\"$HOME/dev/learn-research/learn-$TOPIC_SLUG/\"}" > "/tmp/learn-workflow-state-$TOPIC_SLUG.json"
```

`$TOPIC_SLUG` is the subject lowercased, spaces to hyphens, special characters removed.

**Verification gate:** state file written with the 5 hook-required keys plus `candlekeep`; synthesis has
the three sections in basics → advanced → research order and is ≥2500 characters.

### Phase 2.5: Save Local Files

**Always runs**, regardless of domain or backend availability. Output goes to
`$HOME/dev/learn-research/learn-<topic-slug>/` — **never `/tmp`**, which is not the
canonical location for this workflow's durable output.

```bash
mkdir -p "$HOME/dev/learn-research/learn-$TOPIC_SLUG"
```

```
$HOME/dev/learn-research/learn-<topic-slug>/
  README.md              — index with TOC, metadata, domain, date
  research-summary.md    — the Phase 2 synthesis (basics → advanced → research)
  learning-page.html     — the Phase 6b learning page
  sources/
    01-primary.md        — official docs, or Sefaria text, per domain
    02-library.md        — Trove sources
    03-community.md      — discussion and practitioner sources
    04-articles.md
```

Each source file entry carries: URL or source identifier, title, backend, `kind`, and
the `why_it_matters` / `key_claims` from its digest. `01-primary.md` holds whichever the
resolved domain ranks first (official docs for `tech`, primary texts for `philosophy`,
Sefaria text for `judaism`).

Report the path to the user: `"Research saved to ~/dev/learn-research/learn-<topic-slug>/"`.

**Verification gate:** directory exists, `README.md` and `research-summary.md` exist,
`sources/` has at least one populated file.

### Phase 3-5: NotebookLM (optional)

Phases 3, 4, and 5 are **one unit**. They skip together, with a single notice, when
either is true:

- `HAS_NOTEBOOKLM` is false (Phase 0), or
- `--no-notebook` was passed.

When skipped, emit exactly:

> NotebookLM not available — skipping the notebook package. Research, local files and
> the Trove offer are unaffected.

Omit the NotebookLM notebook and NotebookLM artifact tables from the final report and continue straight to
Phase 6. **Never stop the workflow because NotebookLM is missing or skipped.**

When available, consult `${CLAUDE_SKILL_DIR}/references/notebooklm-loading.md` for
notebook-creation strategy, source-addition patterns, and the 98-source overflow
threshold (read `notebooks[-1]` from the topic-scoped state file, not the old unscoped
path), and `${CLAUDE_SKILL_DIR}/references/artifact-generation.md` for exact tool-call
signatures.

**Phase 3 — Load into NotebookLM:**
1. Create notebook `[Topic] - Core Learning`, unless Phase 1b already created it (either lane; `notebooks[-1]` in the state file) — then reuse it and keep counting from `total_sources`.
2. Add Trove sources first (`wait=false`, title `"Library: [Item Title]"`) if any.
3. Add remaining URL/primary-text sources (`wait=false`).
4. Add the research summary as a text source (`wait=true`).
5. Update the state file's `notebooks[]` and `total_sources` after each addition.
6. Overflow to a new notebook when the running count reaches 98.

**Phase 4 — Generate Artifacts:** create podcast, infographic, mind map, flashcards, and
study guide in parallel (`confirm=true` on each), all using
`language=<resolved domain language>` from Phase 0.5 — never a hardcoded value. The
podcast's, infographic's, and study guide's `focus_prompt` each follow the resolved
domain's `## Output Settings` → NotebookLM artifact focus line (implementation-oriented
for `tech`; argument structure for `philosophy`; text-and-commentary for `judaism`) —
never send the `tech`-framed brief to another domain. See the domain-adapted brief
tables in `artifact-generation.md`.

**Phase 5 — Poll and Report:** poll `studio_status` every 30 seconds (max 10 polls / 5
minutes) until every artifact is `completed` or `failed`.

**Verification gate (when this unit runs):** all `studio_create` calls returned artifact
IDs; polling ends with every artifact reported `completed` or `failed`, never left
`in_progress` in the final summary.

### Phase 6: Companion Visuals

#### 6a: ASCII Diagram — always

Using the Phase 2 synthesis, render an ASCII diagram inline in the terminal that explains
the **basics** — how the core pieces relate or how one thing flows through them. Prefer
a concept map, flowchart or architecture sketch over a comparison table. Unicode
box-drawing characters, width under 100 chars.

#### 6b: Learning Page — Artifact, every domain

Build one HTML learning page from the Phase 2 synthesis and the ranked digests, and
publish it as a Claude Code Artifact. Do not delegate to any other HTML-generating skill.

**Before writing**, call `Artifact` with `action: "quickstart"` and `intent: "other"`, and
follow the design contract it returns (title, theming, libraries, layout). Do not
re-specify those rules here.

**Page structure — three sections, in this order, never reordered:**

1. **Basics** — open with two or three sentences a newcomer can follow: what the subject
   is and what problem it solves. Then the core terms as a short glossary (each defined in
   plain words before any later section uses it), one mental model or analogy, the 6a
   diagram redrawn as inline SVG or HTML, and one minimal worked example. No numbers,
   benchmarks or tables here.
2. **Advanced usage** — patterns, tradeoffs, pitfalls and edge cases, each tied back to a
   term from the Basics. A table is allowed here only after the prose that explains
   what it compares; every number states what it measures and why it matters.
3. **Related research** — the ranked sources (title linked to URL or citation, its
   `kind`, one line on why it matters, its key claims), where sources disagree, and open
   questions to explore next.

Add a short contents list at the top linking the three sections. What each tier means
for this subject comes from the resolved domain's `## Output Settings` → Learning ladder
line.
Write the page in `$LANGUAGE`. The publish step supplies the `<html>`/`<head>`/`<body>`
skeleton, so for a right-to-left language (`he`) put `lang="he" dir="rtl"` on the page's
outermost wrapper element instead of on `<html>`.

**Write, then publish:**

1. Write the page to `$HOME/dev/learn-research/learn-$TOPIC_SLUG/learning-page.html` —
   the durable copy, kept whatever happens next.
2. If `HAS_ARTIFACT`: publish it with `Artifact` (`file_path` set to that file, an
   `icon` such as `book`, a one-sentence `description`). If the publish is refused
   because the file is outside the allowed directories, copy it into the session
   scratchpad directory and publish that copy instead.
3. If `HAS_ARTIFACT` is false or the publish fails, keep the local file and report its
   path — never stop the workflow over it.

**Verification gate:** 6a produced a rendered diagram. 6b wrote `learning-page.html` with
the three sections in order and either published it (artifact URL in hand) or reported
the local path with the reason it was not published.

### Phase 7: Trove Field Research Offer

**Condition:** `HAS_TROVE = true`. Otherwise skip silently.

Follow `${CLAUDE_SKILL_DIR}/references/trove-integration.md` → `## Field Research
Offer (Phase 7)` exactly: run the format-tolerant existence check, create + enrich the
book at creation if none exists, then interactively ask the user:

> **Would you like to file today's findings into your Trove field-research book on
> this topic?**

If yes: compose the dated entry per `## Entry Format` in that reference (one H1 per
page, `#` escaped inside any fence, subject/domain/sources/findings/open-questions),
append with `trove items append <book-id> --file <path> --no-session`, then verify with
`trove items read "<book-id>:<n>" --no-session` — **never** by trusting the append
command's own log output. Update the state file's `candlekeep.write_id`.

If the append or readback fails, report it plainly and leave the local entry file in
place — do not silently drop the finding.

If the user declines, skip without writing anything.

**Verification gate:** either skipped silently (`HAS_TROVE = false`), declined by
the user, or a successful append confirmed by read-back.

### Final Report

Open the final message with three to five plain sentences that teach the basics: what
the subject is, the problem it solves and the one idea to hold onto. Then the artifact
link (or the local `learning-page.html` path), then the local research path. Status
tables (backends, notebooks, NotebookLM artifacts) come last, after the explanation —
never first.

The run's state file is intentionally left in place after the final report — deleting it
is not this skill's job, and `rm` is deliberately not in `allowed-tools`. The state file
is disposable: the plugin's `verify-artifacts.sh` Stop hook reaps any state file older
than 12 hours automatically on a later turn, so a finished run's file never lingers
indefinitely or produces a false stale-state warning.

## Examples

### Example 1 — tech, full package

`/learn-toolkit:learn Next.js App Router`

1. Phase 0: Tavily MCP ✓, Exa ✓, Exa Agent ✓, Trove ✓, NotebookLM ✓, Artifact ✓.
2. Phase 0.5: no `--domain` given → inferred `tech` (documentation/framework subject).
   Announces `Domain: tech (inferred) — official docs, source repos, practitioner
   discussion. Override with --domain.` Language resolves to `en`.
3. Phase 0.5 also announces `Web lanes: 2 (default) — tavily, exa, plus web-research.`
   Phase 1 dispatches `tavily`, `exa`, `library` and `web` from `domains/tech.md` in one
   message.
4. Phase 2: merges digests, ranks official docs > repos > library > discussion, writes
   the synthesis (Basics: what a router is and why the App Router replaced pages;
   Advanced: server components, caching, pitfalls; Related research), saves state file
   with `"domain":"tech"`.
5. Phase 2.5: saves to `~/dev/learn-research/learn-nextjs-app-router/`.
6. Phase 3-5: creates notebook, generates 5 artifacts in `en`.
7. Phase 6a: ASCII diagram of how a URL maps to folders in the App Router. Phase 6b:
   learning page published as an Artifact — basics of file-based routing first, then
   layouts/caching/streaming, then the ranked sources.
8. Phase 7: offers to file findings into a `Field Research — Next.js App Router` book.

### Example 2 — judaism, primary-text-first

`/learn-toolkit:learn hilchot shabbat candle lighting --domain judaism`

1. Phase 0: Tavily ✓, Sefaria ✓, Trove ✓, NotebookLM ✗ (not configured).
2. Phase 0.5: `--domain judaism` given, so inference is skipped. Language resolves to
   `he` (domain default, no `--language` override). Announces
   `Domain: judaism (--domain) — Sefaria primary text, classical commentators,
   library. Override with --domain.`
3. Phase 0.5 sizes it simple (one well-defined halakhic topic): `Web lanes: 1 (simple)
   — exa, plus web-research.` Phase 1 dispatches `primary` (Sefaria), `library` (Trove),
   `web` and the one `exa` lane — Sefaria resolves the citation first before the
   secondary lanes run their contextualizing search.
4. Phase 2: ranks primary text > commentators > library > academic scholarship >
   shiurim; synthesis in Hebrew framing.
5. Phase 2.5: local files saved; `01-primary.md` holds the Sefaria text and commentary
   chain.
6. Phase 3-5: **skipped** — single notice printed: "NotebookLM not available — skipping
   the notebook package. Research, local files and the Trove offer are
   unaffected." No notebook/artifact tables in the final report.
7. Phase 6a: ASCII diagram of the sugya structure. Phase 6b: Hebrew RTL learning page —
   the text and its plain meaning first, then the commentators and halakhic positions,
   then scholarship.
8. Phase 7: offers to file findings into a Trove field-research book.

### Example 3 — philosophy, degraded search

`/learn-toolkit:learn the Ship of Theseus and personal identity`

1. Phase 0: Tavily ✗ (not configured), Exa ✓, Trove ✓, NotebookLM ✓. Since at
   least one search backend (Exa) is available, the workflow proceeds — only zero
   backends stops it.
2. Phase 0.5: inferred `philosophy` (argument/thinker subject, no primary Jewish text).
   Language resolves to `he`.
3. Phase 0.5: two lanes by default; Tavily is missing, so `$LANES` is `exa, firecrawl`.
   The Tavily overview intent (SEP, IEP) moves to the `exa` lane. Phase 1 dispatches
   `exa`, `firecrawl`, `library` (Trove) and `web`.
4. Phase 2 onward proceeds normally; Phase 6b's learning page opens with the puzzle and
   its terms (identity, persistence), then the positions and objections, then the
   literature.

### Example 4 — tech, deep research with a blank Exa key

`/learn-toolkit:learn WebAssembly component model --deep`

1. Phase 0: Exa search ✓, Exa Agent ✗, Tavily CLI ✓, Tavily CLI auth ✓.
2. Phase 1 runs normal search. Phase 1b uses Tavily research with numbered citations,
   polls the request to completion, and keeps cited findings in the digest.

### Example 5 — tech, deep research plus two Gemini reports

`/learn-toolkit:learn agent harness engineering --deep --gemini=2`

1. Phase 0: Chrome ✓ (Claude in Chrome connected), so `HAS_CHROME` is true. Phase 0.5
   sets `$DEEP_EFFORT=medium` and `$GEMINI_RUNS=2`; the subject is "agent harness
   engineering".
2. Phase 1b runs the Exa/Tavily deep run and the NotebookLM lane, then the Gemini lane:
   run 1 (architecture and core concepts) finishes and is saved as `01-<slug>.md`; run 2
   (verification, quality and evaluation) starts only after that.
3. Each report is added to the notebook as a text source and distilled into digests;
   `gemini_research` records both runs. If run 2 still shows "Creating your report" after
   60 minutes, it is recorded as `running` with its chat URL and the run moves on.

## Error Recovery

| Error | Cause | Action |
|-------|-------|--------|
| Tavily, Exa, Firecrawl and web-research all unavailable | No Tavily MCP or CLI, no Exa, no Firecrawl, no web-research server | **STOP workflow.** Show setup instructions for each missing backend. Do not fall back to bare `WebSearch`. This is the only stop condition in the workflow |
| Tavily CLI not authenticated (`tvly auth --json` shows `"authenticated": false`) | Not logged in | Set `HAS_TAVILY_CLI_AUTH=false`; keep `HAS_TAVILY_SKILLS=true` for search and extract, and ask the user to run `tvly login` for full CLI access |
| Tavily MCP returns `Invalid Tavily API key` | Tavily key is blank or invalid | Set `HAS_TAVILY_MCP=false`; use `tvly` CLI (keyless search and extract work without login; `tvly login` or `tvly init --agent claude-code` enables full access), or enter the key with `/plugin configure learn-toolkit@learn-toolkit-marketplace` |
| web-research `failed` with `AUTH_HEADER_REJECTED` (401) | Token is wrong or blank | `HAS_WEB_RESEARCH=false`; continue on Tavily/Exa; tell the user to re-enter it with `/plugin configure learn-toolkit@learn-toolkit-marketplace` |
| web-research unreachable | Tailnet down or server stopped | `HAS_WEB_RESEARCH=false`; continue on the other backends |
| web-research returns zero results | Search engines blocked or empty | Treat as a failed lane; lean on Tavily and Exa |
| Firecrawl keyless call refused (`KEYLESS_*`, 403 or 429, "daily limit") | Free-tier rate limit, or a VPN/proxy network it does not accept | Switch the lane to the signed-in CLI when `HAS_FIRECRAWL_CLI`; drop the lane only when the CLI is unavailable, fails or is out of credits. Continue on the other backends and mention it once in the final report |
| Firecrawl MCP not found | Not connected | `/mcp` reconnect `plugin:learn-toolkit:firecrawl`; no key needed. Continue on the other backends |
| Exa MCP not found | Not connected | `/mcp` reconnect; key optional. Proceed on Tavily alone if available |
| Tavily MCP fails at connect with HTTP 401 `AUTH_HEADER_REJECTED` ("Server rejected the configured Authorization header") | `tavily_api_key` stale, or blank (Tavily then asks for OAuth, which the plugin cannot complete) | `HAS_TAVILY_MCP=false`; continue on the `tvly` CLI; tell the user to re-enter the key with `/plugin configure learn-toolkit@learn-toolkit-marketplace` |
| Exa rate-limit or HTTP 429 error | Keyless Exa throttled by the parallel fan-out | After the fan-out, re-dispatch the starved subagent once, serially, under the keyless Exa budget; tell the user to add an Exa key with `/plugin configure learn-toolkit@learn-toolkit-marketplace` |
| `agent_run` connection returns 401 | Exa key is blank | `--deep` uses Tavily research or is skipped |
| `agent_run` still running after 6 re-calls | Long-running job | Report the run ID and continue without deep results |
| tvly exits 3 | Authentication required, keyless rate-limit cap, or plan limit | Set HAS_TAVILY_CLI_AUTH=false, continue with search and extract only, and tell the user to run tvly login themselves |
| Sefaria MCP not found (domain=judaism) | Not configured | Note in the domain announcement; the web lanes carry more weight; continue |
| NotebookLM not found, or `--no-notebook` passed | Not configured / user opted out | Skip phases 3-5, continue. Emit the single skip notice, omit notebook/artifact tables, proceed to Phase 6 |
| NotebookLM auth expired | Token expired | `nlm` is not in `allowed-tools` and login is a credential action — ask the user to run `nlm login` themselves (in Claude Code they can type `! nlm login` so the output lands in-session); once they confirm it succeeded, retry once |
| NotebookLM research tools not found | Older `notebooklm-mcp` without `research_*` | `HAS_NOTEBOOKLM_RESEARCH=false`; skip the NotebookLM Deep Research lane, continue |
| NotebookLM research job failed or timed out | Job `failed`, or no `completed` after ~15 min | Record the status in `notebooklm_research`, skip that job, continue |
| NotebookLM research quota or rate limit hit | Daily Deep Research limit | Record it in `notebooklm_research`, skip the remaining jobs, continue |
| NotebookLM research import would pass 98 sources | `98 - total_sources` is smaller than the planned import | Trim the source indices to fit; at budget 0 create the overflow notebook first, then import |
| `--gemini` passed but Claude in Chrome is not connected | No `__tabs_context_mcp` tool | `HAS_CHROME=false`; skip the Gemini lane, tell the user to connect Claude in Chrome, continue |
| Gemini shows an error or hangs | "Something went wrong", stuck on "Generating research plan" | Record it in `gemini_research`, retry that run once serially, then skip that run and continue with the next |
| Gemini "Deep research" menu item not found | UI changed | Stop the whole lane after 2-3 attempts, note the UI may have changed (fix in `gemini-deep-research.md`), continue |
| Gemini report still creating after 60 minutes | Long-running report | Record the chat URL with status `running`, continue |
| Signed out of Google in the Gemini tab | No session | Ask the user to sign in themselves; never type credentials; skip the lane if they do not |
| Source add fails for one URL | Blocked or invalid URL | Log it, skip it, continue with remaining sources |
| Notebook source count reaches 98 | Cap approaching | Create overflow notebook per `notebooklm-loading.md`, continue |
| Studio artifact generation fails | NotebookLM internal error | Retry once; if it still fails, report "Failed" in the summary table |
| `Artifact` tool unavailable, or the publish is refused | Not Claude Code, or the file is outside the allowed directories | Copy `learning-page.html` to the scratchpad and retry once; otherwise keep the local file, report its path and the reason, continue |
| State file write fails | `/tmp` permission issue | Continue without state tracking; keep counts in-memory for this run |
| `trove` not found | CLI not installed | `HAS_TROVE=false`; skip library subagent and Phase 7 silently |
| `trove items list` fails | Auth issue | Warn once, set `HAS_TROVE=false`, continue |
| `trove items read` fails for one item | Bad item id | Skip that item, continue with the rest |
| `trove items append` succeeds but the log looks like it failed (`BadRecordMac`) | TLS response-stream error, write may still have landed | Never trust the log — verify with `trove items read "<book-id>:<n>"`. Report actual state from the readback |
| `trove items create`/`append` genuinely fails | Permission or network issue | Warn, leave the local entry file in `~/dev/learn-research/learn-<topic-slug>/`, do not drop the finding |
