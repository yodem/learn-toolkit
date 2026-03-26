---
name: learn-toolkit:learn
description: "Deep Learning Workflow: Tavily + Exa research into NotebookLM learning package with CandleKeep library integration (podcast, infographic, flashcards). Use for deep dives into new technologies, frameworks, or concepts."
argument-hint: "<topic>"
disable-model-invocation: true
allowed-tools: Bash(tvly *), Bash(ck *)
metadata:
  author: Yotam Fromm
  version: 1.5.1
  mcp-server: tavily, exa, notebooklm-mcp
  category: learning
  tags: [research, notebooklm, tavily, exa, podcast, flashcards, candlekeep]
---

# Learn Workflow

## Important

CRITICAL: Follow these steps in exact order. Each phase has a verification gate — do NOT proceed to the next phase until verification passes.

- Default output language is **Hebrew** (`he`). User can override with `--language <code>`
- Max 50 sources per NotebookLM notebook. Track count and overflow to new notebooks

## Instructions

### Phase 0: Discover Available Tools

**This phase is mandatory. Do NOT skip it.**

Before any research, discover which search backends and NotebookLM tools are actually available in this session.

#### Step 0a: Check for Tavily Skills and CLI

First, check if the Tavily agent skills are installed (these provide `tvly` CLI access via `Skill()`):

```bash
tvly --version 2>/dev/null && echo "TAVILY_CLI=true" || echo "TAVILY_CLI=false"
```

If `tvly` is found, check auth status (no API call needed):
```bash
tvly --status 2>/dev/null && echo "TAVILY_CLI_AUTH=true" || echo "TAVILY_CLI_AUTH=false"
```

Set `HAS_TAVILY_SKILLS` = true only if both checks pass. When true, `tvly` commands are available directly (the `/learn-toolkit:learn` skill's `allowed-tools: Bash(tvly *)` grants permission). Available commands:
- `tvly search` — web search with LLM-optimized results
- `tvly extract` — extract content from specific URLs
- `tvly crawl` — crawl websites to local markdown
- `tvly map` — discover URLs on a domain
- `tvly research` — deep AI-synthesized research with citations

#### Step 0b: Check MCP backends

Use `ToolSearch` to probe for each MCP backend:

1. `ToolSearch(query="+tavily search")` — look for `mcp__tavily__tavily_search` and `mcp__tavily__tavily_extract`
2. `ToolSearch(query="+exa search")` — look for `mcp__exa__web_search_exa` and `mcp__exa__crawling_exa`
3. `ToolSearch(query="+notebooklm")` — look for `mcp__notebooklm-mcp__notebook_create`, `mcp__notebooklm-mcp__source_add`, `mcp__notebooklm-mcp__studio_create`, `mcp__notebooklm-mcp__studio_status`

Run all 3 searches in parallel.

Set flags based on results:
- `HAS_TAVILY_MCP` = true if `mcp__tavily__tavily_search` was found
- `HAS_TAVILY_SKILLS` = true if `tvly` CLI is installed and authenticated (from Step 0a)
- `HAS_TAVILY` = true if `HAS_TAVILY_MCP` OR `HAS_TAVILY_SKILLS` is true
- `HAS_EXA` = true if `mcp__exa__web_search_exa` was found
- `HAS_NOTEBOOKLM` = true if NotebookLM tools were found

#### Step 0c: Check CandleKeep CLI

```bash
ck --version 2>/dev/null && echo "CK_CLI=true" || echo "CK_CLI=false"
```

Set `HAS_CANDLEKEEP = true/false`. CandleKeep missing is **not** an error — just note it and continue.

**Tell the user which backends are available:**

```
Research backends: [Tavily MCP ✓/✗] [Tavily Skills/CLI ✓/✗] [Exa ✓/✗] [CandleKeep ✓/✗]
NotebookLM: [✓/✗]
```

**Tavily priority:** If both `HAS_TAVILY_MCP` and `HAS_TAVILY_SKILLS` are true, prefer MCP for search (richer metadata) but use Tavily skills for extract/crawl/research (better at bulk operations). If only skills/CLI are available, use them for all Tavily operations.

**If ANY required backend is missing, STOP the workflow immediately.** Do NOT fall back to WebSearch. Do NOT proceed to Phase 1. Instead, show the user exactly what's missing and how to fix it:

If Tavily is missing (neither MCP nor CLI):
> **Tavily is not connected.** You can set it up via either method:
>
> **Option A: Tavily CLI (recommended)**
> 1. `curl -fsSL https://cli.tavily.com/install.sh | bash`
> 2. `tvly login` (opens browser) or `tvly login --api-key tvly-YOUR_KEY`
> 3. Optionally install agent skills: `npx skills add tavily-ai/skills --yes`
>
> **Option B: Tavily MCP server**
> 1. Get a free API key at https://tavily.com
> 2. Add `export TAVILY_API_KEY="your-key-here"` to your `~/.zshrc` (or `~/.bashrc`)
> 3. Run `source ~/.zshrc` and **restart Claude Code**
>
> **Do not paste your API key in this chat.**

If Exa is missing:
> **Exa is not connected.** This is likely because `EXA_API_KEY` is not set in your shell environment.
>
> To fix:
> 1. Get an API key at https://exa.ai
> 2. Add `export EXA_API_KEY="your-key-here"` to your `~/.zshrc` (or `~/.bashrc`)
> 3. Run `source ~/.zshrc` and **restart Claude Code**
>
> **Do not paste your API key in this chat.**

If NotebookLM is missing:
> **NotebookLM is not connected.** Install it from https://github.com/nicholasgriffintn/notebooklm-mcp and run `nlm login` to authenticate.

After showing the missing tools, end with:
> Run `/learn-toolkit:learn $ARGUMENTS` again after fixing the above.

**Verification gate:** ALL three backends must be available: Tavily ✓ (MCP or CLI), Exa ✓, NotebookLM ✓. If any are missing, the workflow STOPS here with setup instructions. Do NOT continue.

### Phase 0.5: CandleKeep Library Scan

**Condition:** `HAS_CANDLEKEEP = true` AND no `--no-ck-read` flag. Skip this phase entirely otherwise.

Consult `${CLAUDE_SKILL_DIR}/references/candlekeep-integration.md` for detailed library scan logic and `ck` command patterns.

1. `ck items list --json` — scan titles/descriptions for topic overlap with `$ARGUMENTS`
2. For matching items (max 3): `ck items toc <id>`, then `ck items read "id:<relevant-pages>"`
3. Store as `ck_sources[]` with `{id, title, content_snippet}`
4. Report: "Found X relevant documents in CandleKeep: [titles]" or "No relevant library documents found"

CandleKeep content is available as context for Phase 1 — use it to refine search queries (skip basics already covered in library).

**Verification gate:** Library scanned (even if 0 matches). Proceed regardless.

### Phase 1: Parallel Research

Research **$ARGUMENTS** across all **available** backends simultaneously. Only use backends where the corresponding flag from Phase 0 is true.

**If HAS_TAVILY_MCP (preferred for search):**
- `mcp__tavily__tavily_search(query="$ARGUMENTS", search_depth="advanced", include_raw_content=true)`
- `mcp__tavily__tavily_search(query="$ARGUMENTS tutorial guide 2025 2026", search_depth="advanced", include_raw_content=true)`
- After searches complete, extract top 3-5 most valuable URLs via `mcp__tavily__tavily_extract` if that tool is available

**If HAS_TAVILY_SKILLS (fallback, or complement to MCP):**
Use `tvly` CLI commands directly (permitted by this skill's `allowed-tools: Bash(tvly *)`):
- `tvly search "$ARGUMENTS" --depth advanced --max-results 10 --include-raw-content --json`
- `tvly search "$ARGUMENTS tutorial guide 2025 2026" --depth advanced --max-results 10 --json`
- After searches, extract top URLs: `tvly extract "URL1" "URL2" "URL3" --json`
- For comprehensive single-call research: `tvly research "$ARGUMENTS" --json` (multi-source synthesis with citations — can replace manual search+extract when only CLI is available)

If both MCP and skills are available, use MCP for search and `tvly` CLI for extract/crawl/research (CLI is better at bulk operations).

**If HAS_EXA:**
- `mcp__exa__web_search_exa(query="$ARGUMENTS documentation")`
- `mcp__exa__web_search_exa(query="$ARGUMENTS architecture patterns examples")`
- Crawl top 2-3 most valuable URLs via `mcp__exa__crawling_exa`

**Verification gate:** At least 5 unique URLs collected across all backends. If fewer, run additional queries with broader terms before proceeding.

### Phase 2: Organize and Verify

1. Deduplicate URLs across all backends
2. Categorize: official docs > **library (CandleKeep)** > tutorials > blog posts > code repos > comparisons
3. If CandleKeep sources exist from Phase 0.5, list them under a "Library Sources" heading in the research summary
4. Write a 500-word research summary synthesizing key findings from search result snippets, any fetched content, and CandleKeep library content
5. Save state (substitute `$TOPIC_SLUG` with the actual slug — topic lowercased, spaces to hyphens, special chars removed):
```bash
echo "{\"topic\":\"$ARGUMENTS\",\"notebooks\":[],\"total_sources\":0,\"candlekeep\":{\"read_ids\":[],\"write_id\":null},\"local_path\":\"$HOME/dev/learn-research/learn-$TOPIC_SLUG/\"}" > /tmp/learn-workflow-state.json
```

**Verification gate:** State file written successfully. Research summary covers at least 3 distinct subtopics. If not, return to Phase 1 with refined queries.

### Phase 2.5: Save Local MD Files

Always runs (not CandleKeep-specific). Save all research to `~/dev/learn-research/learn-<topic-slug>/`. Create the directory if it doesn't exist:

```bash
mkdir -p "$HOME/dev/learn-research/learn-<topic-slug>"
```

```
~/dev/learn-research/learn-<topic-slug>/
  README.md              — index with TOC, metadata, date
  research-summary.md    — 500-word synthesis
  sources/
    01-official-docs.md
    02-library.md         — CandleKeep sources (if any)
    03-tutorials.md
    04-articles.md
```

Each source file contains: URL/source identifier, title, backend that provided it, and content snippet. The `topic-slug` is the topic lowercased, spaces replaced with hyphens, special chars removed.

Consult `${CLAUDE_SKILL_DIR}/references/candlekeep-integration.md` for file structure details.

Report path to user: `"Research saved to ~/dev/learn-research/learn-<topic-slug>/"`

Note: If `--ck-write` is set, `book.md` will be added to this directory later in Phase 5.5.

**Verification gate:** Directory created, `README.md` and `research-summary.md` exist.

### Phase 3: Load into NotebookLM

IMPORTANT: Max 50 sources per notebook. Track the count. Overflow creates a new notebook.

Consult `${CLAUDE_SKILL_DIR}/references/notebooklm-loading.md` for notebook creation strategy, source addition patterns, and overflow handling.

1. Create notebook: `mcp__notebooklm-mcp__notebook_create(title="[Topic] - Core Learning")`
2. If CandleKeep sources exist (`ck_sources[]` from Phase 0.5), add them as text sources with `wait=false` (before URLs). Use title `"Library: [Item Title]"`. Max 3 items = negligible impact on 50-source limit
3. Add all URL sources with `wait=false` (non-blocking)
4. Add research summary text source with `wait=true` (blocking)
5. Update state file with notebook ID, source count, and `candlekeep.read_ids` after each addition
6. If source count reaches 48, create overflow notebook and continue

**Verification gate:** Run `mcp__notebooklm-mcp__studio_status` and confirm all sources show `status: "ready"` or `"completed"`. If sources are still processing, wait 10 seconds and check again (max 3 retries).

### Phase 4: Generate Artifacts

For each notebook, create all four artifacts in parallel (confirm=true on each).

Consult `${CLAUDE_SKILL_DIR}/references/artifact-generation.md` for exact tool call signatures.

| Artifact | Type | Key params |
|----------|------|-----------|
| Podcast | `audio` | `deep_dive`, `language="he"` |
| Infographic | `infographic` | `bento_grid`, `portrait`, `language="he"` |
| Mind Map | `mind_map` | `language="he"` |
| Flashcards | `flashcards` | `medium`, `language="he"` |
| Study Guide | `report` | `report_type="Study Guide"`, `language="he"`, implementation-focused `focus_prompt` |

The Study Guide is an implementation-focused artifact that includes: key concepts summary, step-by-step implementation guide with code examples, action items checklist, common pitfalls, and recommended next steps.

**Verification gate:** All 5 `studio_create` calls returned successfully with artifact IDs. If any failed, retry once before reporting failure.

### Phase 5: Poll and Report

Poll `mcp__notebooklm-mcp__studio_status` every 30 seconds until all artifacts are complete (max 10 polls / 5 minutes).

Present final summary to user:

```
## Learning Package: [Topic]

### Notebooks
| # | Name | Sources | Link |
|---|------|---------|------|

### Artifacts
| Notebook | Type | Status | Title |
|----------|------|--------|-------|

### Research Summary
- X official docs, X tutorials, X articles, X repos
- Total unique sources: X
```

**Verification gate:** Summary table includes at least 1 notebook and 5 artifacts. All artifact statuses are reported (completed or failed, not in_progress).

### Phase 5.5: Write to CandleKeep

**Condition:** `HAS_CANDLEKEEP = true` AND `--ck-write` flag present. Skip this phase entirely otherwise.

Consult `${CLAUDE_SKILL_DIR}/references/candlekeep-integration.md` for book compilation template and `ck` command patterns.

1. Compile book from all research into `~/dev/learn-research/learn-<topic-slug>/book.md` — includes executive summary, 3-5 chapters adapted to the topic, and source index appendix
2. `ck items create "[Topic] - Research Compendium" --description "Auto-generated research compendium on [Topic]. Created by learn-toolkit on [date]." --no-session`
3. `ck items put <id> --file ~/dev/learn-research/learn-<topic-slug>/book.md --no-session`
4. Update state file with `candlekeep.write_id`
5. Report: `"Research book uploaded to CandleKeep (item #ID)"`

If `ck items create` or `ck items put` fails, warn user and continue — the compiled `book.md` is still available in `~/dev/learn-research/`.

**Verification gate:** Book file exists at `~/dev/learn-research/learn-<topic-slug>/book.md`. If `--ck-write` was set, CandleKeep item was created (or failure was reported).

### Phase 6: Generate Companion Visualizations (3-Step Integration)

After the NotebookLM artifacts are complete, generate the other two skill outputs using the research already gathered. This gives the user the full 3-step learning experience in one workflow.

#### Step 6a: ASCII Architecture Diagram (`/learn-toolkit:visualize`)

Using the research summary from Phase 2, generate an ASCII diagram directly in the terminal. Pick the most appropriate diagram type for the topic:

- Architecture topics → system architecture diagram
- Process/workflow topics → flowchart
- Comparison topics → comparison table
- Concept topics → mind map / hierarchy

Output the diagram inline (same as `/learn-toolkit:visualize` would produce). Use Unicode box-drawing characters, keep width under 100 chars.

#### Step 6b: Interactive Playground (`/learn-toolkit:playground`)

**Do NOT generate the HTML yourself.** Delegate to the `playground:playground` skill, passing the research summary as context.

Invoke: `Skill(skill="playground:playground", args="<topic> — based on this research summary: <paste the 500-word research summary from Phase 2>")`

The playground skill will generate the interactive HTML file and open it in the browser. Let it handle all HTML creation, styling, and file output.

#### Final Output

Present the complete learning package:

```
## Complete Learning Package: [Topic]

### Step 1: Quick Visual (Terminal)
[ASCII diagram rendered above]

### Step 2: Interactive Explorer (Browser)
File: ~/dev/learn-research/playground-<topic-slug>.html (opened in browser)

### Step 3: Deep Learning (NotebookLM)
| # | Notebook | Sources | Link |
|---|----------|---------|------|

| Notebook | Type | Status | Title |
|----------|------|--------|-------|

### CandleKeep
| Direction | Items | Details |
|-----------|-------|---------|
| Read      | X     | "Doc A", "Doc B", "Doc C" |
| Write     | X     | Item #ID - "[Topic] - Research Compendium" |

(Omit this section entirely if HAS_CANDLEKEEP = false)

### Local Files
Research saved to: ~/dev/learn-research/learn-<topic-slug>/

### Research Summary
- X official docs, X library sources, X tutorials, X articles, X repos
- Total unique sources: X
```

**Verification gate:** All three steps produced output: ASCII diagram rendered, playground skill invoked and HTML opened, NotebookLM artifacts complete.

### Phase 7: Offer to Save Research Summary

After presenting the final summary, ask the user:

> **Would you like to keep the research summary?**
> I can save it with a proper name (e.g., `[Topic]-research-summary.md`) and add it as a source to your NotebookLM notebook.

If the user says yes:
1. Copy `~/dev/learn-research/learn-<topic-slug>/research-summary.md` to the current working directory with a descriptive name (e.g., `[Topic]-Research-Summary-[YYYY-MM-DD].md`)
2. If `HAS_NOTEBOOKLM = true`, add the summary as a text source to the notebook: `mcp__notebooklm-mcp__source_add(notebook_id=<id>, source_type="text", text=<summary content>)`
3. Report the saved file path and notebook addition status

If the user declines, skip this phase.

## Examples

### Example 1: Full 3-step learning package

User says: `/learn-toolkit:learn Next.js App Router`

Actions:
1. Phase 0: ToolSearch finds Tavily MCP ✓, Exa ✓, NotebookLM ✓
2. Tavily MCP searches for "Next.js App Router" and "Next.js App Router tutorial guide 2025 2026"
3. Exa searches for "Next.js App Router documentation" and "Next.js App Router architecture patterns"
4. Collects 23 unique URLs, deduplicates to 19
5. Creates "Next.js App Router - Core Learning" notebook, adds all 19 URLs + research summary
6. Generates podcast, infographic, mind map, flashcards, study guide in Hebrew
7. Polls until complete
8. **Step 1 output:** ASCII architecture diagram of App Router's file-based routing (rendered in terminal)
9. **Step 2 output:** Interactive playground comparing Pages Router vs App Router with parameter toggles → `/tmp/playground-nextjs-app-router.html`
10. **Step 3 output:** NotebookLM summary table with 5 artifacts

Result: Complete learning package — ASCII diagram + interactive playground + 1 notebook, 19 sources, 5 artifacts

### Example 2: Tavily CLI only (no MCP)

User says: `/learn-toolkit:learn Kafka event streaming` (Tavily MCP not configured, but `tvly` CLI installed)

Actions:
1. Phase 0: `tvly --version` found ✓, auth check passes ✓. ToolSearch finds Tavily MCP ✗, Exa ✓, NotebookLM ✓
2. Status: Tavily CLI ✓, Exa ✓, NotebookLM ✓ — proceed
3. `tvly search "Kafka event streaming" --depth advanced --max-results 10 --json`
4. `tvly search "Kafka event streaming tutorial guide 2025 2026" --depth advanced --max-results 10 --json`
5. Exa searches run in parallel
6. `tvly extract` on top URLs for full content
7. Continues to Phase 2+

Result: Same quality output, using CLI instead of MCP for Tavily

### Example 3: Missing backends — workflow stops

User says: `/learn-toolkit:learn Kafka event streaming` (no Tavily/Exa configured)

Actions:
1. Phase 0: `tvly` not found. ToolSearch finds Tavily MCP ✗, Exa ✗, NotebookLM ✓
2. Workflow STOPS — displays setup instructions for Tavily (CLI or MCP) and Exa
3. User installs `tvly` or sets env vars, restarts Claude Code, runs `/learn-toolkit:learn Kafka event streaming` again

Result: No research performed. User gets clear fix instructions.

### Example 4: Overflow to multiple notebooks

User says: `/learn-toolkit:learn Kubernetes`

Actions:
1. Research yields 65 unique URLs across all backends
2. Creates "Kubernetes - Core Learning" (48 sources)
3. Creates "Kubernetes - Deep Dive" (17 sources + research summary)
4. Generates 5 artifacts per notebook (10 total)
5. ASCII diagram of K8s architecture (pods, services, ingress, nodes)
6. Interactive playground comparing deployment strategies (rolling, blue-green, canary)

Result: Complete learning package — ASCII diagram + playground + 2 notebooks, 65 sources, 10 artifacts

### Example 5: Language override

User says: `/learn-toolkit:learn GraphQL federation --language en`

Actions: Same workflow, but all NotebookLM artifacts use `language="en"` instead of `"he"`

Result: English-language learning package

## Error Recovery

| Error | Cause | Action |
|-------|-------|--------|
| Tavily not found (neither MCP nor CLI) | Server not configured, CLI not installed, or API key missing | **STOP workflow.** Show Tavily setup instructions (CLI or MCP). Do NOT fall back to WebSearch |
| Tavily CLI auth error (exit code 3) | `tvly` installed but not authenticated | Run `tvly login` or set `TAVILY_API_KEY` env var |
| Exa MCP not found in ToolSearch | Server not configured, API key missing, or MCP not connected | **STOP workflow.** Show Exa setup instructions. Do NOT fall back to WebSearch |
| NotebookLM not found in ToolSearch | MCP not configured | **STOP workflow.** Show NotebookLM setup instructions |
| NotebookLM auth expired | Token expired | Run `nlm login` via Bash (timeout 120s), then retry |
| Source add fails for a URL | URL blocked or invalid | Log the URL, skip it, continue with remaining sources |
| Source limit (50) hit | Too many sources | Create new notebook with next-tier name, continue adding |
| Studio generation fails | NotebookLM internal error | Retry once. If still fails, report in summary table as "Failed" |
| State file write fails | /tmp permission issue | Continue without state tracking, use in-memory counting |
| `ck` not found | CLI not installed | `HAS_CANDLEKEEP = false`, skip silently |
| `ck items list` fails | Auth issue | Warn user, set `HAS_CANDLEKEEP = false`, continue |
| `ck items read` fails | Bad item | Skip that item, continue with remaining |
| `ck items create/put` fails | Permission issue | Warn, skip write, `book.md` still in `/tmp` |
