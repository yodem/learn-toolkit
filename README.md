# /learn — Deep Learning Workflow for Claude Code

A Claude Code slash command that chains **Tavily**, **Exa**, and **NotebookLM** into an automated learning pipeline. Give it a topic, get back a full learning package: podcast, infographic, mind map, and flashcards.

## How It Works

```
/learn <topic>
```

```
Phase 1: Research (parallel)          Phase 2: Organize
  ├── Tavily (advanced search)   →      ├── Deduplicate URLs
  ├── Exa (web + code search)    →      ├── Categorize sources
  └── WebSearch (fallback)       →      └── Create research summary

Phase 3: NotebookLM                   Phase 4: Generate (parallel)
  ├── Create notebook(s)         →      ├── Hebrew podcast (deep dive)
  ├── Add URLs as sources        →      ├── Bento-grid infographic
  ├── Add research summary       →      ├── Mind map
  └── Overflow → new notebook    →      └── Flashcards

Phase 5: Poll & Report
  └── Final summary table with notebook links and artifact status
```

### Source Overflow Handling

NotebookLM allows up to **50 sources per notebook**. When the limit is reached, the workflow automatically creates additional notebooks:

| Notebook | Contents |
|----------|----------|
| `[Topic] - Core Learning` | Official docs, tutorials, main articles |
| `[Topic] - Deep Dive & Examples` | Code examples, comparisons, advanced content |
| `[Topic] - Community & Alternatives` | Blog posts, discussions, alternatives |

## Setup

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and working
- API keys for:
  - **Tavily** — get one at [tavily.com](https://tavily.com)
  - **Exa** — get one at [exa.ai](https://exa.ai)
  - **NotebookLM MCP** — requires the `notebooklm-mcp` server (see below)

### Step 1: Install the slash command

Copy the command file to your Claude Code commands directory:

```bash
# Global (available in all projects)
cp commands/learn.md ~/.claude/commands/learn.md

# Or project-level (available only in current project)
mkdir -p .claude/commands
cp commands/learn.md .claude/commands/learn.md
```

### Step 2: Configure MCP servers

Add the following to your `~/.claude/settings.json` under `"mcpServers"`:

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

Replace `YOUR_TAVILY_API_KEY` and `YOUR_EXA_API_KEY` with your actual keys.

### Step 3: Install NotebookLM MCP

The NotebookLM MCP server connects to Google's NotebookLM. Install it following the [notebooklm-mcp docs](https://github.com/nicholasgriffintn/notebooklm-mcp).

After installation, authenticate:

```bash
nlm login
```

### Step 4: Restart Claude Code

MCP servers load at session start. Restart Claude Code for the new servers to connect:

```bash
# Exit current session
/exit

# Relaunch
claude
```

### Step 5: Verify

Check that all three MCP servers are connected:

```bash
# In Claude Code, try:
/learn React Server Components
```

You should see parallel research happening across Tavily and Exa, followed by NotebookLM notebook creation.

## Usage Examples

```bash
# Learn a new technology
/learn Kafka event streaming

# Learn a programming language
/learn Rust ownership and borrowing

# Learn a framework
/learn Next.js App Router and Server Components

# Learn a concept
/learn distributed consensus algorithms

# Learn with language override (default is Hebrew)
/learn GraphQL federation --language en
```

## Output

The workflow produces a final summary like:

```
## Learning Package: Kafka Event Streaming

### Notebooks Created
| # | Notebook                          | Sources | Link          |
|---|-----------------------------------|---------|---------------|
| 1 | Kafka - Core Learning             | 28      | [Open](url)   |
| 2 | Kafka - Deep Dive & Examples      | 15      | [Open](url)   |

### Artifacts Generated
| Notebook | Type        | Status | Title                            |
|----------|-------------|--------|----------------------------------|
| Core     | Podcast     | Done   | יסודות קפקא ועיבוד אירועים      |
| Core     | Infographic | Done   | ארכיטקטורת קפקא בתמונה אחת      |
| Core     | Mind Map    | Done   | עולם קפקא - מפת מושגים          |
| Core     | Flashcards  | Done   | 12 כרטיסיות למידה                |
```

## Configuration

### Language

By default, all NotebookLM artifacts are generated in **Hebrew**. To change:

- Pass `--language en` (or any BCP-47 code) in your `/learn` invocation
- Or edit `learn.md` and change the default `language` parameter

### Research Depth

The workflow uses all three research backends in parallel. If one is unavailable, it gracefully falls back:

| Backend Available | Behavior |
|-------------------|----------|
| Tavily + Exa + WebSearch | Full parallel research (best coverage) |
| Tavily + WebSearch | Tavily primary, WebSearch supplement |
| Exa + WebSearch | Exa primary, WebSearch supplement |
| WebSearch only | Built-in search (still works, less depth) |

### Artifact Types

Edit `learn.md` to customize which artifacts are generated. Available types:

| Type | Parameter | Options |
|------|-----------|---------|
| Audio | `audio_format` | `deep_dive`, `brief`, `critique`, `debate` |
| Video | `video_format` | `explainer`, `brief`, `cinematic` |
| Infographic | `infographic_style` | `bento_grid`, `sketch_note`, `professional`, `editorial` |
| Slides | `slide_format` | `detailed_deck`, `presenter_slides` |
| Report | `report_format` | `Briefing Doc`, `Study Guide`, `Blog Post` |
| Flashcards | `difficulty` | `easy`, `medium`, `hard` |
| Quiz | `question_count` | any integer |
| Mind Map | — | auto-generated |

## File Structure

```
claude-learn-workflow/
├── README.md              # This file
├── commands/
│   └── learn.md           # The slash command (copy to ~/.claude/commands/)
└── examples/
    └── settings-snippet.json  # MCP server config to merge into settings.json
```

## Context: The 3-Step Learning Framework

This tool implements **Step 3** of a developer learning framework:

| Step | Tool | Environment | When to Use |
|------|------|-------------|-------------|
| 1 | ASCII Visualizer | Terminal | Quick concept, don't want to leave CLI |
| 2 | Playground (HTML) | Browser | Compare alternatives, interactive exploration |
| **3** | **NotebookLM + /learn** | **Web / MCP** | **Deep learning, new tech, team materials** |

## License

MIT
