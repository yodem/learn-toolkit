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

This installs all 3 skills and configures MCP servers automatically:
- `/learn-toolkit:visualize` — ASCII diagrams in terminal (no config needed)
- `/learn-toolkit:playground` — Interactive HTML explorer (no config needed)
- `/learn-toolkit:learn` — Tavily + Exa research into NotebookLM packages, with optional CandleKeep library integration

### Step 2: Set up API keys for /learn (optional)

The `/learn-toolkit:visualize` and `/learn-toolkit:playground` skills work immediately with no API keys.

For `/learn-toolkit:learn`, the plugin's `.mcp.json` configures Tavily and Exa servers using environment variable references (`${TAVILY_API_KEY}`, `${EXA_API_KEY}`). The user needs to set these in their shell profile.

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

If the user doesn't have API keys, `/learn-toolkit:learn` will detect the missing backends at startup and show setup instructions. `/learn-toolkit:visualize` and `/learn-toolkit:playground` work with no keys at all.

### Step 2b: Install Tavily Agent Skills (recommended)

The Tavily agent skills give `/learn-toolkit:learn` a CLI-based fallback when the Tavily MCP server isn't available, and provide standalone `tvly` commands for direct web search, extraction, crawling, and research.

**Install the skills and CLI:**

```bash
npx skills add tavily-ai/skills --yes
curl -fsSL https://cli.tavily.com/install.sh | bash
tvly login
```

The `tvly login` command opens a browser for OAuth, or use `tvly login --api-key` with the same key from Step 2.

This installs 7 skills:
- `/tavily-search` — LLM-optimized web search
- `/tavily-extract` — Extract content from URLs
- `/tavily-crawl` — Crawl websites to local markdown
- `/tavily-map` — Discover URLs on a domain
- `/tavily-research` — AI-synthesized deep research with citations
- `/tavily-cli` — Unified CLI reference
- `/tavily-best-practices` — Integration guidance

**How it works with `/learn-toolkit:learn`:** The learn workflow auto-detects whether Tavily MCP or the Tavily CLI is available. If MCP is configured, it uses MCP for search and Tavily skills for extract/crawl. If only the CLI is installed, it uses the skills for everything. Either way, the user gets full Tavily coverage.

### Step 3: NotebookLM (optional)

If the user wants podcast/infographic generation:
- Check if they have `notebooklm-mcp` installed
- If not: "NotebookLM is optional. `/learn-toolkit:learn` will still research your topic — it just won't generate podcasts, infographics, and flashcards. Add it later from https://github.com/nicholasgriffintn/notebooklm-mcp"

### Step 3b: CandleKeep (optional)

If the user has `candlekeep-cloud` installed (with the `ck` CLI available), `/learn-toolkit:learn` will automatically:
- **Read** from their CandleKeep library for existing knowledge on the topic (on by default, disable with `--no-ck-read`)
- **Write** a compiled research book back to CandleKeep (off by default, enable with `--ck-write`)

CandleKeep is never required — the workflow skips it silently if `ck` is not installed.

### Step 4: Confirm

Tell the user:

---

Plugin **learn-toolkit** installed. Here's what you have:

| Skill | Command | Ready? |
|-------|---------|--------|
| ASCII Visualizer | `/learn-toolkit:visualize <concept>` | Yes |
| Interactive Playground | `/learn-toolkit:playground <topic>` | Yes |
| Deep Learning | `/learn-toolkit:learn <topic>` | After setting env vars + restart |
| CandleKeep (optional) | `--ck-write` to save, `--no-ck-read` to skip | If `ck` CLI installed |
| Tavily Agent Skills | `/tavily-search`, `/tavily-research`, `tvly` CLI | After Step 2b (`npx skills add` + `tvly login`) |

**Try now (no restart needed):**
```
/learn-toolkit:visualize microservices architecture
/learn-toolkit:playground React vs Vue vs Svelte
```

**After env vars + restart:**
```
/learn-toolkit:learn Kafka event streaming
```

**After Tavily skills install (Step 2b):**
```
/tavily-search "Claude Code plugins"
/tavily-research "RAG architecture patterns"
tvly crawl "https://docs.example.com" --output-dir ./docs/
```

**When to use which:**
- Quick concept, stay in terminal -> `/learn-toolkit:visualize`
- Compare options, explore interactively -> `/learn-toolkit:playground`
- Deep dive, new technology, team materials -> `/learn-toolkit:learn`
- Deep dive + save to library -> `/learn-toolkit:learn <topic> --ck-write`
- Direct web search/extract/crawl -> `/tavily-search`, `/tavily-extract`, `/tavily-crawl`
- Comprehensive research with citations -> `/tavily-research`

---

## Important notes for the AI assistant

- **NEVER ask for, display, or log API key values.** Not in chat, not in tool calls, not in file contents.
- If a user accidentally pastes a key, warn them to rotate it immediately
- The plugin bundles MCP configs via `.mcp.json` with `${ENV_VAR}` references — no manual settings.json editing needed
- If the user's Claude Code version doesn't support plugins (< 1.0.33), fall back to manual skill installation using the files in `skills/`
