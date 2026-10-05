# learn-toolkit

A single Claude Code skill, `/learn-toolkit:learn`, for deep-diving into a subject.
It fans research out across Tavily, Exa, Sefaria, and CandleKeep with domain-aware
routing, synthesizes the findings, saves them locally, and optionally builds a
NotebookLM learning package (podcast, infographic, mind map, flashcards, study guide)
and offers to file the session into a CandleKeep field-research book.

```
/learn-toolkit:learn <subject> [--domain tech|philosophy|judaism] [--language <code>] [--no-notebook] [--deep[=high|xhigh]]
```

## Install

```
/plugin marketplace add yodem/learn-toolkit
/plugin install learn-toolkit@learn-toolkit-marketplace
```

Installation prompts for both optional keys and stores them in the system keychain. Exa search works keyless; Tavily MCP uses OAuth when its key is blank. Change keys with `/plugin configure learn-toolkit@learn-toolkit-marketplace`. Non-interactive `claude plugin install learn-toolkit@learn-toolkit-marketplace --config exa_api_key=…` is for CI only.

For Tavily CLI fallback: `curl -fsSL https://cli.tavily.com/install.sh | bash && tvly init --agent claude-code`. Requires `tvly` >= 0.1.8; update with `tvly update`. Never paste keys in chat.

The workflow needs **at least one** of Tavily or Exa to run at all; everything else
(Sefaria, CandleKeep, NotebookLM) is optional and degrades gracefully when absent. See
[Backends](#backends) below.

## How it routes

`/learn-toolkit:learn` resolves exactly one of three domains before doing any research:

| Domain | What it's for | Default language | Learning page ladder (Phase 6b): basics → advanced → research |
|--------|----------------|-------------------|-------------------------------------|
| `tech` | Software, infrastructure, tooling, frameworks, protocols, AI/ML engineering — anything better answered from docs, source code, or practitioner discussion | `en` | concepts and a minimal example → patterns and pitfalls → docs, repos, discussion |
| `philosophy` | Philosophical concepts, arguments, thinkers, traditions — answered from argument and secondary literature, no primary Jewish text at the center | `he` | the question and its terms → positions and objections → literature |
| `judaism` | Torah, Talmud, halakha, midrash, Jewish thought — whenever a primary Jewish text is the thing being studied, even under a philosophical framing | `he` | the text and its plain meaning → commentators and halakha → scholarship |

**Domain resolution:** if `--domain` is passed, it always wins. Otherwise the subject is
matched against each domain's identity description; if genuinely ambiguous, it defaults
to `tech` and says so — correct it with `--domain` on the next run.

**Language resolution:** `--language <code>` if passed, else the resolved domain's
default from the table above. Every phase uses this resolved value — nothing is
hardcoded.

Each domain has its own subagent roster, source ranking, and query patterns (see
`skills/learn/references/domains/{tech,philosophy,judaism}.md`) — the workflow reads the
resolved domain's file in full before dispatching any research.

## What a run does

1. **Phase 0 — Discover tools.** Checks Tavily (CLI and MCP), Exa MCP, Sefaria MCP,
   CandleKeep CLI, and NotebookLM MCP. Reports a matrix of what's available.
2. **Phase 0.5 — Resolve domain and language,** read the domain file, announce the
   routing before spending any research call.
3. **Phase 1 — Parallel research fan-out.** One subagent per roster entry in the
   resolved domain, dispatched in a single message — including a `library` subagent that
   scans CandleKeep (see [CandleKeep](#candlekeep) below) unconditionally on every
   domain. Each subagent returns digests (URL/id, title, kind, why it matters, key
   claims) — never raw page dumps.
4. **Phase 2 — Merge and synthesize.** Dedupe, rank by the domain's source hierarchy,
   write a ~500-word synthesis in three sections, basics first: **Basics** (terms
   defined, a mental model, a minimal example — no numbers or tables), **Advanced
   usage**, **Related research**.
5. **Phase 2.5 — Save local files.** Always runs, regardless of what backends were
   available. Output goes to `$HOME/dev/learn-research/learn-<topic-slug>/` —
   **`/tmp` is never used** for this durable output.
6. **Phase 3-5 — NotebookLM package (optional).** Loads sources into a notebook, then
   generates podcast, infographic, mind map, flashcards, and a domain-adapted study
   guide in parallel, and polls until each artifact completes. See
   [NotebookLM is optional](#notebooklm-is-optional) below.
7. **Phase 6 — Companion visuals.** An ASCII diagram of the basics in the terminal
   (concept map, flowchart or architecture sketch), then a **learning page** for every
   domain: one HTML page in the same basics → advanced usage → related research order,
   saved as `learning-page.html` in the research folder and published as a Claude Code
   Artifact. Without the Artifact tool the local file is kept and its path reported.
8. **Phase 7 — CandleKeep field-research offer (optional).** If CandleKeep is
   available, interactively asks whether to file today's findings into a per-topic
   field-research book. See [CandleKeep](#backends) below.

## Backends

| Backend | Required? | What it's for | If missing |
|---------|-----------|----------------|------------|
| Tavily | One of Tavily/Exa required | General web search, official docs, community discussion | If Exa is also missing, the workflow **stops** before Phase 0.5 with setup instructions — the only hard stop in the whole workflow |
| Exa | One of Tavily/Exa required | `web_search_exa`, `web_fetch_exa`, and targeted `web_search_advanced_exa` | Same as above |
| Exa Agent | Optional; key required | Opt-in `agent_run` research with `--deep` | Use Tavily research or skip deep results |
| Sefaria | Optional, `judaism` only | Primary-text search and commentary chains — the authoritative source for that domain | The `secondary` (Tavily/Exa) subagent carries more weight; noted in the domain announcement |
| CandleKeep | Optional | Unconditional library scan via the `library` subagent (Phase 1) on every domain; interactive field-research offer (Phase 7) | Both phases skip silently — no error, no interruption |
| NotebookLM | Optional | Podcast, infographic, mind map, flashcards, study guide | Phases 3-5 skip **as one unit** with a single notice — research, local files, and the CandleKeep offer are unaffected |

### NotebookLM is optional

NotebookLM is not required to get value from `/learn-toolkit:learn`. If it isn't
configured, or you pass `--no-notebook`, phases 3, 4, and 5 skip together and the
workflow prints exactly one notice:

> NotebookLM not available — skipping the notebook package. Research, local files and
> the CandleKeep offer are unaffected.

The notebook/artifact tables are simply omitted from the final report; the workflow
never stops because of this. The **only** hard stop in the entire workflow is having
zero available search backends (both Tavily and Exa missing).

### Exa tools

| Tool | Use |
|------|-----|
| `web_search_exa` | Quick broad searches and code examples |
| `web_fetch_exa` | Fetch selected source pages with a character limit |
| `web_search_advanced_exa` | Targeted search with categories, domain filters, date windows, and highlights |
| `agent_run` | Optional deep research, only when `--deep` is passed; requires an Exa key |

The former specialized Exa search tools and retired categories are no longer supported by this plugin. Search works keyless; Agent requires an Exa key.

### Deep research (`--deep`)

`--deep` opts into Exa Agent with medium effort by default. Set `--deep=high` or `--deep=xhigh` to choose a higher effort. Approximate prices per run are low $0.025, medium $0.10, high $0.50, and xhigh $1.00 ([Exa Agent quickstart](https://exa.ai/docs/agent/quickstart)). When the Exa key is blank, the workflow uses Tavily research if the CLI is available; otherwise it reports that a key is needed and continues.

### CandleKeep

If the `ck` CLI is on your `PATH` (install via the `candlekeep-cloud` plugin),
`/learn-toolkit:learn` will:

- **Scan the library** via the `library` subagent, one of the parallel subagents
  dispatched in Phase 1's fan-out, for existing documents on the topic before
  synthesizing — this runs unconditionally on every invocation when CandleKeep is
  available, on every domain, and returns a digest like every other backend rather than
  a standalone report. There is no flag to disable it.
- **Offer to file findings** (Phase 7) into a per-topic field-research book, at the end
  of the run — this is an interactive question, not a flag. Decline it and nothing is
  written.

There is no `--ck-write` or `--no-ck-read` flag in this version — both behaviors above
replaced the old flag-gated design outright.

## Setup

### Tavily

**Option A — CLI (recommended):**
```bash
curl -fsSL https://cli.tavily.com/install.sh | bash
tvly login                                 # opens browser for OAuth
# or: tvly login --api-key tvly-YOUR_KEY
```
The workflow checks CLI auth with `tvly auth` (not `tvly --status`, whose two-part
banner drops the auth line when piped). Use `tvly` >= 0.1.8; update with `tvly update`.

**Option B — MCP server:** enter the key through `/plugin configure learn-toolkit@learn-toolkit-marketplace`, or sign in from `/mcp`. Blank config uses OAuth.

### Exa

Exa search works keyless. To increase its rate limit and enable `--deep`, set the key with `/plugin configure learn-toolkit@learn-toolkit-marketplace` and reload plugins or restart Claude Code.

### Sefaria (optional, `judaism` only)

Configured separately as an MCP server; only matters when the resolved domain is
`judaism`. If unavailable, the `secondary` subagent (Tavily/Exa) carries more weight —
Sefaria is never substituted with open-web search for the primary text.

### Deep research (`--deep`)

`--deep` opts into Exa Agent with medium effort by default. Set `--deep=high` or `--deep=xhigh` to choose a higher effort. Approximate prices per run are low $0.025, medium $0.10, high $0.50, and xhigh $1.00 ([Exa Agent quickstart](https://exa.ai/docs/agent/quickstart)). When the Exa key is blank, the workflow uses Tavily research if the CLI is available; otherwise it reports that a key is needed and continues.

### CandleKeep (optional)

Install the `candlekeep-cloud` plugin so the `ck` CLI is on your `PATH`. Detected
automatically — no configuration in this plugin.

### NotebookLM (optional)

Install [notebooklm-mcp](https://github.com/nicholasgriffintn/notebooklm-mcp), then:

```bash
nlm login
```

## API key safety

- **Never ask for, display, or log an API key value** — not in chat, not in tool calls,
  not in file contents.
- If you accidentally paste a key into the chat, **rotate it immediately** at the
  provider (Tavily, Exa, etc.) — treat it as compromised the moment it's been typed.
- Keys live only in sensitive plugin `userConfig`, stored in the system keychain and
  passed as MCP headers. Change them with `/plugin configure learn-toolkit@learn-toolkit-marketplace`.

## Examples

```bash
# tech — inferred domain, English output, full package
/learn-toolkit:learn Next.js App Router

# judaism — explicit domain, Hebrew output (default), no NotebookLM configured
/learn-toolkit:learn hilchot shabbat candle lighting --domain judaism

# philosophy — inferred domain, degraded search (only Exa available)
/learn-toolkit:learn the Ship of Theseus and personal identity

# skip the NotebookLM package explicitly
/learn-toolkit:learn Rust ownership and borrowing --no-notebook

# override the inferred/default language
/learn-toolkit:learn Kafka event streaming --language en
```

## Output

Research is always saved locally, regardless of which optional backends are available:

```
$HOME/dev/learn-research/learn-<topic-slug>/
  README.md              — index with TOC, metadata, domain, date
  research-summary.md    — ~500-word synthesis
  sources/
    01-primary.md        — official docs, or Sefaria text, per domain
    02-library.md        — CandleKeep sources
    03-community.md      — discussion and practitioner sources
    04-articles.md
```

When NotebookLM is available, the run also reports a notebook table and an artifact
status table (podcast, infographic, mind map, flashcards, study guide). NotebookLM
notebooks cap at 100 sources; the workflow overflows to a new notebook before the cap is
hit.

## File Structure

```
learn-toolkit/                                 # Plugin root (plugins/learn-toolkit/)
├── .claude-plugin/
│   └── plugin.json                            # Plugin manifest (name, version 2.2.0)
├── .mcp.json                                   # MCP servers (Tavily, Exa) with ${ENV_VAR} refs
├── hooks/
│   ├── hooks.json
│   ├── validate-output.sh
│   └── verify-artifacts.sh
├── references/
│   └── setup-guide.md                          # AI-assistant install walkthrough
├── README.md                                   # This file
├── LICENSE
└── skills/
    └── learn/
        ├── SKILL.md                            # The one command: phases, flags, routing
        └── references/
            ├── domains/
            │   ├── tech.md
            │   ├── philosophy.md
            │   └── judaism.md
            ├── notebooklm-loading.md           # Notebook overflow logic
            ├── artifact-generation.md          # NotebookLM tool signatures
            └── candlekeep-integration.md       # CandleKeep read/write reference
```

## Development

Run `bash scripts/lint-skill.sh` from the plugin root before committing any change to
`skills/learn/SKILL.md` or its references — it derives everything from the files at
runtime, so it stays meaningful as the skill evolves. It checks:

1. **Undefined variables** — every `$VAR` used in `SKILL.md` is assigned or derived
   somewhere in the file, aside from a small whitelist of real environment variables.
2. **Body commands vs. `allowed-tools`** — every shell command the skill body instructs
   the agent to run is actually covered by the frontmatter's `allowed-tools`.
3. **Count-vs-enumeration drift** — a stated count ("the five keys") matches the size of
   the list, JSON object, or comma list right next to it.
4. **Cross-file Exa tool-name agreement** — every `*_exa` tool named in prose across the
   skill, its domain references, and the READMEs is actually enabled in `.mcp.json`.
5. **Deprecated tool names** — `crawling_exa`, `deep_researcher_start`, and
   `deep_researcher_check` appear nowhere except on a line that also says why not to use
   them.
6. **Referenced files exist** — every `references/*.md` path `SKILL.md` points to is
   actually present on disk.
7. **Phase numbering** — `### Phase N` headings in `SKILL.md` are non-decreasing, with no
   duplicates or out-of-order phases.

Exits 0 on a clean run, 1 with a `FAIL: <check> — <detail>` line per finding otherwise.

## License

MIT
