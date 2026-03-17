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

## Step 2: Ask which search backends the user wants

The `/visualize` and `/playground` skills work with NO API keys — they use built-in tools only.

The `/learn` skill benefits from search backends. Ask the user:

1. **Tavily** — "Do you want to use Tavily for web search? (free key at https://tavily.com) — yes/no"
2. **Exa** — "Do you want to use Exa for web + code search? (key at https://exa.ai) — yes/no"
3. **NotebookLM MCP** — "Do you have the notebooklm-mcp server installed? If not, I'll skip it — `/learn` will still do research, it just won't generate podcasts/infographics."

If the user doesn't want any search backends, still install all three skills. `/visualize` and `/playground` work immediately. `/learn` falls back to built-in WebSearch.

## Step 3: Configure MCP servers with env var references (SECURITY CRITICAL)

**NEVER ask the user to paste API keys into the chat.** Keys must never appear in conversation history, tool outputs, or config files.

Instead, configure MCP servers using `${ENV_VAR}` references that Claude Code resolves at runtime.

Read the user's `~/.claude/settings.json`. If it exists, merge the new MCP servers into the existing `mcpServers` object. If it doesn't exist, create it.

**Add these entries — note the `${VAR}` placeholders, NOT literal keys:**

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

IMPORTANT:
- Do NOT overwrite existing settings. Merge into the existing JSON structure.
- Do NOT put actual API key values in the config. Use `${TAVILY_API_KEY}` and `${EXA_API_KEY}` exactly as shown.
- Preserve all existing mcpServers, permissions, hooks, plugins, and other settings.

## Step 4: Guide the user to set environment variables

After writing the config, tell the user to add their API keys to their shell profile. Detect their shell first:

```bash
echo $SHELL
```

Then provide the appropriate instructions:

**For zsh (`~/.zshrc`):**
```
Add these lines to your ~/.zshrc (open it in your editor):

export TAVILY_API_KEY="your-tavily-key-here"
export EXA_API_KEY="your-exa-key-here"

Then run: source ~/.zshrc
```

**For bash (`~/.bashrc` or `~/.bash_profile`):**
```
Add these lines to your ~/.bashrc:

export TAVILY_API_KEY="your-tavily-key-here"
export EXA_API_KEY="your-exa-key-here"

Then run: source ~/.bashrc
```

CRITICAL SECURITY RULES:
- Do NOT offer to write the API keys to the shell profile for the user. The user must do this themselves.
- Do NOT ask the user to paste their key in the chat. Say: "Open your shell profile in your editor and add the export lines. Do not paste your key here."
- If the user pastes an API key in the chat anyway, warn them: "For security, API keys should not be shared in chat. Please rotate this key at [provider URL] and set the new one in your shell profile."
- When confirming setup, NEVER echo back or display any API key values. Only refer to them as `$TAVILY_API_KEY` / `$EXA_API_KEY`.

## Step 5: NotebookLM setup (if user has it)

If the user confirmed they have notebooklm-mcp:
- Check if it's already in their MCP config
- If not, ask how they installed it and help add the correct config entry
- Run `nlm login` if they need to authenticate

If the user doesn't have it:
- Tell them: "NotebookLM MCP is optional. `/learn` will still research your topic — it just won't auto-generate podcasts, infographics, and flashcards. You can add it later from https://github.com/nicholasgriffintn/notebooklm-mcp"

## Step 6: Confirm and instruct

After setup, tell the user:

---

Setup complete! Here's what was installed:

**3 skills installed to `~/.claude/skills/`:**

| Skill | Command | Ready? |
|-------|---------|--------|
| ASCII Visualizer | `/visualize <concept>` | Yes (no config needed) |
| Interactive Playground | `/playground <topic>` | Yes (no config needed) |
| Deep Learning | `/learn <topic>` | [Yes/Partial — list which MCP servers were configured] |

**MCP servers configured** (using environment variable references — no keys in config files):
- [list which ones were added, or "None — /visualize and /playground still work"]

**Remaining step — you need to do this yourself:**
1. Open your shell profile (`~/.zshrc` or `~/.bashrc`) in your editor
2. Add your API key exports (see the lines printed above)
3. Run `source ~/.zshrc` (or `~/.bashrc`)
4. Restart Claude Code (`/exit` then relaunch)

**Quick start — try these now (no restart needed):**
```
/visualize microservices architecture
/playground React vs Vue vs Svelte
```

**After setting env vars and restarting:**
```
/learn Kafka event streaming
```

**When to use which:**
- Quick concept, stay in terminal -> `/visualize`
- Compare options, explore interactively -> `/playground`
- Deep dive, new technology, team materials -> `/learn`

---

## Important notes for the AI assistant

- **NEVER ask for, display, or log API key values.** Not in chat, not in tool calls, not in file contents.
- Always read the user's existing settings.json before writing to it
- Config files must contain `${ENV_VAR}` references, NEVER literal key values
- If a user accidentally pastes a key, warn them to rotate it immediately
- `/visualize` and `/playground` need NO configuration — install and they work immediately
- If you cannot write to `~/.claude/` (permissions), suggest the user run the commands manually
- If the user is using a different AI tool (not Claude Code), explain that these skills are designed for Claude Code's skill system but the workflow logic in SKILL.md can be adapted
