# learn-toolkit

A Claude Code plugin marketplace with one plugin: **learn-toolkit**, a single skill,
`/learn-toolkit:learn <subject>`, for deep-diving into a technology, a philosophical
concept, or a Jewish text with domain-aware research routing across Tavily, Exa,
Sefaria, and CandleKeep, and an optional NotebookLM learning package.

```
/learn-toolkit:learn <subject> [--domain tech|philosophy|judaism] [--language <code>] [--no-notebook] [--deep[=high|xhigh]]
```

Full documentation — domains, backends, setup, flags, examples, output layout, and API
key safety — lives in the plugin itself:
[`plugins/learn-toolkit/README.md`](plugins/learn-toolkit/README.md).

## Install

### Option A: Plugin install (recommended)

```
/plugin marketplace add yodem/learn-toolkit
/plugin install learn-toolkit@learn-toolkit-marketplace
```

This registers the marketplace, installs the `learn-toolkit` plugin, and configures its
MCP servers (Tavily, Exa, and Exa Agent) with optional sensitive keys stored in the system keychain. Installation prompts for both keys; Exa search works keyless. A blank Tavily key leaves the Tavily MCP unusable. `/learn` then uses the `tvly` CLI (keyless search and extract work without login; run `tvly login` or `tvly init --agent claude-code` for full access), or enter the key with `/plugin configure learn-toolkit@learn-toolkit-marketplace`. Change keys with `/plugin configure learn-toolkit@learn-toolkit-marketplace`. Non-interactive `claude plugin install learn-toolkit@learn-toolkit-marketplace --config exa_api_key=…` is for CI only. Never paste keys in chat. `/learn-toolkit:learn` needs at least one of Tavily or Exa to run;
everything else (Sefaria, CandleKeep, NotebookLM) is optional. See the plugin README for
what degrades when each is absent.

### Option B: Manual setup

<details>
<summary>Click to expand manual steps</summary>

See the plugin README's [Setup](plugins/learn-toolkit/README.md#setup) section for the
full walkthrough. In short:

```bash
mkdir -p ~/.claude/skills/learn/references
cp plugins/learn-toolkit/skills/learn/SKILL.md ~/.claude/skills/learn/SKILL.md
cp -r plugins/learn-toolkit/skills/learn/references/* ~/.claude/skills/learn/references/
```

Then configure the `tavily`, `exa`, and `exa-agent` MCP servers in `~/.claude/settings.json` — copy entries from [`plugins/learn-toolkit/.mcp.json`](plugins/learn-toolkit/.mcp.json). Configure sensitive keys through plugin userConfig where possible; never paste keys in chat.

</details>

## Repository layout

```
learn-toolkit/                                  # Repository root — marketplace
├── .claude-plugin/
│   └── marketplace.json                        # Marketplace catalog for /plugin install
├── README.md                                   # This file
├── LICENSE
└── plugins/learn-toolkit/                      # The installable plugin (v2.2.0)
    ├── .claude-plugin/plugin.json               # Plugin manifest
    ├── .mcp.json                                # MCP servers (Tavily, Exa, Exa Agent) with sensitive userConfig headers
    ├── hooks/                                   # Output/artifact validation hooks
    ├── references/setup-guide.md                # AI-assistant install walkthrough
    ├── README.md                                # Full plugin documentation — start here
    └── skills/learn/                            # The one skill: /learn-toolkit:learn
        ├── SKILL.md
        └── references/
            ├── domains/{tech,philosophy,judaism}.md
            ├── notebooklm-loading.md
            ├── artifact-generation.md
            └── candlekeep-integration.md
```

## License

MIT
