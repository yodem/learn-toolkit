# learn-toolkit

A Claude Code plugin marketplace with one plugin: **learn-toolkit**, a single skill,
`/learn-toolkit:learn <subject>`, for deep-diving into a technology, a philosophical
concept, or a Jewish text with domain-aware research routing across Tavily, Exa,
Sefaria, and CandleKeep, and an optional NotebookLM learning package.

```
/learn-toolkit:learn <subject> [--domain tech|philosophy|judaism] [--language <code>] [--no-notebook]
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
MCP servers (Tavily, Exa) via environment-variable references — no secrets touch any
config file.

Then add your API keys to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
export TAVILY_API_KEY="your-key-here"   # https://tavily.com (free)
export EXA_API_KEY="your-key-here"      # https://exa.ai
```

Restart Claude Code. `/learn-toolkit:learn` needs at least one of Tavily or Exa to run;
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

Then configure the `tavily` and `exa` MCP servers in `~/.claude/settings.json` — copy the
entries from [`plugins/learn-toolkit/.mcp.json`](plugins/learn-toolkit/.mcp.json)
verbatim, since it already carries the canonical Exa `tools=` list. Add your API keys to
your shell profile as in Option A, then restart Claude Code.

</details>

## Repository layout

```
learn-toolkit/                                  # Repository root — marketplace
├── .claude-plugin/
│   └── marketplace.json                        # Marketplace catalog for /plugin install
├── README.md                                   # This file
├── LICENSE
└── plugins/learn-toolkit/                      # The installable plugin (v2.0.0)
    ├── .claude-plugin/plugin.json               # Plugin manifest
    ├── .mcp.json                                # MCP servers (Tavily, Exa) with ${ENV_VAR} refs
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
