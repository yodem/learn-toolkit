# Setup Instructions for AI Assistants

This repository is a **Claude Code plugin**. When a user shares this repo URL, guide them through the plugin install — do NOT manually copy skill files.

## Quick install (preferred)

### Step 1: Add the marketplace and install the plugin

```
/plugin marketplace add yodem/learn-toolkit
/plugin install learn-toolkit@learn-toolkit-marketplace
```

Or via CLI:
```bash
claude plugin install learn-toolkit@learn-toolkit-marketplace
```

This installs the plugin's one skill and configures MCP servers automatically:
- `/learn-toolkit:learn <subject>` — domain-aware deep research (Tavily + Exa, plus
  Sefaria for `judaism`) into a NotebookLM learning package (podcast, infographic, mind
  map, flashcards, study guide), with optional CandleKeep library integration.

### Step 2: Set up API keys for /learn (optional but recommended)

The plugin's `.mcp.json` configures Tavily and Exa servers using environment variable
references (`${TAVILY_API_KEY}`, `${EXA_API_KEY}`). The user needs to set these in their
shell profile. The workflow needs **at least one** of Tavily or Exa to run at all — that
is the only hard stop in the whole workflow; everything else (Sefaria, CandleKeep,
NotebookLM) degrades gracefully when absent.

**SECURITY: NEVER ask the user to paste API keys in the chat.**

Detect their shell:
```bash
echo $SHELL
```

Then tell them:

---

The plugin is installed. To enable the `/learn-toolkit:learn` search backends, add your API keys to your shell profile.

**Open your shell profile in your editor** (`~/.zshrc` for zsh, `~/.bashrc` for bash) and add:

```bash
export TAVILY_API_KEY="your-tavily-key-here"    # Get one free at https://tavily.com
export EXA_API_KEY="your-exa-key-here"          # Get one at https://exa.ai
```

Then run `source ~/.zshrc` (or `~/.bashrc`) and restart Claude Code.

**Do not paste your API keys in this chat.** Add them directly to your shell profile.

---

If the user doesn't have API keys and skips this step entirely, `/learn-toolkit:learn`
will detect the missing backends at Phase 0 and show setup instructions instead of
running.

### Step 2b: Install Tavily Agent Skills (recommended)

The Tavily agent skills give `/learn-toolkit:learn` a CLI-based fallback when the Tavily MCP server isn't available, and provide standalone `tvly` commands for direct web search, extraction, crawling, and research.

**Install the skills and CLI:**

```bash
npx skills add tavily-ai/skills --yes
curl -fsSL https://cli.tavily.com/install.sh | bash
tvly login
```

The `tvly login` command opens a browser for OAuth, or use `tvly login --api-key` with the same key from Step 2.

**Check auth with `tvly auth`, not `tvly --status`** — the latter prints a two-part
banner whose auth line is lost when piped, giving a false negative. `/learn-toolkit:learn`
itself checks with `tvly auth` for exactly this reason:

```bash
tvly auth
```

This installs 8 skills:
- `/tavily-search` — LLM-optimized web search
- `/tavily-extract` — Extract content from URLs
- `/tavily-crawl` — Crawl websites to local markdown
- `/tavily-map` — Discover URLs on a domain
- `/tavily-research` — AI-synthesized deep research with citations
- `/tavily-dynamic-search` — Programmatic search with context isolation
- `/tavily-cli` — Unified CLI reference
- `/tavily-best-practices` — Integration guidance

**How it works with `/learn-toolkit:learn`:** the workflow auto-detects whether Tavily MCP or the Tavily CLI is available. If MCP is configured, it uses MCP for search. If only the CLI is installed, it uses the CLI (piped through a filter so raw HTML never enters context) for everything. Either way, the user gets full Tavily coverage.

### Step 3: NotebookLM (fully optional)

If the user wants podcast/infographic/mind-map/flashcard generation:
- Check if they have `notebooklm-mcp` installed
- If not: "NotebookLM is optional. `/learn-toolkit:learn` will still research your topic, save it locally, and offer the CandleKeep write — it just won't generate a podcast, infographic, mind map, flashcards, or study guide. Add it later from https://github.com/nicholasgriffintn/notebooklm-mcp, or pass `--no-notebook` any time to skip it deliberately."

When NotebookLM is absent, or when the user passes `--no-notebook`, the workflow's Phase
3-5 (notebook creation + artifact generation) skip together as one unit. Research, local
file output, and the CandleKeep offer are unaffected — NotebookLM is never a blocker.

### Step 3b: CandleKeep (optional)

If the user has `candlekeep-cloud` installed (with the `ck` CLI available),
`/learn-toolkit:learn` will automatically:
- **Scan the library** for existing documents on the topic before researching — this
  runs unconditionally on every domain, with no flag to disable it.
- **Offer to write** a compiled field-research entry back to CandleKeep at the end of the
  run — this is an interactive yes/no question at Phase 7, not a flag. It appends to a
  per-topic `Field Research — <Topic>` book; declining writes nothing.

Neither behavior above is flag-gated in this version — the old read/write flags from
earlier releases are gone; the scan is now always-on and the write is always an
interactive prompt. CandleKeep is never required — the workflow skips both the scan and
the offer silently if `ck` is not installed.

### Step 4: Confirm

Tell the user:

---

Plugin **learn-toolkit** installed. Here's what you have:

| Command | Ready? |
|---------|--------|
| `/learn-toolkit:learn <subject>` | After setting env vars + restart (at least one of Tavily/Exa) |
| CandleKeep (optional) | Automatic library scan + end-of-run write offer, if `ck` CLI installed |
| NotebookLM (optional) | Podcast/infographic/mind map/flashcards, if `notebooklm-mcp` installed — skip with `--no-notebook` |
| Tavily Agent Skills | `/tavily-search`, `/tavily-research`, `tvly` CLI — after Step 2b (`npx skills add` + `tvly login`) |

**After env vars + restart:**
```
/learn-toolkit:learn Kafka event streaming
```

The domain (`tech`, `philosophy`, or `judaism`) is inferred from the subject and
announced before any research runs — override it with `--domain`:

```
/learn-toolkit:learn hilchot shabbat candle lighting --domain judaism
```

Default language follows the resolved domain (`tech` → `en`; `philosophy`/`judaism` →
`he`) — override with `--language <code>`:

```
/learn-toolkit:learn Rust ownership and borrowing --language en
```

Skip the NotebookLM package for a given run:

```
/learn-toolkit:learn Next.js App Router --no-notebook
```

**After Tavily skills install (Step 2b):**
```
/tavily-search "Claude Code plugins"
/tavily-research "RAG architecture patterns"
tvly crawl "https://docs.example.com" --output-dir ./docs/
```

---

## Important notes for the AI assistant

- **NEVER ask for, display, or log API key values.** Not in chat, not in tool calls, not in file contents.
- If a user accidentally pastes a key, warn them to rotate it immediately
- The plugin bundles MCP configs via `.mcp.json` with `${ENV_VAR}` references — no manual settings.json editing needed
- If the user's Claude Code version doesn't support plugins (< 1.0.33), fall back to manual skill installation using the skill files in `plugins/learn-toolkit/skills/` (see Option C in README)
