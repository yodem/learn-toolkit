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
- `/learn-toolkit:learn <subject> [--domain tech|philosophy|judaism] [--language <code>] [--no-notebook] [--deep[=high|xhigh]]`
  — domain-aware deep research across Tavily, Exa, Sefaria, and CandleKeep, with an
  optional NotebookLM learning package.

### Step 2: Set up API keys

Install prompts for both optional API keys and stores them in the system keychain. Change them later with `/plugin configure learn-toolkit@learn-toolkit-marketplace`. Exa works keyless; Tavily MCP uses OAuth when its key is blank. At least one search backend must be available.

**SECURITY: NEVER ask the user to paste API keys in the chat.**

Detect their shell:
```bash
echo $SHELL
```

Then tell them:

---

The plugin prompts for optional Exa and Tavily keys during installation and stores them in the system keychain. Leave either blank if you prefer Exa keyless access, Tavily OAuth, or the `tvly` CLI. Change keys later with `/plugin configure learn-toolkit@learn-toolkit-marketplace`. Non-interactive installation with `claude plugin install learn-toolkit@learn-toolkit-marketplace --config exa_api_key=…` is for CI only.

**Do not paste your API keys in this chat.**

---

Exa works keyless; Tavily MCP uses OAuth when its key is blank. The Tavily CLI is an alternative backend.

### Step 2a: Verify Tavily CLI auth (if the user installs the CLI)

```bash
curl -fsSL https://cli.tavily.com/install.sh | bash
tvly init --agent claude-code
```
Use `tvly` 0.1.8 or newer; upgrade with `tvly update`.

The workflow checks CLI authentication with:

```bash
tvly auth
```

**Not** `tvly --status` — its two-part banner drops the auth line when piped through a
filter (e.g. `head`), producing a false negative even when the user is actually logged
in.

### Step 2b: Exa tool set

The Exa MCP connection enables `web_search_exa`, `web_fetch_exa`, and
`web_search_advanced_exa`. A separate Exa Agent connection exposes `agent_run` for
optional `--deep` research and requires an Exa key. Exa search works keyless at a lower rate limit.

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

Plugin **learn-toolkit** (v2.2.0) installed. Here's what you have:

| Skill | Command | Ready? |
|-------|---------|--------|
| Deep Learning | `/learn-toolkit:learn <subject> [--domain tech\|philosophy\|judaism] [--language <code>] [--no-notebook] [--deep[=high|xhigh]] [--deep[=high\|xhigh]]` | After plugin configuration (optional) |
| CandleKeep (optional) | Library scan + field-research offer, no flags needed | If `ck` CLI installed |
| NotebookLM (optional) | Notebook + artifact package, or skip with `--no-notebook` | If `notebooklm-mcp` configured |

**After installation (keys optional):**
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
