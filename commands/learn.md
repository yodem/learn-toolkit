# Deep Learning Workflow: Tavily + Exa -> NotebookLM

You are executing a structured learning workflow. The user wants to deeply learn about a topic using web research tools (Tavily, Exa) and then have all findings loaded into NotebookLM for podcast/infographic/mindmap/flashcard generation.

## Input

The user provides: **$ARGUMENTS** (a topic or technology to learn about)

If no topic is provided, ask the user what they want to learn about.

## Workflow Steps

### Phase 1: Multi-Source Research

Run Tavily and Exa searches **in parallel** to maximize coverage:

**Tavily Search** (use `mcp__tavily__tavily_search` or `mcp__tavily__search`):
- Search for the topic with `search_depth: "advanced"` and `include_raw_content: true`
- Search for "[topic] tutorial guide 2025 2026"
- Search for "[topic] best practices examples"
- If available, use `mcp__tavily__tavily_extract` to extract full content from the top 3-5 URLs

**Exa Search** (use `mcp__exa__web_search_exa` or `mcp__exa__web_search_advanced_exa`):
- Search for the topic with focus on documentation and guides
- Search for "[topic] architecture patterns"
- Use `mcp__exa__crawling_exa` on any particularly valuable URLs found

**WebSearch** (built-in, as fallback/supplement):
- Use if either Tavily or Exa is unavailable
- Search for official documentation links

### Phase 2: Organize & Deduplicate

1. Collect all URLs and content from both research tools
2. Deduplicate URLs
3. Categorize sources:
   - **Official docs** (highest priority)
   - **Tutorials & guides**
   - **Blog posts & articles**
   - **Code examples & repos**
   - **Comparison & alternatives**
4. Create a research summary as text (this becomes a source too)

### Phase 3: NotebookLM Setup

**Source limit: NotebookLM allows up to 50 sources per notebook.**

Track source count carefully. When approaching the limit, create a new notebook.

#### Notebook Creation Strategy:
- **Notebook 1**: `"[Topic] - Core Learning"` — official docs, tutorials, main articles
- **Notebook 2** (if needed): `"[Topic] - Deep Dive & Examples"` — code examples, comparisons, advanced content
- **Notebook 3** (if needed): `"[Topic] - Community & Alternatives"` — blog posts, discussions, alternatives

#### Adding Sources:

For each unique URL found:
```
mcp__notebooklm-mcp__source_add(
  notebook_id=<id>,
  source_type="url",
  url=<url>,
  wait=false  # don't wait for each one, batch them
)
```

For the research summary text:
```
mcp__notebooklm-mcp__source_add(
  notebook_id=<id>,
  source_type="text",
  title="Research Summary - [Topic]",
  text=<compiled research summary>,
  wait=true
)
```

**IMPORTANT:** After adding all sources, wait for processing. Use `mcp__notebooklm-mcp__studio_status` to verify sources are ready.

### Phase 4: Generate Learning Materials

For EACH notebook created, generate these artifacts **in parallel**:

1. **Audio Podcast** (Hebrew deep-dive):
```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="audio",
  audio_format="deep_dive",
  audio_length="default",
  language="he",
  focus_prompt="<focused prompt about what to cover>",
  confirm=true
)
```

2. **Infographic** (bento grid):
```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="infographic",
  orientation="portrait",
  detail_level="detailed",
  infographic_style="bento_grid",
  language="he",
  focus_prompt="<key concepts and relationships>",
  confirm=true
)
```

3. **Mind Map**:
```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="mind_map",
  title="<topic in Hebrew>",
  language="he",
  confirm=true
)
```

4. **Flashcards**:
```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="flashcards",
  difficulty="medium",
  language="he",
  confirm=true
)
```

### Phase 5: Poll & Report

1. Poll `studio_status` every 30 seconds until all artifacts are complete
2. Present a final summary table to the user:

```
## Learning Package: [Topic]

### Notebooks Created
| # | Notebook | ID | Sources | Link |
|---|----------|----|---------|------|
| 1 | [Topic] - Core | abc-123 | 23 | [Open](url) |
| 2 | [Topic] - Deep Dive | def-456 | 18 | [Open](url) |

### Artifacts Generated
| Notebook | Type | Status | Title |
|----------|------|--------|-------|
| Core | Podcast | Done | ... |
| Core | Infographic | Done | ... |
| Core | Mind Map | Done | ... |
| Core | Flashcards | Done | ... |

### Research Sources Summary
- X official documentation pages
- X tutorials and guides
- X blog posts and articles
- X code repositories
- Total unique sources: X
```

## State Tracking

Store notebook IDs in a temp file for the session:
```bash
echo '{"topic":"<topic>","notebooks":[{"id":"<id>","name":"<name>","source_count":0}],"total_sources":0}' > /tmp/learn-workflow-state.json
```

Update this file after each notebook creation and source addition. Read it before any operation to maintain state across tool calls.

## Error Handling

- If Tavily MCP is unavailable: fall back to Exa + WebSearch
- If Exa MCP is unavailable: fall back to Tavily + WebSearch
- If a source fails to add to NotebookLM: log it, continue with others
- If source limit (50) is hit: create new notebook, continue adding
- If studio generation fails: retry once, then report the failure

## Language Preference

- All NotebookLM artifacts should be generated in **Hebrew** (`language="he"`) by default
- The user can override this by specifying a language in their request
- Research is conducted in English (better coverage), artifacts are generated in Hebrew
