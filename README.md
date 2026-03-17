# Three Steps for Learning and Visualization with Claude Code

A 3-skill toolkit for learning new technologies without leaving your workflow. Escalate from quick terminal diagrams, through interactive browser exploration, to full AI-generated learning packages.

| Step | Skill | Environment | When to use |
|------|-------|-------------|-------------|
| 1 | `/visualize` | Terminal | Quick flowchart or architecture diagram, stay in CLI |
| 2 | `/playground` | Browser (HTML) | Compare alternatives, explore parameters interactively |
| 3 | `/learn` | Web / MCP | Deep learning with podcast, infographic, mind map, flashcards |

## Quick Install

Paste this repo URL into Claude Code and it sets everything up:

```
https://github.com/YOUR_USERNAME/claude-learn-workflow
```

Claude reads the `CLAUDE.md` and:
1. Installs all 3 skills (`/visualize`, `/playground`, `/learn`)
2. `/visualize` and `/playground` work immediately — no API keys needed
3. Asks for Tavily/Exa keys for `/learn` (optional — falls back to built-in search)
4. Configures MCP servers and sets up NotebookLM (optional)

> Works with any AI coding assistant that reads `CLAUDE.md` — Claude Code, Cursor, Windsurf, etc.

## Manual Setup

<details>
<summary>Click to expand manual setup steps</summary>

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- API keys for:
  - **Tavily** — [tavily.com](https://tavily.com)
  - **Exa** — [exa.ai](https://exa.ai)
  - **NotebookLM MCP** — `notebooklm-mcp` server (optional)

### Step 1: Install the skill

```bash
mkdir -p ~/.claude/skills/learn/references
cp skills/learn/SKILL.md ~/.claude/skills/learn/SKILL.md
cp skills/learn/references/*.md ~/.claude/skills/learn/references/
```

### Step 2: Configure MCP servers

Add to `~/.claude/settings.json` under `"mcpServers"`:

```json
{
  "mcpServers": {
    "tavily": {
      "type": "url",
      "url": "https://mcp.tavily.com/mcp/?tavilyApiKey=YOUR_TAVILY_API_KEY"
    },
    "exa": {
      "type": "url",
      "url": "https://mcp.exa.ai/mcp?exaApiKey=YOUR_EXA_API_KEY&tools=web_search_exa,web_search_advanced_exa,get_code_context_exa,crawling_exa,company_research_exa,people_search_exa,deep_researcher_start,deep_researcher_check"
    }
  }
}
```

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

## The Three Skills

### Step 1: `/visualize` — ASCII Diagrams in Terminal

```
/visualize <concept>
```

Generates flowcharts, architecture diagrams, sequence diagrams, decision trees, and comparison tables directly in the terminal using Unicode box-drawing characters. No files created, no browser needed.

```
/visualize user login flow
/visualize microservices with API gateway
/visualize REST vs GraphQL vs gRPC
```

**No API keys or MCP servers required.** Works immediately after install.

### Step 2: `/playground` — Interactive HTML Explorer

```
/playground <topic>
```

Generates a standalone HTML file with interactive controls (sliders, toggles, tabs) for exploring parameters, comparing alternatives, and making decisions. Opens in your default browser.

```
/playground PostgreSQL vs MongoDB vs Redis
/playground REST API pagination strategies
/playground monolith vs microservices for team of 5
```

**No API keys or MCP servers required.** Works immediately after install.

### Step 3: `/learn` — Deep Learning Package via NotebookLM

```
/learn <topic>
```

Researches a topic across Tavily, Exa, and web search in parallel, loads everything into NotebookLM, and generates a full learning package.

```
/learn Kafka event streaming
/learn Rust ownership and borrowing
/learn Next.js App Router --language en
```

**Requires API keys** for Tavily/Exa (optional — falls back to WebSearch) and NotebookLM MCP (optional — skips artifact generation without it).

#### /learn Pipeline

```
Phase 1: Research (parallel)          Phase 2: Organize
  ├── Tavily (advanced search)   ->     ├── Deduplicate URLs
  ├── Exa (web + code search)    ->     ├── Categorize sources
  └── WebSearch (fallback)       ->     └── Create research summary

Phase 3: NotebookLM                   Phase 4: Generate (parallel)
  ├── Create notebook(s)         ->     ├── Hebrew podcast (deep dive)
  ├── Add URLs as sources        ->     ├── Bento-grid infographic
  ├── Add research summary       ->     ├── Mind map
  └── Overflow -> new notebook   ->     └── Flashcards
```

NotebookLM allows up to **50 sources per notebook**. Overflow automatically creates additional notebooks.

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

### Environment Variable Support

`.mcp.json` supports `${VAR}` and `${VAR:-default}` syntax so you can commit configs without hardcoding secrets:

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

### Team Sharing

To share the skill with your team, add it to your project's `.claude/skills/` directory and commit to git. Team members get the skill automatically without any setup.

</details>

## Usage

```bash
# Learn a new technology
/learn Kafka event streaming

# Learn a programming language
/learn Rust ownership and borrowing

# Learn a framework
/learn Next.js App Router and Server Components

# Learn a concept
/learn distributed consensus algorithms

# Override language (default is Hebrew)
/learn GraphQL federation --language en
```

## Output

```
## Learning Package: Kafka Event Streaming

### Notebooks
| # | Notebook                     | Sources | Link        |
|---|------------------------------|---------|-------------|
| 1 | Kafka - Core Learning        | 28      | [Open](url) |
| 2 | Kafka - Deep Dive            | 15      | [Open](url) |

### Artifacts
| Notebook | Type        | Status | Title                       |
|----------|-------------|--------|-----------------------------|
| Core     | Podcast     | Done   | יסודות קפקא ועיבוד אירועים |
| Core     | Infographic | Done   | ארכיטקטורת קפקא             |
| Core     | Mind Map    | Done   | עולם קפקא - מפת מושגים     |
| Core     | Flashcards  | Done   | 12 כרטיסיות למידה           |
```

## Configuration

### Language

Default: **Hebrew** (`he`). Override per-invocation or edit `SKILL.md`.

### Research Backends

All three run in parallel with graceful fallback:

| Available | Behavior |
|-----------|----------|
| Tavily + Exa + WebSearch | Full coverage (best) |
| Tavily + WebSearch | Tavily primary |
| Exa + WebSearch | Exa primary |
| WebSearch only | Built-in only (reduced depth) |

### Artifact Types

Default: podcast + infographic + mind map + flashcards. Additional types available in `references/artifact-generation.md`:

| Type | Options |
|------|---------|
| Audio | `deep_dive`, `brief`, `critique`, `debate` |
| Infographic | `bento_grid`, `sketch_note`, `professional`, `editorial` |
| Video | `explainer`, `brief`, `cinematic` |
| Slides | `detailed_deck`, `presenter_slides` |
| Report | `Briefing Doc`, `Study Guide`, `Blog Post` |

## File Structure

```
claude-learn-workflow/
├── CLAUDE.md                                 # AI reads this for automated setup
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
│           └── artifact-generation.md        # NotebookLM tool signatures
├── commands/
│   └── learn.md                              # Legacy command (alternative)
└── examples/
    └── settings-snippet.json                 # MCP config template
```

## License

MIT
