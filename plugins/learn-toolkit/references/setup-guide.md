# Setup Instructions for AI Assistants

This repository is a **Claude Code plugin marketplace**. When a user shares this repo
URL, guide them through the plugin install — do NOT manually copy skill files.

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

This installs the single skill and configures MCP servers automatically:
- `/learn-toolkit:learn <subject> [--domain tech|philosophy|judaism] [--language <code>] [--no-notebook]`
  — domain-aware deep research across Tavily, Exa, Sefaria, and CandleKeep, with an
  optional NotebookLM learning package.

### Step 2: Set up API keys

The plugin's `.mcp.json` configures Tavily and Exa servers using environment variable
references (`${TAVILY_API_KEY}`, `${EXA_API_KEY}`). The user needs to set these in their
shell profile. At least one of Tavily or Exa must be configured — that is the only hard
stop in the workflow.

**SECURITY: NEVER ask the user to paste API keys in the chat.**

Detect their shell:
```bash
echo $SHELL
```

Then tell them:

---

The plugin is installed. To enable `/learn-toolkit:learn`'s search backends, add your
API keys to your shell profile.

**Open your shell profile in your editor** (`~/.zshrc` for zsh, `~/.bashrc` for bash) and
add:

```bash
export TAVILY_API_KEY="your-tavily-key-here"    # Get one free at https://tavily.com
export EXA_API_KEY="your-exa-key-here"          # Get one at https://exa.ai
```

Then run `source ~/.zshrc` (or `~/.bashrc`) and restart Claude Code.

**Do not paste your API keys in this chat.** Add them directly to your shell profile.

---

If the user doesn't have API keys for either backend, `/learn-toolkit:learn` will stop
at Phase 0 with setup instructions for both — no other missing tool stops the workflow,
only zero search backends.

### Step 2a: Verify Tavily CLI auth (if the user installs the CLI)

```bash
curl -fsSL https://cli.tavily.com/install.sh | bash
tvly login    # opens browser for OAuth, or: tvly login --api-key tvly-YOUR_KEY
```

The workflow checks CLI authentication with:

```bash
tvly auth
```

**Not** `tvly --status` — its two-part banner drops the auth line when piped through a
filter (e.g. `head`), producing a false negative even when the user is actually logged
in.

### Step 2b: Exa tool set

The bundled `.mcp.json` already enables the canonical tool set on the Exa MCP
connection — nothing for the user to configure:

```
web_search_exa, web_search_advanced_exa, get_code_context_exa, web_fetch_exa,
company_research_exa, people_search_exa, linkedin_search_exa, deep_search_exa
```

The workflow itself calls `web_search_advanced_exa` and `get_code_context_exa` for
research, plus `linkedin_search_exa` for the `tech` domain's community subagent (no
extra credentials needed beyond the Exa key). It never uses any Exa crawling tool or
multi-step deep-research tool — do not suggest those in any config or guidance given to
the user for this plugin.

### Step 3: NotebookLM (optional)

NotebookLM is fully optional. If the user wants podcast/infographic/flashcard
generation:
- Check if they have `notebooklm-mcp` installed.
- If not: "NotebookLM is optional. `/learn-toolkit:learn` will still research your
  topic, save it locally, and offer the CandleKeep write — it just skips the notebook
  package (phases 3-5 as one unit) with a single notice. Add NotebookLM later from
  https://github.com/nicholasgriffintn/notebooklm-mcp, or pass `--no-notebook` any time
  to skip it deliberately."

### Step 3b: CandleKeep (optional)

If the user has `candlekeep-cloud` installed (with the `ck` CLI available),
`/learn-toolkit:learn` will automatically:
- **Scan the library** via the `library` subagent, dispatched as part of Phase 1's
  parallel research fan-out, for existing knowledge on the topic — this runs
  unconditionally on every invocation, on every domain, returning a digest alongside
  every other backend's rather than a standalone report. There is no flag to disable it.
- **Offer, interactively, at the end of the run** (Phase 7) to file the session's
  findings into a per-topic CandleKeep field-research book. This is a question the
  workflow asks, not a flag — decline it and nothing is written.

There is no `--ck-write` or `--no-ck-read` flag in this version. CandleKeep is never
required — the workflow skips both phases silently if `ck` is not installed.

### Step 4: Confirm

Tell the user:

---

Plugin **learn-toolkit** (v2.0.0) installed. Here's what you have:

| Skill | Command | Ready? |
|-------|---------|--------|
| Deep Learning | `/learn-toolkit:learn <subject> [--domain tech\|philosophy\|judaism] [--language <code>] [--no-notebook]` | After setting env vars + restart |
| CandleKeep (optional) | Library scan + field-research offer, no flags needed | If `ck` CLI installed |
| NotebookLM (optional) | Notebook + artifact package, or skip with `--no-notebook` | If `notebooklm-mcp` configured |

**After env vars + restart:**
```
/learn-toolkit:learn Kafka event streaming
/learn-toolkit:learn hilchot shabbat candle lighting --domain judaism
/learn-toolkit:learn the Ship of Theseus and personal identity --domain philosophy
```

**Domain routing:** the subject is matched against `tech`, `philosophy`, and `judaism`
automatically; override with `--domain` if the inference is wrong. Language defaults to
`en` for `tech` and `he` for `philosophy`/`judaism`; override with `--language <code>`.

---

## Important notes for the AI assistant

- **NEVER ask for, display, or log API key values.** Not in chat, not in tool calls, not
  in file contents.
- If a user accidentally pastes a key, tell them to **rotate it immediately** at the
  provider — treat it as compromised the moment it was typed.
- The plugin bundles MCP configs via `.mcp.json` with `${ENV_VAR}` references — no
  manual `settings.json` editing needed. Keys never appear as literal values in any
  config file.
- If the user's Claude Code version doesn't support plugins (< 1.0.33), fall back to
  manual skill installation using the files in `skills/learn/`.
