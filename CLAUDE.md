# Setup Instructions for AI Assistants

When a user shares this repository URL, your job is to install **three learning skills** and configure the required MCP servers. Follow these steps exactly.

## What gets installed

This repo provides a 3-step learning toolkit for Claude Code:

| Skill | Purpose | Environment | When to use |
|-------|---------|-------------|-------------|
| `/visualize` | ASCII flowcharts, architecture diagrams, tables | Terminal | Quick concept, don't want to leave CLI |
| `/playground` | Interactive HTML for comparing options, exploring parameters | Browser | Need to see alternatives, tweak settings |
| `/learn` | Full research + NotebookLM learning package (podcast, infographic, mind map, flashcards) | Web / MCP | Deep learning, new tech, team materials |

## Step 1: Install all three skills

```bash
mkdir -p ~/.claude/skills/visualize
mkdir -p ~/.claude/skills/playground
mkdir -p ~/.claude/skills/learn/references
```

Then copy these files from this repo using the Write tool (read each file from this repo first):

**Skill 1 — /visualize:**
- `skills/visualize/SKILL.md` -> `~/.claude/skills/visualize/SKILL.md`

**Skill 2 — /playground:**
- `skills/playground/SKILL.md` -> `~/.claude/skills/playground/SKILL.md`

**Skill 3 — /learn:**
- `skills/learn/SKILL.md` -> `~/.claude/skills/learn/SKILL.md`
- `skills/learn/references/notebooklm-loading.md` -> `~/.claude/skills/learn/references/notebooklm-loading.md`
- `skills/learn/references/artifact-generation.md` -> `~/.claude/skills/learn/references/artifact-generation.md`

## Step 2: Collect API keys from the user

The `/visualize` and `/playground` skills work with NO API keys — they use built-in tools only.

The `/learn` skill needs search backends. Ask the user:

1. **Tavily API key** — "Do you have a Tavily API key? Get one free at https://tavily.com if not."
2. **Exa API key** — "Do you have an Exa API key? Get one at https://exa.ai if not."
3. **NotebookLM MCP** — "Do you have the notebooklm-mcp server installed? If not, I'll skip NotebookLM setup — `/learn` will still do research, it just won't generate podcasts/infographics."

If the user doesn't have any API keys, still install all three skills. `/visualize` and `/playground` work immediately. `/learn` will fall back to built-in WebSearch.

## Step 3: Configure MCP servers (only if user provided API keys)

Read the user's `~/.claude/settings.json`. If it exists, merge the new MCP servers into the existing `mcpServers` object. If it doesn't exist, create it.

Add these entries (replacing API keys with the user's actual keys):

```json
{
  "mcpServers": {
    "tavily": {
      "type": "url",
      "url": "https://mcp.tavily.com/mcp/?tavilyApiKey=USER_TAVILY_KEY"
    },
    "exa": {
      "type": "url",
      "url": "https://mcp.exa.ai/mcp?exaApiKey=USER_EXA_KEY&tools=web_search_exa,web_search_advanced_exa,get_code_context_exa,crawling_exa,company_research_exa,people_search_exa,deep_researcher_start,deep_researcher_check"
    }
  }
}
```

IMPORTANT: Do NOT overwrite existing settings. Merge into the existing JSON structure. Preserve all existing mcpServers, permissions, hooks, plugins, and other settings.

## Step 4: NotebookLM setup (if user has it)

If the user confirmed they have notebooklm-mcp:
- Check if it's already in their MCP config
- If not, ask how they installed it and help add the correct config entry
- Run `nlm login` if they need to authenticate

If the user doesn't have it:
- Tell them: "NotebookLM MCP is optional. `/learn` will still research your topic — it just won't auto-generate podcasts, infographics, and flashcards. You can add it later from https://github.com/nicholasgriffintn/notebooklm-mcp"

## Step 5: Confirm and instruct

After setup, tell the user:

---

Setup complete! Here's what was installed:

**3 skills installed to `~/.claude/skills/`:**

| Skill | Command | Ready? |
|-------|---------|--------|
| ASCII Visualizer | `/visualize <concept>` | Yes (no API keys needed) |
| Interactive Playground | `/playground <topic>` | Yes (no API keys needed) |
| Deep Learning | `/learn <topic>` | [Yes/Partial — list which MCP servers were configured] |

**MCP servers configured:**
- [list which ones were added, or "None — /visualize and /playground still work"]

**Quick start — try these now (no restart needed for /visualize and /playground):**
```
/visualize microservices architecture
/playground React vs Vue vs Svelte
```

**For /learn (requires restart to load MCP servers):**
1. Restart Claude Code (`/exit` then relaunch)
2. Then: `/learn Kafka event streaming`

**When to use which:**
- Quick concept, stay in terminal → `/visualize`
- Compare options, explore interactively → `/playground`
- Deep dive, new technology, team materials → `/learn`

---

## Important notes for the AI assistant

- Always read the user's existing settings.json before writing to it
- Never expose or log API keys in visible output
- `/visualize` and `/playground` need NO configuration — install and they work immediately
- If you cannot write to `~/.claude/` (permissions), suggest the user run the commands manually
- If the user is using a different AI tool (not Claude Code), explain that these skills are designed for Claude Code's skill system but the workflow logic in SKILL.md can be adapted
