---
name: learn-toolkit:learn
description: "Domain-aware deep learning workflow. Researches a subject across Tavily, Exa, Sefaria and CandleKeep with one subagent per backend, then optionally builds a NotebookLM package and files findings into a CandleKeep field-research book. Routes by domain: tech, philosophy, judaism. Do NOT use for quick factual lookups or for a single URL — use a direct web search instead."
argument-hint: "<subject> [--domain tech|philosophy|judaism] [--language <code>] [--no-notebook]"
allowed-tools: Task, Write, Read, Bash(tvly *), Bash(ck *), Bash(echo *), Bash(mkdir *), Bash(test *), Bash(cat *), Bash(cp *)
metadata:
  author: Yotam Fromm
  version: 2.0.0
  mcp-server: tavily, exa, notebooklm-mcp
  category: learning
  tags: [research, domains, tavily, exa, sefaria, candlekeep, notebooklm]
---

# Learn Workflow

## Important

`/learn <subject>` routes research across exactly three domains: **tech**, **philosophy**,
**judaism**. The domain is inferred from the subject unless `--domain <domain>` is passed,
in which case the flag always wins. Each domain has a language default —
`tech` → `en`; `philosophy` → `he`; `judaism` → `he` — overridden by `--language <code>`
when present. Do not hardcode a language anywhere in this workflow; always use the
resolved value from Phase 0.5.

NotebookLM notebooks cap at 50 sources. Track the running count in the state file and
overflow to a new notebook before the cap is hit (see
`${CLAUDE_SKILL_DIR}/references/notebooklm-loading.md`).

CRITICAL: follow the phases in order. Each phase has a verification gate — do not
proceed until it passes. The **only** hard stop in this entire workflow is zero
available search backends (Phase 0). Every other missing tool — NotebookLM, CandleKeep,
Sefaria, one of the two search backends — degrades the run instead of stopping it.

## Instructions

### Phase 0: Discover Available Tools

**Mandatory. Do not skip.**

#### Step 0a: Tavily CLI

```bash
tvly --version 2>/dev/null && echo "TAVILY_CLI=true" || echo "TAVILY_CLI=false"
```

If found, check authentication with `tvly auth` — **not** `tvly --status`, whose
two-part banner drops the auth line when piped through `head` and gives a false
negative:

```bash
tvly auth 2>/dev/null && echo "TAVILY_CLI_AUTH=true" || echo "TAVILY_CLI_AUTH=false"
```

Set `HAS_TAVILY_SKILLS = true` only if both checks pass.

#### Step 0b: MCP backends

Run these `ToolSearch` calls in parallel:

1. `ToolSearch(query="+tavily search")` — look for `mcp__tavily__tavily_search` /
   `mcp__tavily__tavily_extract`.
2. `ToolSearch(query="+exa search")` — look for `mcp__exa__web_search_advanced_exa` and
   `mcp__exa__get_code_context_exa`. These are the only two Exa tools this workflow
   uses; do not probe for or fall back to any other Exa crawling or multi-step research
   tool.
3. `ToolSearch(query="+sefaria text search")` — look for
   `mcp__claude_ai_Sefaria__text_search`. Only needed if the domain resolves to
   `judaism`, but cheap to check now alongside the others.
4. `ToolSearch(query="+notebooklm")` — look for `mcp__notebooklm-mcp__notebook_create`,
   `source_add`, `studio_create`, `studio_status`.

Set:
- `HAS_TAVILY_MCP` = true if `mcp__tavily__tavily_search` was found.
- `HAS_TAVILY` = true if `HAS_TAVILY_MCP` OR `HAS_TAVILY_SKILLS`.
- `HAS_EXA` = true if `mcp__exa__web_search_advanced_exa` was found.
- `HAS_SEFARIA` = true if `mcp__claude_ai_Sefaria__text_search` was found.
- `HAS_NOTEBOOKLM` = true if the NotebookLM tools were found.

#### Step 0c: CandleKeep CLI

```bash
ck --version 2>/dev/null && echo "CK_CLI=true" || echo "CK_CLI=false"
```

Set `HAS_CANDLEKEEP`. Missing is not an error.

#### Report the matrix

```
Research backends: [Tavily MCP ✓/✗] [Tavily CLI ✓/✗] [Exa ✓/✗] [Sefaria ✓/✗] [CandleKeep ✓/✗] [NotebookLM ✓/✗]
```

**The only hard stop in the workflow:** if `HAS_TAVILY` is false AND `HAS_EXA` is false,
halt before Phase 0.5 (see the Error Recovery table below for the exact directive). Show
setup instructions for both and end with "Run `/learn-toolkit:learn $ARGUMENTS` again
after fixing the above." Do not fall back to bare `WebSearch`.

If Tavily is missing:
> **Tavily is not connected.**
> **Option A — CLI:** `curl -fsSL https://cli.tavily.com/install.sh | bash`, then
> `tvly login` (or `tvly login --api-key tvly-YOUR_KEY`).
> **Option B — MCP:** get a key at https://tavily.com, `export TAVILY_API_KEY="..."` in
> your shell rc file, `source` it, then restart Claude Code.
> Do not paste your API key in this chat.

If Exa is missing, check `[ -n "$EXA_API_KEY" ]` first: if set, tell the user to restart
Claude Code (the MCP server loads keys at startup); if unset, point to https://exa.ai and
the same env-var + restart flow.

Every other backend degrades instead of stopping:
- `HAS_SEFARIA = false` — only matters if the resolved domain is `judaism`; note it in
  the domain announcement and let the `judaism` roster's `secondary` subagent (Tavily/Exa)
  carry more weight.
- `HAS_CANDLEKEEP = false` — the library subagent and Phase 7 offer are skipped silently.
- `HAS_NOTEBOOKLM = false` — see Phase 3-5.

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

Read `${CLAUDE_SKILL_DIR}/references/domains/$DOMAIN.md` in full before doing anything
else — it defines the Phase 1 roster, Source Ranking, Query Patterns, and Output
Settings used by every later phase.

**Announce before spending any research call:**

```
Domain: <name> (inferred|--domain) — <primary sources for this domain, one clause>. Override with --domain.
```

Example: `Domain: tech (inferred) — official docs, source repos, practitioner discussion. Override with --domain.`

**Verification gate:** domain announced, resolved language known, domain file read.

### Phase 1: Parallel Research Fan-Out

Dispatch every subagent in the resolved domain's `## Subagent Roster` **in a single
message** (one `Task` call per roster entry, all in the same turn — this is a real
fan-out, not a sequence). For each subagent, hand it:

1. The subject (`$ARGUMENTS`, minus flags).
2. Its roster entry — role name and which backend/tools it owns, verbatim from the
   domain file.
3. That backend's `## Query Patterns` from the same domain file — the exact query
   shapes, flags, and (for Exa) the "describe the ideal page" framing.
4. The return contract below, reproduced in the subagent's prompt.

**Return contract — every subagent returns digests, never raw pages:**

```json
[{"url": "...", "title": "...", "kind": "official_docs|tutorial|discussion|library|primary_text",
  "why_it_matters": "one sentence", "key_claims": ["...", "..."]}]
```

A subagent that dumps full page text or raw HTML back into the parent context has
failed its contract — tell it explicitly to summarize, not paste.

**Token-economy rules — include in every subagent's prompt:**

- Tavily subagents MUST pipe `tvly --json` output through Python (the
  `tavily-dynamic-search` pattern) so raw HTML never enters context. Never call bare
  `tvly` without `--json` piped through a filter.
- Exa subagents use exactly `mcp__exa__web_search_advanced_exa` and
  `mcp__exa__get_code_context_exa` — no other Exa tool is part of this workflow, and a
  subagent must not fall back to one it happens to find via its own `ToolSearch`. They
  have no pipe to interpose, so use `highlights` first to triage every result cheaply,
  then call `text` with an explicit `maxCharacters` only for the 3-5 keepers worth full
  content.
- Sefaria subagents (domain `judaism` only) resolve the topic to a citation first, then
  pull commentary chains — never substitute open-web search for the primary text.
- CandleKeep `library` subagents follow
  `${CLAUDE_SKILL_DIR}/references/candlekeep-integration.md` — `ck items list --json`,
  match up to 3 items by topic keywords, `ck items toc` then `ck items read` for the
  relevant pages, and return the same digest contract (`kind: "library"`).

**Verification gate:** every dispatched subagent returned at least one digest entry, and
combined the roster produced at least 5 unique URLs/sources. If fewer, re-dispatch the
weakest subagent with a broadened query before proceeding.

### Phase 2: Merge and Synthesize

1. Collect every subagent's digest array. Deduplicate by URL (library/primary-text
   entries dedupe by id instead).
2. Rank by the resolved domain's `## Source Ranking` order.
3. Write a synthesis of roughly 500 words (~3000 characters — the validation hook warns
   below 2500) covering at least 3 distinct subtopics, drawing only from the digests'
   `why_it_matters` and `key_claims`, not from re-fetching pages.
4. Save the workflow state file. All five keys are required — the hook rejects the file
   if any is missing:

```bash
echo "{\"topic\":\"$SUBJECT\",\"domain\":\"$DOMAIN\",\"notebooks\":[],\"total_sources\":0,\"candlekeep\":{\"read_ids\":[],\"write_id\":null},\"local_path\":\"$HOME/dev/learn-research/learn-$TOPIC_SLUG/\"}" > "/tmp/learn-workflow-state-$TOPIC_SLUG.json"
```

`$TOPIC_SLUG` is the subject lowercased, spaces to hyphens, special characters removed.

**Verification gate:** state file written and matches the 5-key schema; synthesis covers
≥3 subtopics and is ≥2500 characters.

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
  research-summary.md    — ~500-word synthesis
  sources/
    01-primary.md        — official docs, or Sefaria text, per domain
    02-library.md        — CandleKeep sources
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
> the CandleKeep offer are unaffected.

Omit the Notebooks and Artifacts tables from the final report and continue straight to
Phase 6. **Never stop the workflow because NotebookLM is missing or skipped.**

When available, consult `${CLAUDE_SKILL_DIR}/references/notebooklm-loading.md` for
notebook-creation strategy, source-addition patterns, and the 48-source overflow
threshold (read `notebooks[-1]` from the topic-scoped state file, not the old unscoped
path), and `${CLAUDE_SKILL_DIR}/references/artifact-generation.md` for exact tool-call
signatures.

**Phase 3 — Load into NotebookLM:**
1. Create notebook `[Topic] - Core Learning`.
2. Add CandleKeep sources first (`wait=false`, title `"Library: [Item Title]"`) if any.
3. Add remaining URL/primary-text sources (`wait=false`).
4. Add the research summary as a text source (`wait=true`).
5. Update the state file's `notebooks[]` and `total_sources` after each addition.
6. Overflow to a new notebook when the running count reaches 48.

**Phase 4 — Generate Artifacts:** create podcast, infographic, mind map, flashcards, and
study guide in parallel (`confirm=true` on each), all using
`language=<resolved domain language>` from Phase 0.5 — never a hardcoded value. The
study guide's `focus_prompt` follows the resolved domain's `## Output Settings` →
NotebookLM artifact focus line (implementation-oriented for `tech`; argument structure
for `philosophy`; text-and-commentary for `judaism`) — see the domain-adapted brief table
in `artifact-generation.md`.

**Phase 5 — Poll and Report:** poll `studio_status` every 30 seconds (max 10 polls / 5
minutes) until every artifact is `completed` or `failed`.

**Verification gate (when this unit runs):** all `studio_create` calls returned artifact
IDs; polling ends with every artifact reported `completed` or `failed`, never left
`in_progress` in the final summary.

### Phase 6: Companion Visuals

#### 6a: ASCII Diagram — always

Using the Phase 2 synthesis, render an ASCII diagram inline in the terminal — pick the
shape that fits the subject (architecture diagram, flowchart, comparison table, mind
map / hierarchy). Unicode box-drawing characters, width under 100 chars.

#### 6b: Interactive Playground — tech only

**Condition:** the resolved domain's `## Output Settings` → Playground line says
**yes**. Currently that is `tech` only — `philosophy` and `judaism` say no because a
parameter-toggle explorer doesn't fit argumentative or textual material. Skip silently
for those domains.

When it runs, do not generate the HTML yourself — delegate:

```
Skill(skill="playground:playground", args="<subject> — based on this research summary: <paste the Phase 2 synthesis>")
```

Let the playground skill own all HTML creation, styling, and file output.

**Verification gate:** 6a always produced a rendered diagram. 6b either produced an
opened HTML file (tech) or was skipped with no output (philosophy/judaism) — no partial
state in between.

### Phase 7: CandleKeep Field Research Offer

**Condition:** `HAS_CANDLEKEEP = true`. Otherwise skip silently.

Follow `${CLAUDE_SKILL_DIR}/references/candlekeep-integration.md` → `## Field Research
Offer (Phase 7)` exactly: run the format-tolerant existence check, create + enrich the
book at creation if none exists, then interactively ask the user:

> **Would you like to file today's findings into your CandleKeep field-research book on
> this topic?**

If yes: compose the dated entry per `## Entry Format` in that reference (one H1 per
page, `#` escaped inside any fence, subject/domain/sources/findings/open-questions),
append with `ck items append <book-id> --file <path> --no-session`, then verify with
`ck items read "<book-id>:<n>" --no-session` — **never** by trusting the append
command's own log output. Update the state file's `candlekeep.write_id`.

If the append or readback fails, report it plainly and leave the local entry file in
place — do not silently drop the finding.

If the user declines, skip without writing anything.

**Verification gate:** either skipped silently (`HAS_CANDLEKEEP = false`), declined by
the user, or a successful append confirmed by read-back.

## Examples

### Example 1 — tech, full package

`/learn-toolkit:learn Next.js App Router`

1. Phase 0: Tavily MCP ✓, Exa ✓, CandleKeep ✓, NotebookLM ✓.
2. Phase 0.5: no `--domain` given → inferred `tech` (documentation/framework subject).
   Announces `Domain: tech (inferred) — official docs, source repos, practitioner
   discussion. Override with --domain.` Language resolves to `en`.
3. Phase 1: dispatches `docs`, `code`, `community`, `library` subagents from
   `domains/tech.md` in one message.
4. Phase 2: merges digests, ranks official docs > repos > library > discussion, writes
   ~500-word synthesis, saves state file with `"domain":"tech"`.
5. Phase 2.5: saves to `~/dev/learn-research/learn-nextjs-app-router/`.
6. Phase 3-5: creates notebook, generates 5 artifacts in `en`.
7. Phase 6a: ASCII diagram of the App Router's file-based routing. Phase 6b: playground
   comparing Pages Router vs App Router (tech says yes).
8. Phase 7: offers to file findings into a `Field Research — Next.js App Router` book.

### Example 2 — judaism, primary-text-first

`/learn-toolkit:learn hilchot shabbat candle lighting --domain judaism`

1. Phase 0: Tavily ✓, Sefaria ✓, CandleKeep ✓, NotebookLM ✗ (not configured).
2. Phase 0.5: `--domain judaism` given, so inference is skipped. Language resolves to
   `he` (domain default, no `--language` override). Announces
   `Domain: judaism (--domain) — Sefaria primary text, classical commentators,
   library. Override with --domain.`
3. Phase 1: dispatches `primary` (Sefaria), `library` (CandleKeep), `secondary`
   (Tavily/Exa) — Sefaria resolves the citation first before the secondary subagent
   runs its contextualizing search.
4. Phase 2: ranks primary text > commentators > library > academic scholarship >
   shiurim; synthesis in Hebrew framing.
5. Phase 2.5: local files saved; `01-primary.md` holds the Sefaria text and commentary
   chain.
6. Phase 3-5: **skipped** — single notice printed: "NotebookLM not available — skipping
   the notebook package. Research, local files and the CandleKeep offer are
   unaffected." No notebook/artifact tables in the final report.
7. Phase 6a: ASCII diagram of the sugya structure. Phase 6b: skipped (judaism says no).
8. Phase 7: offers to file into CandleKeep; never writes to or links into
   `~/dev/sefaria/sefaria-wiki`.

### Example 3 — philosophy, degraded search

`/learn-toolkit:learn the Ship of Theseus and personal identity`

1. Phase 0: Tavily ✗ (not configured), Exa ✓, CandleKeep ✓, NotebookLM ✓. Since at
   least one search backend (Exa) is available, the workflow proceeds — only zero
   backends stops it.
2. Phase 0.5: inferred `philosophy` (argument/thinker subject, no primary Jewish text).
   Language resolves to `he`.
3. Phase 1: dispatches `literature` (Exa only, Tavily-dependent query patterns skipped),
   `overview` (degrades — notes Tavily unavailable, relies on Exa for encyclopedic
   framing too), `library` (CandleKeep).
4. Phase 2 onward proceeds normally; Phase 6b skipped (philosophy says no).

## Error Recovery

| Error | Cause | Action |
|-------|-------|--------|
| Both Tavily and Exa unavailable | Neither MCP nor CLI configured, no keys | **STOP workflow.** Show setup instructions for both. Do not fall back to bare `WebSearch`. This is the only stop condition in the workflow |
| Tavily CLI auth fails (`tvly auth`) | Not logged in | Run `tvly login` or set `TAVILY_API_KEY`; treat as `HAS_TAVILY_SKILLS=false` until fixed |
| Exa MCP not found | Key unset, or set after Claude Code started | If `$EXA_API_KEY` set: tell user to restart Claude Code. If unset: show Exa setup instructions. Proceed on Tavily alone if it is available |
| Sefaria MCP not found (domain=judaism) | Not configured | Note in the domain announcement; `secondary` subagent (Tavily/Exa) carries more weight; continue |
| NotebookLM not found, or `--no-notebook` passed | Not configured / user opted out | Skip phases 3-5, continue. Emit the single skip notice, omit notebook/artifact tables, proceed to Phase 6 |
| NotebookLM auth expired | Token expired | Run `nlm login` via Bash (timeout 120s), then retry once |
| Source add fails for one URL | Blocked or invalid URL | Log it, skip it, continue with remaining sources |
| Notebook source count reaches 48 | Cap approaching | Create overflow notebook per `notebooklm-loading.md`, continue |
| Studio artifact generation fails | NotebookLM internal error | Retry once; if it still fails, report "Failed" in the summary table |
| State file write fails | `/tmp` permission issue | Continue without state tracking; keep counts in-memory for this run |
| `ck` not found | CLI not installed | `HAS_CANDLEKEEP=false`; skip library subagent and Phase 7 silently |
| `ck items list` fails | Auth issue | Warn once, set `HAS_CANDLEKEEP=false`, continue |
| `ck items read` fails for one item | Bad item id | Skip that item, continue with the rest |
| `ck items append` succeeds but the log looks like it failed (`BadRecordMac`) | TLS response-stream error, write may still have landed | Never trust the log — verify with `ck items read "<book-id>:<n>"`. Report actual state from the readback |
| `ck items create`/`append` genuinely fails | Permission or network issue | Warn, leave the local entry file in `~/dev/learn-research/learn-<topic-slug>/`, do not drop the finding |
