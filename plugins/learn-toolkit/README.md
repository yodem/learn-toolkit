# Three Steps for Learning and Visualization with Claude Code

A 3-skill toolkit for learning new technologies without leaving your workflow. Escalate from quick terminal diagrams, through interactive browser exploration, to full AI-generated learning packages.

| Step | Skill | Environment | When to use |
|------|-------|-------------|-------------|
| 1 | `/learn-toolkit:visualize` | Terminal | Quick flowchart or architecture diagram, stay in CLI |
| 2 | `/learn-toolkit:playground` | Browser (HTML) | Compare alternatives, explore parameters interactively |
| 3 | `/learn-toolkit:learn` | Terminal + Browser + Web | **All 3 steps combined:** ASCII diagram + interactive playground + NotebookLM package with study guide |

## Install

### Option A: Plugin install (recommended)

```
/plugin marketplace add yodem/learn-toolkit
/plugin install learn-toolkit@learn-toolkit-marketplace
```

This installs all 3 skills, configures MCP servers (via env vars), and handles updates automatically.

Then add your API keys to `~/.zshrc` (or `~/.bashrc`):

```bash
export TAVILY_API_KEY="your-key-here"   # https://tavily.com (free)
export EXA_API_KEY="your-key-here"      # https://exa.ai
```

Restart Claude Code. Done.

> `/learn-toolkit:visualize` and `/learn-toolkit:playground` work immediately — no API keys needed. Keys are only required for `/learn-toolkit:learn`'s search backends.

### Option B: Paste repo URL

Paste this URL into Claude Code and it reads `CLAUDE.md` to walk you through setup:

```
https://github.com/yodem/learn-toolkit
```

> Also works with Cursor, Windsurf, and other AI tools that read `CLAUDE.md`.

### Option C: Manual setup

<details>
<summary>Click to expand manual steps</summary>

See [Prerequisites](#prerequisites) above for required API keys and tools.

### Step 1: Install the skill

```bash
mkdir -p ~/.claude/skills/learn/references
cp skills/learn/SKILL.md ~/.claude/skills/learn/SKILL.md
cp skills/learn/references/*.md ~/.claude/skills/learn/references/
```

### Step 2: Configure MCP servers

Add to `~/.claude/settings.json` under `"mcpServers"` — note the `${VAR}` references, not literal keys:

```json
{
  "mcpServers": {
    "tavily": {
      "type": "url",
      "url": "https://mcp.tavily.com/mcp/?tavilyApiKey=${TAVILY_API_KEY}"
    },
    "exa": {
      "type": "url",
      "url": "https://mcp.exa.ai/mcp?exaApiKey=${EXA_API_KEY}&tools=web_search_exa,web_search_advanced_exa,get_code_context_exa,crawling_exa,company_research_exa,people_search_exa,deep_researcher_start,deep_researcher_check"
    }
  }
}
```

Then add your actual keys to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
export TAVILY_API_KEY="tvly-your-key-here"
export EXA_API_KEY="your-exa-key-here"
```

This way your config file contains no secrets and can be safely shared or committed.

### Step 3: Install NotebookLM MCP (optional)

```bash
# See https://github.com/nicholasgriffintn/notebooklm-mcp
nlm login
```

### Step 4: Restart Claude Code

```bash
/exit
claude
```

</details>

## Tavily Agent Skills (recommended)

Install Tavily's agent skills to give `/learn-toolkit:learn` a CLI-based fallback and add standalone search/extract/crawl/research capabilities:

```bash
npx skills add tavily-ai/skills --yes
curl -fsSL https://cli.tavily.com/install.sh | bash
tvly login    # opens browser for OAuth, or: tvly login --api-key tvly-YOUR_KEY
```

This installs 7 skills as slash commands:

| Skill | Slash Command | CLI Command | Purpose |
|-------|---------------|-------------|---------|
| `tavily-search` | `/tavily-search` | `tvly search "query" --json` | Web search with LLM-optimized results |
| `tavily-extract` | `/tavily-extract` | `tvly extract "url"` | Extract content from specific URLs |
| `tavily-crawl` | `/tavily-crawl` | `tvly crawl "url" --output-dir ./docs/` | Crawl site sections to local markdown |
| `tavily-map` | `/tavily-map` | `tvly map "url"` | Discover URLs on a domain |
| `tavily-research` | `/tavily-research` | `tvly research "topic" --json` | Deep multi-source research with citations |
| `tavily-cli` | `/tavily-cli` | `tvly --help` | Unified CLI reference |
| `tavily-best-practices` | `/tavily-best-practices` | — | Integration patterns and guidance |

**Workflow escalation:** search → extract → map → crawl → research

**Integration with `/learn-toolkit:learn`:** The learn workflow auto-detects Tavily CLI alongside the MCP server. If MCP is available, it uses MCP for search and CLI skills for extract/crawl. If only the CLI is installed, skills handle all Tavily operations. Either path provides full Tavily coverage.

## The Three Skills

### Step 1: `/learn-toolkit:visualize` — ASCII Diagrams in Terminal

```
/learn-toolkit:visualize <concept>
```

Generates flowcharts, architecture diagrams, sequence diagrams, decision trees, and comparison tables directly in the terminal using Unicode box-drawing characters. No files created, no browser needed.

```
/learn-toolkit:visualize user login flow
/learn-toolkit:visualize microservices with API gateway
/learn-toolkit:visualize REST vs GraphQL vs gRPC
```

**No API keys or MCP servers required.** Works immediately after install.

### Step 2: `/learn-toolkit:playground` — Interactive HTML Explorer

```
/learn-toolkit:playground <topic>
```

Generates a standalone HTML file with interactive controls (sliders, toggles, tabs) for exploring parameters, comparing alternatives, and making decisions. Opens in your default browser.

```
/learn-toolkit:playground PostgreSQL vs MongoDB vs Redis
/learn-toolkit:playground REST API pagination strategies
/learn-toolkit:playground monolith vs microservices for team of 5
```

**No API keys or MCP servers required.** Works immediately after install.

### Step 3: `/learn-toolkit:learn` — Complete Learning Package (All 3 Steps)

```
/learn-toolkit:learn <topic>
```

The full learning workflow that combines all three steps. Researches a topic across Tavily and Exa in parallel, optionally reads from your CandleKeep library, then generates:

1. **ASCII diagram** in the terminal (architecture, flowchart, or comparison table)
2. **Interactive playground** in the browser (parameter explorer, decision matrix, or comparison tool)
3. **NotebookLM package** with podcast, infographic, mind map, flashcards, and **implementation study guide**

```
/learn-toolkit:learn Kafka event streaming
/learn-toolkit:learn Rust ownership and borrowing
/learn-toolkit:learn Next.js App Router --language en
```

**Requires API keys** for Tavily/Exa and NotebookLM MCP (workflow stops with setup instructions if missing). **Optional:** CandleKeep (`ck` CLI) for library read/write integration.

#### /learn Pipeline

```
Phase 0: Discover tools               Phase 0.5: CandleKeep scan (optional)
  ├── Tavily MCP or CLI?         ->     ├── ck items list --json
  ├── Exa MCP?                   ->     ├── Match titles to topic
  ├── NotebookLM MCP?            ->     └── Read up to 3 matching items
  └── CandleKeep CLI?

Phase 1: Research (parallel)          Phase 2: Organize
  ├── Tavily MCP or CLI          ->     ├── Deduplicate URLs
  └── Exa (web + code search)   ->     ├── Categorize (docs > library > tutorials > articles)
                                        └── Create research summary

Phase 2.5: Save local MD files        Phase 3: NotebookLM
  ├── /tmp/learn-<slug>/         ->     ├── Create notebook(s)
  ├── README.md + summary        ->     ├── Add CandleKeep text sources
  └── sources/ (by category)     ->     ├── Add URL sources
                                        ├── Add research summary
                                        └── Overflow -> new notebook

Phase 4: Generate (parallel)          Phase 5: Poll + Report
  ├── Hebrew podcast (deep dive) ->     └── Summary table with all artifacts
  ├── Bento-grid infographic
  ├── Mind map                   Phase 5.5: Write to CandleKeep (--ck-write)
  ├── Flashcards                   ├── Compile book.md
  └── Implementation study guide   └── ck items create + put

Phase 6: 3-Step Integration
  ├── Step 1: ASCII diagram in terminal (architecture/flow/comparison)
  ├── Step 2: Interactive HTML playground in browser
  └── Step 3: NotebookLM + CandleKeep + local files summary
```

NotebookLM allows up to **50 sources per notebook**. Overflow automatically creates additional notebooks.

## Prerequisites

The `/learn-toolkit:visualize` and `/learn-toolkit:playground` skills work immediately — no setup needed.

The `/learn-toolkit:learn` skill requires three backends and supports one optional integration:

### 1. Tavily (required) — Web Search

Tavily provides LLM-optimized web search and content extraction.

**Option A: Tavily CLI (recommended)**
```bash
curl -fsSL https://cli.tavily.com/install.sh | bash
tvly login                                        # opens browser for OAuth
# or: tvly login --api-key tvly-YOUR_KEY
```

Optionally install agent skills for slash commands:
```bash
npx skills add tavily-ai/skills --yes
```

**Option B: Tavily MCP server**

Add `export TAVILY_API_KEY="your-key"` to `~/.zshrc` (get a free key at [tavily.com](https://tavily.com)), then restart Claude Code. The plugin's `.mcp.json` picks it up automatically.

### 2. Exa (required) — Code & Documentation Search

Exa specializes in code-aware and documentation-focused search.

Add to `~/.zshrc` (get a key at [exa.ai](https://exa.ai)):
```bash
export EXA_API_KEY="your-exa-key-here"
```

Then `source ~/.zshrc` and restart Claude Code.

### 3. NotebookLM (required) — Learning Artifacts

NotebookLM generates podcasts, infographics, mind maps, flashcards, and study guides.

Install from [notebooklm-mcp](https://github.com/nicholasgriffintn/notebooklm-mcp), then authenticate:
```bash
nlm login
```

### 4. CandleKeep (optional) — Library Integration

CandleKeep provides bidirectional library integration. If the `ck` CLI is available, `/learn` will:

- **Read** (on by default): Scan your CandleKeep library for existing documents on the topic before researching. Disable with `--no-ck-read`
- **Write** (off by default): Compile all research into a structured book and upload it to your library. Enable with `--ck-write`

Install via the `candlekeep-cloud` Claude Code plugin. Once `ck` is on your PATH, `/learn` detects it automatically.

```bash
# Learn and save the research as a book to CandleKeep
/learn-toolkit:learn Kafka event streaming --ck-write
```

The compiled book includes an executive summary, 3-5 topic-adapted chapters, and a source index. It's saved locally at `/tmp/learn-<topic>/book.md` regardless, but `--ck-write` also uploads it to your CandleKeep library as a permanent reference.

If `ck` is not installed, CandleKeep phases are silently skipped — no errors, no interruptions.

## Advanced Setup Options

<details>
<summary>MCP server scoping, env vars, and team sharing</summary>

### MCP Server Scoping

| Scope | Where | Use case |
|-------|-------|----------|
| User (recommended) | `~/.claude/settings.json` | Available in all projects |
| Project | `.mcp.json` in project root | Shared with team via git |
| Local | `.claude/settings.local.json` | Per-machine, gitignored |

When servers share the same name across scopes, local wins over project, project wins over user.

### Security: API keys via environment variables

API keys are **never stored in config files**. Both `settings.json` and `.mcp.json` support `${VAR}` and `${VAR:-default}` syntax — the actual key is resolved at runtime from your shell environment:

```json
{
  "mcpServers": {
    "tavily": {
      "type": "url",
      "url": "https://mcp.tavily.com/mcp/?tavilyApiKey=${TAVILY_API_KEY}"
    }
  }
}
```

Keys live in your shell profile (`~/.zshrc` / `~/.bashrc`) where they're standard for CLI dev tools. This means:
- Config files contain no secrets and can be safely shared/committed
- Keys are easy to rotate (change the env var, restart Claude Code)
- No keys appear in conversation history or AI tool logs

### Team Sharing

To share the skill with your team, add it to your project's `.claude/skills/` directory and commit to git. Team members get the skill automatically without any setup.

</details>

## Usage

```bash
# Learn a new technology
/learn-toolkit:learn Kafka event streaming

# Learn a framework (English output)
/learn-toolkit:learn Next.js App Router --language en

# Learn and save research as a book to CandleKeep
/learn-toolkit:learn Rust ownership and borrowing --ck-write

# Skip CandleKeep library scan
/learn-toolkit:learn distributed consensus algorithms --no-ck-read
```

## Output

```
## Complete Learning Package: Kafka Event Streaming

### Step 1: Quick Visual (Terminal)
[ASCII architecture diagram of Kafka clusters, topics, partitions]

### Step 2: Interactive Explorer (Browser)
File: /tmp/playground-kafka-event-streaming.html

### Step 3: Deep Learning (NotebookLM)
| # | Notebook                     | Sources | Link        |
|---|------------------------------|---------|-------------|
| 1 | Kafka - Core Learning        | 28      | [Open](url) |
| 2 | Kafka - Deep Dive            | 15      | [Open](url) |

| Notebook | Type        | Status | Title                       |
|----------|-------------|--------|-----------------------------|
| Core     | Podcast     | Done   | יסודות קפקא ועיבוד אירועים |
| Core     | Infographic | Done   | ארכיטקטורת קפקא             |
| Core     | Mind Map    | Done   | עולם קפקא - מפת מושגים     |
| Core     | Flashcards  | Done   | 12 כרטיסיות למידה           |
| Core     | Study Guide | Done   | מדריך יישום קפקא            |

### CandleKeep
| Direction | Items | Details                                    |
|-----------|-------|--------------------------------------------|
| Read      | 2     | "Kafka Basics", "Event-Driven Architecture"|
| Write     | 1     | Item #42 - "Kafka - Research Compendium"   |

### Local Files
Research saved to: /tmp/learn-kafka-event-streaming/
```

## Configuration

### Language

Default: **Hebrew** (`he`). Override per-invocation or edit `SKILL.md`.

### Research Backends

Tavily (MCP or CLI) and Exa are required. The workflow checks for them at startup and shows setup instructions if missing:

| Available | Behavior |
|-----------|----------|
| Tavily MCP + Exa + NotebookLM | Full coverage via MCP (best) |
| Tavily CLI + Exa + NotebookLM | CLI for Tavily, MCP for Exa |
| + CandleKeep (`ck` CLI) | Scans library for existing knowledge, optionally writes book back |
| Missing Tavily, Exa, or NotebookLM | Workflow stops with setup instructions |

### Artifact Types

Default: podcast + infographic + mind map + flashcards + **study guide** (implementation-focused with action items). Additional types available in `references/artifact-generation.md`:

| Type | Options |
|------|---------|
| Audio | `deep_dive`, `brief`, `critique`, `debate` |
| Infographic | `bento_grid`, `sketch_note`, `professional`, `editorial` |
| Video | `explainer`, `brief`, `cinematic` |
| Slides | `detailed_deck`, `presenter_slides` |
| Report | `Briefing Doc`, `Study Guide`, `Blog Post` |

## File Structure

```
learn-toolkit/
├── .claude-plugin/
│   ├── plugin.json                           # Plugin manifest (name, version, metadata)
│   └── marketplace.json                      # Marketplace catalog for /plugin install
├── .mcp.json                                 # MCP servers (Tavily, Exa) with ${ENV_VAR} refs
├── CLAUDE.md                                 # AI reads this for paste-URL setup flow
├── README.md
├── LICENSE
├── skills/
│   ├── visualize/
│   │   └── SKILL.md                          # Step 1: ASCII diagrams
│   ├── playground/
│   │   └── SKILL.md                          # Step 2: Interactive HTML
│   └── learn/
│       ├── SKILL.md                          # Step 3: Deep learning
│       └── references/
│           ├── notebooklm-loading.md         # Notebook overflow logic
│           ├── artifact-generation.md        # NotebookLM tool signatures
│           └── candlekeep-integration.md     # CandleKeep read/write reference
└── .gitignore
```

## License

MIT
