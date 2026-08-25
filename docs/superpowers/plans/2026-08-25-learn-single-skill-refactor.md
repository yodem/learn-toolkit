# learn-toolkit Single-Skill Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse the three-skill `learn-toolkit` plugin into one `/learn <subject>` skill that routes research strategy and tool selection by inferred domain (tech / philosophy / judaism).

**Architecture:** A domain-agnostic workflow spine lives in `skills/learn/SKILL.md`; per-domain specifics live in `skills/learn/references/domains/<domain>.md` and only the active domain's file is read. Phase 1 fans out one subagent per search backend, each returning a structured digest rather than raw pages. NotebookLM becomes fully optional; the run ends by offering to append findings to a per-topic CandleKeep field-research book.

**Tech Stack:** Claude Code plugin (markdown skills + JSON manifests + bash hooks). No application runtime. Verification is `claude plugin validate --strict`, `shellcheck`, `jq`, and `grep` assertions.

**Spec:** `docs/superpowers/specs/2026-08-25-learn-toolkit-single-skill-refactor-design.md` — read it before starting any task.

## Global Constraints

- **Repo layout:** the repo root is the *marketplace*; the plugin lives at `plugins/learn-toolkit/`. Every path below is relative to the repo root `~/dev/learn-toolkit`. The spec's §11 omits the `plugins/learn-toolkit/` prefix — this plan's paths are authoritative.
- **Target version: `2.0.0`** (breaking: two skills removed). `plugin.json` and the `marketplace.json` entry must both say `2.0.0`.
- **Canonical research output path:** `$HOME/dev/learn-research/learn-<topic-slug>/`. `/tmp` is never used for research output.
- **Workflow state file:** `/tmp/learn-workflow-state-<topic-slug>.json` — topic-scoped, never the shared `/tmp/learn-workflow-state.json`.
- **Domains:** exactly `tech`, `philosophy`, `judaism`.
- **Default languages:** `tech` → `en`; `philosophy` → `he`; `judaism` → `he`. `--language <code>` overrides.
- **Exa `tools=` list** (canonical, verified 2026-08-25):
  `web_search_exa,web_search_advanced_exa,get_code_context_exa,web_fetch_exa,company_research_exa,people_search_exa,linkedin_search_exa,deep_search_exa`
- **Never** reference `crawling_exa`, `deep_researcher_start`, or `deep_researcher_check` — removed/deprecated.
- **Never** write to `~/dev/sefaria/sefaria-wiki` or link to it.
- **Do not commit.** Subagents edit and verify only; the orchestrator commits per wave. This avoids `git index.lock` races between parallel agents.
- **Do not push.** Pushing requires the user's explicit go-ahead.

## Execution waves

File sets are disjoint, so these run concurrently without worktrees.

| Wave | Tasks | Rationale |
|---|---|---|
| **A** | 1, 2, 3, 5, 6 | Fully independent file sets |
| **B** | 4 | `SKILL.md` consumes interfaces produced by 3, 5, 6 |
| **C** | 7 | Docs describe the final state of everything above |

---

### Task 1: Manifests and MCP config

**Files:**
- Modify: `plugins/learn-toolkit/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `plugins/learn-toolkit/.mcp.json`
- Delete: `plugins/learn-toolkit/CLAUDE.md`

**Interfaces:**
- Consumes: nothing.
- Produces: plugin version `2.0.0`; a `.mcp.json` whose `exa` server URL carries the canonical tools list.

**Background the implementer needs:** `claude plugin validate --strict` reported that `mcp` and `requiredEnvVars` are **unknown fields that Claude Code ignores at load time**. The `mcp` field additionally points to `../.mcp.json`, which resolves *outside* the plugin directory and does not exist — the real file is `plugins/learn-toolkit/.mcp.json`, discovered by convention, not by that field. Both fields are removed. Separately, a plugin-root `CLAUDE.md` is **not loaded as context** — that file is dead weight and is deleted; its useful content moves to the README in Task 7.

- [ ] **Step 1: Run the validators to see the current failures**

```bash
cd ~/dev/learn-toolkit
claude plugin validate plugins/learn-toolkit --strict
claude plugin validate . --strict
```

Expected: both FAIL. Plugin reports unknown fields `mcp` and `requiredEnvVars` plus the CLAUDE.md warning. Marketplace reports the missing description and `Entry declares version "1.5.1" but ... plugin.json says "1.5.2"`.

- [ ] **Step 2: Rewrite `plugins/learn-toolkit/.claude-plugin/plugin.json`**

```json
{
  "name": "learn-toolkit",
  "version": "2.0.0",
  "description": "One skill, /learn <subject>, that researches a topic with domain-aware tool routing (tech, philosophy, judaism), fans research out across Tavily, Exa, Sefaria and CandleKeep, and optionally builds a NotebookLM learning package.",
  "author": {
    "name": "Yotam Fromm",
    "url": "https://github.com/yodem"
  },
  "homepage": "https://github.com/yodem/learn-toolkit",
  "repository": "https://github.com/yodem/learn-toolkit",
  "license": "MIT",
  "keywords": ["learning", "research", "notebooklm", "tavily", "exa", "candlekeep", "sefaria"],
  "skills": "./skills/"
}
```

- [ ] **Step 3: Rewrite `.claude-plugin/marketplace.json`**

```json
{
  "name": "learn-toolkit-marketplace",
  "owner": {
    "name": "Yotam Fromm",
    "email": "yodem@users.noreply.github.com"
  },
  "metadata": {
    "description": "Yotam's personal learning-workflow plugin: domain-aware deep research into an optional NotebookLM package and a CandleKeep field-research book."
  },
  "plugins": [
    {
      "name": "learn-toolkit",
      "version": "2.0.0",
      "description": "One skill, /learn <subject>, with domain-aware research routing across Tavily, Exa, Sefaria and CandleKeep.",
      "source": "./plugins/learn-toolkit"
    }
  ]
}
```

- [ ] **Step 4: Rewrite `plugins/learn-toolkit/.mcp.json`**

```json
{
  "mcpServers": {
    "tavily": {
      "type": "url",
      "url": "https://mcp.tavily.com/mcp/?tavilyApiKey=${TAVILY_API_KEY}"
    },
    "exa": {
      "type": "url",
      "url": "https://mcp.exa.ai/mcp?exaApiKey=${EXA_API_KEY}&tools=web_search_exa,web_search_advanced_exa,get_code_context_exa,web_fetch_exa,company_research_exa,people_search_exa,linkedin_search_exa,deep_search_exa"
    }
  }
}
```

Note: keys stay as `${ENV_VAR}` references. Never inline a key value.

- [ ] **Step 5: Delete the unloaded plugin CLAUDE.md**

```bash
rm plugins/learn-toolkit/CLAUDE.md
```

- [ ] **Step 6: Verify all gates pass**

```bash
cd ~/dev/learn-toolkit
claude plugin validate plugins/learn-toolkit --strict && echo "PLUGIN OK"
claude plugin validate . --strict && echo "MARKETPLACE OK"
jq -e '.mcpServers.exa.url | contains("linkedin_search_exa") and contains("deep_search_exa") and contains("web_fetch_exa")' plugins/learn-toolkit/.mcp.json
jq -e '.mcpServers.exa.url | (contains("crawling_exa") or contains("deep_researcher")) | not' plugins/learn-toolkit/.mcp.json
test "$(jq -r .version plugins/learn-toolkit/.claude-plugin/plugin.json)" = "$(jq -r .plugins[0].version .claude-plugin/marketplace.json)" && echo "VERSIONS MATCH"
```

Expected: `PLUGIN OK`, `MARKETPLACE OK`, two `true`, `VERSIONS MATCH`.

---

### Task 2: Remove two skills, repair the hooks

**Files:**
- Delete: `plugins/learn-toolkit/skills/visualize/SKILL.md` (and its directory)
- Delete: `plugins/learn-toolkit/skills/playground/SKILL.md` (and its directory)
- Modify: `plugins/learn-toolkit/hooks/validate-output.sh`
- Modify: `plugins/learn-toolkit/hooks/verify-artifacts.sh`

**Interfaces:**
- Consumes: the Global Constraints' canonical output path and state-file naming.
- Produces: hooks that validate `$HOME/dev/learn-research/learn-*` and topic-scoped state files.

**Background:** deleting the two skills is safe. The ASCII diagram is rendered inline by the `learn` skill itself, and the playground step delegates to `playground:playground`, which is a **separate installed plugin**, not this local skill. Three standing bugs are fixed here: the hook path filter still matches `/tmp/learn-*` (open since 2026-05-26) though output moved to `$HOME/dev/learn-research/`; the state-file path is hardcoded and unscoped; and the research-summary length gate trips at 500 chars while its own comment expects ~3000.

- [ ] **Step 1: Write the failing assertions**

```bash
cd ~/dev/learn-toolkit
# Each of these should currently FAIL (print nothing / non-zero)
grep -q 'dev/learn-research' plugins/learn-toolkit/hooks/validate-output.sh && echo "PATH OK" || echo "PATH BUG (expected)"
grep -q 'learn-workflow-state-' plugins/learn-toolkit/hooks/verify-artifacts.sh && echo "STATE OK" || echo "STATE BUG (expected)"
test -d plugins/learn-toolkit/skills/visualize && echo "visualize still present (expected)"
```

Expected: `PATH BUG (expected)`, `STATE BUG (expected)`, `visualize still present (expected)`.

- [ ] **Step 2: Delete the two skill directories**

```bash
cd ~/dev/learn-toolkit
git rm -r --quiet plugins/learn-toolkit/skills/visualize plugins/learn-toolkit/skills/playground
```

- [ ] **Step 3: Replace `plugins/learn-toolkit/hooks/validate-output.sh`**

```bash
#!/usr/bin/env bash
# validate-output.sh
# PostToolUse hook: validates files written by learn-toolkit have correct structure.
# Reads tool use JSON from stdin. Exit 0 to allow, exit 2 to block with message.

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || true)

RESEARCH_ROOT="$HOME/dev/learn-research"

# Only validate learn-toolkit outputs: research files, or a topic-scoped state file.
case "$FILE_PATH" in
  "$RESEARCH_ROOT"/learn-*) ;;
  /tmp/learn-workflow-state-*.json) ;;
  *) exit 0 ;;
esac

# Validate README.md has a top-level heading
if [[ "$FILE_PATH" == */README.md ]]; then
  if ! grep -q "^#" "$FILE_PATH" 2>/dev/null; then
    echo "ERROR: $FILE_PATH is missing a top-level heading" >&2
    exit 2
  fi
fi

# Validate research-summary.md length. A 500-word synthesis is ~3000 chars;
# warn below 2500 rather than the old 500, which passed near-empty files.
if [[ "$FILE_PATH" == */research-summary.md ]]; then
  CHAR_COUNT=$(wc -c < "$FILE_PATH" 2>/dev/null || echo 0)
  if [[ "$CHAR_COUNT" -lt 2500 ]]; then
    echo "WARNING: $FILE_PATH looks too short (${CHAR_COUNT} chars) — expected ~3000 for a 500-word summary" >&2
  fi
fi

# Validate topic-scoped workflow state JSON
if [[ "$FILE_PATH" == /tmp/learn-workflow-state-*.json ]]; then
  if ! jq empty "$FILE_PATH" 2>/dev/null; then
    echo "ERROR: $FILE_PATH is not valid JSON" >&2
    exit 2
  fi
  for KEY in topic domain notebooks total_sources local_path; do
    if ! jq -e "has(\"$KEY\")" "$FILE_PATH" >/dev/null 2>&1; then
      echo "ERROR: $FILE_PATH is missing required key: $KEY" >&2
      exit 2
    fi
  done
fi

exit 0
```

- [ ] **Step 4: Replace `plugins/learn-toolkit/hooks/verify-artifacts.sh`**

Note the SC2034 fix: the old file read stdin into `INPUT` and never used it. Here stdin is drained to `/dev/null`, because a hook that does not consume stdin can make the caller block on a full pipe.

```bash
#!/usr/bin/env bash
# verify-artifacts.sh
# Stop hook: checks that expected learn-toolkit artifacts were generated this session.
# Reads session JSON from stdin. Exit 0 to allow stop, exit 2 to block with message.

set -euo pipefail

# Drain stdin; the payload is not needed, but leaving it unread can block the caller.
cat >/dev/null

shopt -s nullglob
STATE_FILES=(/tmp/learn-workflow-state-*.json)

# No state file: the learn workflow did not run this session.
if [[ ${#STATE_FILES[@]} -eq 0 ]]; then
  exit 0
fi

for STATE_FILE in "${STATE_FILES[@]}"; do
  TOPIC=$(jq -r '.topic // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")
  LOCAL_PATH=$(jq -r '.local_path // ""' "$STATE_FILE" 2>/dev/null || echo "")
  TOTAL_SOURCES=$(jq -r '.total_sources // 0' "$STATE_FILE" 2>/dev/null || echo "0")

  if [[ -n "$LOCAL_PATH" && ! -d "$LOCAL_PATH" ]]; then
    echo "WARNING: learn-toolkit ran for topic '$TOPIC' but local path '$LOCAL_PATH' was not created." >&2
  fi

  if [[ -n "$LOCAL_PATH" && ! -f "${LOCAL_PATH}/research-summary.md" ]]; then
    echo "WARNING: learn-toolkit ran for topic '$TOPIC' but research-summary.md was not generated." >&2
  fi

  if [[ "$TOTAL_SOURCES" -eq 0 ]]; then
    echo "WARNING: learn-toolkit state shows 0 sources for topic '$TOPIC'. The workflow may have failed silently." >&2
  fi
done

exit 0
```

- [ ] **Step 5: Verify the assertions now pass**

```bash
cd ~/dev/learn-toolkit
shellcheck plugins/learn-toolkit/hooks/*.sh && echo "SHELLCHECK CLEAN"
bash -n plugins/learn-toolkit/hooks/validate-output.sh && bash -n plugins/learn-toolkit/hooks/verify-artifacts.sh && echo "SYNTAX OK"
grep -q 'dev/learn-research' plugins/learn-toolkit/hooks/validate-output.sh && echo "PATH FIXED"
grep -q 'learn-workflow-state-' plugins/learn-toolkit/hooks/verify-artifacts.sh && echo "STATE FIXED"
! grep -rq '/tmp/learn-[a-z]' plugins/learn-toolkit/hooks/ && echo "NO STALE TMP PATHS"
test ! -d plugins/learn-toolkit/skills/visualize && test ! -d plugins/learn-toolkit/skills/playground && echo "SKILLS REMOVED"
ls plugins/learn-toolkit/skills/
```

Expected: `SHELLCHECK CLEAN`, `SYNTAX OK`, `PATH FIXED`, `STATE FIXED`, `NO STALE TMP PATHS`, `SKILLS REMOVED`, and `ls` printing only `learn`.

- [ ] **Step 6: Functional test of the state-file validator**

```bash
cd /tmp
printf '{"topic":"x","domain":"tech","notebooks":[],"total_sources":0,"local_path":"/tmp/nope"}' > /tmp/learn-workflow-state-x.json
echo '{"tool_input":{"file_path":"/tmp/learn-workflow-state-x.json"}}' \
  | bash ~/dev/learn-toolkit/plugins/learn-toolkit/hooks/validate-output.sh && echo "ACCEPTS VALID STATE"
printf '{"topic":"x"}' > /tmp/learn-workflow-state-x.json
echo '{"tool_input":{"file_path":"/tmp/learn-workflow-state-x.json"}}' \
  | bash ~/dev/learn-toolkit/plugins/learn-toolkit/hooks/validate-output.sh; echo "exit=$? (expect 2)"
rm -f /tmp/learn-workflow-state-x.json
```

Expected: `ACCEPTS VALID STATE`, then `exit=2` with a missing-key error.

---

### Task 3: Domain reference files

**Files:**
- Create: `plugins/learn-toolkit/skills/learn/references/domains/tech.md`
- Create: `plugins/learn-toolkit/skills/learn/references/domains/philosophy.md`
- Create: `plugins/learn-toolkit/skills/learn/references/domains/judaism.md`

**Interfaces:**
- Consumes: the Global Constraints' domain list and language defaults.
- Produces: three files, each with **exactly** these five `##` headings, in this order — `## Identity`, `## Subagent Roster`, `## Source Ranking`, `## Query Patterns`, `## Output Settings`. `SKILL.md` (Task 4) reads the active domain's file and relies on these headings existing.

**Rule:** a domain file contains **only** what differs from the spine. It never restates workflow phases. If a statement would be true for all three domains, it belongs in `SKILL.md`, not here.

- [ ] **Step 1: Create `tech.md`**

```markdown
# Domain: tech

## Identity

Software, infrastructure, tooling, languages, frameworks, protocols, AI/ML engineering.
Prefer this domain when the answer lives in documentation, source code, or practitioner
discussion rather than in a text tradition.

## Subagent Roster

Four subagents, dispatched in one message:

1. **docs** — Tavily, official documentation and specifications.
2. **code** — Exa `get_code_context_exa`, plus `web_search_advanced_exa` with `category: "github"`.
3. **community** — Tavily with `include_domains: ["reddit.com","news.ycombinator.com","stackoverflow.com"]`,
   plus Exa `web_search_advanced_exa` with `category: "personal site"`, plus `linkedin_search_exa`
   for practitioners writing about the subject.
4. **library** — CandleKeep (see `../candlekeep-integration.md`).

## Source Ranking

official docs > source code / repos > library (CandleKeep) > practitioner discussion > tutorials > blog posts

## Query Patterns

Tavily — one focused query per subagent, recency via parameter, never via query text:

```bash
tvly search "<subject> official documentation" --depth advanced --max-results 6 --json
tvly search "<subject> production issues" --time-range year --include-domains reddit.com,news.ycombinator.com --max-results 6 --json
```

Exa — describe the ideal page, never keywords:

- GOOD: `"in-depth blog post explaining how <subject> works in production, with tradeoffs"`
- BAD: `"<subject> production tradeoffs"`
- GOOD: `"official reference documentation for <subject> configuration options"`
- BAD: `"<subject> documentation"`

## Output Settings

- Language: `en`
- Playground (Phase 6b): **yes**
- NotebookLM artifact focus: implementation-oriented — code examples, pitfalls, action items.
```

- [ ] **Step 2: Create `philosophy.md`**

```markdown
# Domain: philosophy

## Identity

Philosophical concepts, arguments, thinkers, and traditions — analytic or continental,
ancient or modern. Prefer this domain when the answer lives in argument and secondary
literature rather than in documentation or in a religious text tradition.

## Subagent Roster

Three subagents, dispatched in one message:

1. **literature** — Exa `web_search_advanced_exa` with `category: "publication"` for papers,
   plus `category: "personal site"` for essays. Exa's personal-site index is its documented
   strength; use it rather than domain-filtered Tavily here.
2. **overview** — Tavily general search for encyclopedic and orienting material
   (SEP, IEP, university course pages).
3. **library** — CandleKeep, prioritising per-author humanities books
   (see `../candlekeep-integration.md`).

## Source Ranking

primary texts > peer-reviewed literature > library (CandleKeep) > encyclopedic overviews (SEP/IEP) > essays > blog posts

## Query Patterns

Exa — describe the ideal page:

- GOOD: `"scholarly article analysing <thinker>'s argument about <concept> and its critics"`
- BAD: `"<thinker> <concept> criticism"`
- GOOD: `"clear introductory essay explaining the <concept> debate for a graduate reader"`
- BAD: `"<concept> introduction"`

Tavily:

```bash
tvly search "<subject> Stanford Encyclopedia of Philosophy overview" --depth advanced --max-results 6 --json
```

## Output Settings

- Language: `he`
- Playground (Phase 6b): **no** — a parameter-toggle explorer does not fit argumentative material.
- NotebookLM artifact focus: argument structure — positions, objections, replies.
```

- [ ] **Step 3: Create `judaism.md`**

```markdown
# Domain: judaism

## Identity

Torah, Talmud, halakha, midrash, Jewish thought and its commentators. Prefer this domain
when a primary Jewish text is the thing being studied, even when the framing is
philosophical.

## Subagent Roster

Three subagents, dispatched in one message:

1. **primary** — Sefaria MCP. This is the authoritative source for this domain and always
   runs first: `mcp__claude_ai_Sefaria__text_search`,
   `mcp__claude_ai_Sefaria__english_semantic_search`,
   `mcp__claude_ai_Sefaria__get_topic_details`,
   `mcp__claude_ai_Sefaria__get_links_between_texts` for commentary chains.
2. **library** — CandleKeep Judaica books (see `../candlekeep-integration.md`).
3. **secondary** — Tavily and Exa, **secondary only**: scholarship and shiurim that
   contextualise the primary text. Never used in place of Sefaria.

## Source Ranking

primary text (Sefaria) > classical commentators > library (CandleKeep) > academic scholarship > shiurim and popular writing

## Query Patterns

Sefaria first. Resolve the topic to a citation before searching the open web, so that
secondary sources are evaluated against the text rather than substituting for it.

Exa — describe the ideal page:

- GOOD: `"academic article on the reception history of <text> among medieval commentators"`
- BAD: `"<text> commentary history"`

## Wiki Boundary — MANDATORY

Using Sefaria MCP *text* tools for personal study is expected and fine. The separation rule
governs **where notes are filed**, not which tools are called.

- Findings go to `$HOME/dev/learn-research/` and, on acceptance, to CandleKeep.
- **Never** write to `~/dev/sefaria/sefaria-wiki`.
- **Never** emit a wikilink pointing into the Sefaria wiki.

## Output Settings

- Language: `he`
- Playground (Phase 6b): **no**
- NotebookLM artifact focus: text-and-commentary — sugya structure, positions of the
  commentators, practical halakhic upshot where relevant.
```

- [ ] **Step 4: Verify structure**

```bash
cd ~/dev/learn-toolkit/plugins/learn-toolkit/skills/learn/references/domains
for f in tech philosophy judaism; do
  echo "--- $f ---"
  for h in Identity "Subagent Roster" "Source Ranking" "Query Patterns" "Output Settings"; do
    grep -q "^## $h\$" "$f.md" && echo "  OK   $h" || echo "  MISS $h"
  done
done
grep -rn 'crawling_exa\|deep_researcher' . && echo "STALE TOOL REFS FOUND" || echo "NO STALE TOOL REFS"
grep -rn 'sefaria-wiki' judaism.md | grep -qv Never && echo "CHECK BOUNDARY WORDING" || echo "BOUNDARY OK"
```

Expected: every heading `OK` for all three files, `NO STALE TOOL REFS`, `BOUNDARY OK`.

---

### Task 4: Rewrite `SKILL.md` — WAVE B, run after Wave A

**Files:**
- Modify (full rewrite): `plugins/learn-toolkit/skills/learn/SKILL.md`

**Interfaces:**
- Consumes: the five `##` headings from Task 3's domain files; the field-research procedure from Task 5's `candlekeep-integration.md`; the optional-mode notes from Task 6.
- Produces: the single `learn-toolkit:learn` skill, the only skill in the plugin.

**Required frontmatter — copy exactly:**

```yaml
---
name: learn-toolkit:learn
description: "Domain-aware deep learning workflow. Researches a subject across Tavily, Exa, Sefaria and CandleKeep with one subagent per backend, then optionally builds a NotebookLM package and files findings into a CandleKeep field-research book. Routes by domain: tech, philosophy, judaism. Do NOT use for quick factual lookups or for a single URL — use a direct web search instead."
argument-hint: "<subject> [--domain tech|philosophy|judaism] [--language <code>] [--no-notebook]"
allowed-tools: Task, Write, Read, Bash(tvly *), Bash(ck *), Bash(echo *), Bash(mkdir *), Bash(test *), Bash(cat *), Bash(cp *)
metadata:
  author: Yotam Fromm
  version: 2.0.0
  mcp-server: tavily, exa, notebooklm-mcp
  category: learning
  tags: [research, domains, tavily, exa, sefaria, candlekeep, notebooklm]
---
```

`Task` is newly required — Phase 1 dispatches subagents. Without it the fan-out cannot run.

**Required structure.** Write these sections, in order:

1. `## Important` — state the three domains, that domain is inferred with `--domain` overriding, that language defaults are per-domain (`tech` → `en`, others → `he`), and the 50-source NotebookLM cap.
2. `### Phase 0: Discover Available Tools` — probe Tavily CLI (`tvly --version` for presence, **`tvly auth` for authentication — NOT `tvly --status`**, whose two-part banner loses the auth line when piped through `head`), Tavily MCP, Exa, Sefaria MCP, CandleKeep (`ck --version`), NotebookLM. Report a one-line matrix. **The only hard stop in the whole workflow is zero search backends.** Everything else degrades with a notice.
3. `### Phase 0.5: Resolve Domain` — infer from the subject unless `--domain` is given; read `references/domains/<domain>.md`; **announce before spending any research call**, in the form `Domain: <name> (inferred) — <primary sources>. Override with --domain.`
4. `### Phase 1: Parallel Research Fan-Out` — dispatch the domain's roster **in a single message**. Give each subagent: the subject, its roster entry, its backend's query patterns, and the return contract below. State explicitly that subagents return digests, never raw pages.
5. `### Phase 2: Merge and Synthesize` — dedupe by URL, rank by the domain's Source Ranking, write a ~500-word synthesis (~3000 chars; the hook warns below 2500).
6. `### Phase 2.5: Save Local Files` — always runs. Structure below.
7. `### Phase 3-5: NotebookLM (optional)` — **one unit.** If NotebookLM is absent or `--no-notebook` is set, all three phases skip together with a single notice, and the NotebookLM tables are omitted from the final report.
8. `### Phase 6: Companion Visuals` — 6a ASCII diagram always; 6b playground **only when the domain's Output Settings say yes** (tech only), delegating to `Skill(skill="playground:playground", ...)`.
9. `### Phase 7: CandleKeep Field Research Offer` — per `references/candlekeep-integration.md`.
10. `## Examples` — at least three, covering one per domain, including one degraded run with NotebookLM absent.
11. `## Error Recovery` — a table.

**Subagent return contract — reproduce verbatim in Phase 1:**

```json
[{"url": "...", "title": "...", "kind": "official_docs|tutorial|discussion|library|primary_text",
  "why_it_matters": "one sentence", "key_claims": ["...", "..."]}]
```

**Token-economy rules — reproduce in Phase 1:**

- Tavily subagents MUST pipe `tvly --json` through Python per the `tavily-dynamic-search` pattern so raw HTML never enters context. Never call bare `tvly`.
- Exa subagents have no pipe to interpose; they use `highlights` to triage all results, then `text` with an explicit `maxCharacters` for only the 3–5 keepers.

**Local file structure — reproduce in Phase 2.5:**

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

**State file — reproduce in Phase 2:**

```bash
echo "{\"topic\":\"$SUBJECT\",\"domain\":\"$DOMAIN\",\"notebooks\":[],\"total_sources\":0,\"candlekeep\":{\"read_ids\":[],\"write_id\":null},\"local_path\":\"$HOME/dev/learn-research/learn-$TOPIC_SLUG/\"}" > "/tmp/learn-workflow-state-$TOPIC_SLUG.json"
```

All five keys `topic`, `domain`, `notebooks`, `total_sources`, `local_path` are required — Task 2's hook rejects the file otherwise.

**Error Recovery table — the NotebookLM row MUST read "skip phases 3-5, continue", never "STOP workflow".** The only `STOP workflow` entry permitted in the entire file is for zero search backends.

- [ ] **Step 1: Record the pre-state**

```bash
cd ~/dev/learn-toolkit
grep -c 'STOP workflow' plugins/learn-toolkit/skills/learn/SKILL.md
grep -n 'no-ck-read\|ck-write\|2025 2026\|max-results 10\|crawling_exa\|deep_researcher' plugins/learn-toolkit/skills/learn/SKILL.md
```

Expected: a non-zero `STOP workflow` count and several hits — all of which must be gone by Step 3.

- [ ] **Step 2: Write the new `SKILL.md`** following the structure above.

- [ ] **Step 3: Verify**

```bash
cd ~/dev/learn-toolkit
S=plugins/learn-toolkit/skills/learn/SKILL.md

python3 -c "
import sys,yaml
t=open('$S').read()
assert t.startswith('---'), 'no frontmatter'
fm=yaml.safe_load(t.split('---')[1])
assert fm['name']=='learn-toolkit:learn', fm['name']
assert 'Task' in fm['allowed-tools'], 'Task tool missing — fan-out cannot run'
assert str(fm['metadata']['version'])=='2.0.0', fm['metadata']['version']
print('FRONTMATTER OK')
"

test "$(grep -c 'STOP workflow' $S)" -le 1 && echo "STOP COUNT OK"
! grep -q 'no-ck-read\|--ck-write' $S && echo "OLD FLAGS GONE"
! grep -q '2025 2026' $S && echo "NO QUERY-STRING RECENCY HACK"
! grep -q 'crawling_exa\|deep_researcher' $S && echo "NO DEPRECATED EXA TOOLS"
! grep -q 'max-results 10' $S && echo "MAX RESULTS SANE"
! grep -q '/tmp/learn-workflow-state.json' $S && echo "STATE FILE SCOPED"
grep -q 'tvly auth' $S && echo "AUTH PROBE CORRECT"
grep -q 'dev/learn-research' $S && echo "OUTPUT PATH OK"
for d in tech philosophy judaism; do grep -q "domains/$d" $S || grep -q "domains/<domain>" $S; done && echo "DOMAIN REFS OK"

claude plugin validate plugins/learn-toolkit --strict && echo "PLUGIN VALIDATES"
```

Expected: every line prints its OK message.

- [ ] **Step 4: Confirm referenced files exist**

```bash
cd ~/dev/learn-toolkit/plugins/learn-toolkit/skills/learn
for f in references/domains/tech.md references/domains/philosophy.md references/domains/judaism.md \
         references/candlekeep-integration.md references/notebooklm-loading.md references/artifact-generation.md; do
  test -f "$f" && echo "OK   $f" || echo "MISS $f"
done
```

Expected: all `OK`. A `MISS` means Wave A did not complete — stop and report.

---

### Task 5: Rewrite `candlekeep-integration.md` for field research

**Files:**
- Modify (full rewrite): `plugins/learn-toolkit/skills/learn/references/candlekeep-integration.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the Phase 0.5 scan procedure and the Phase 7 field-research offer that `SKILL.md` calls into.

**Background the implementer needs — these constraints were learned in production and must all appear in the file:**

1. CandleKeep pagination splits on `#` H1 and **ignores code fences** — author one H1 per intended page.
2. CandleKeep injects a blank line above any `#` inside a fence — **escape `#` at write time**.
3. A book is capped at **1,000,000 bytes**; overflow returns HTTP 413.
4. Appends use `ck items append <book-id>`, **not** `ck ms <id>`.
5. **Verify a write with `ck items read <id>:<n>`, never the command log** — a `BadRecordMac` TLS error can hit the *response* while the write itself succeeded.
6. `ck items enrich --add-prompt` and `--sample-question` must be set **at creation**, or the book is not agent-queryable.

- [ ] **Step 1: Record the pre-state**

```bash
grep -n '/tmp/learn-\|no-ck-read\|ck-write' ~/dev/learn-toolkit/plugins/learn-toolkit/skills/learn/references/candlekeep-integration.md
```

Expected: hits on line ~21 (`--no-ck-read`), ~92 (`/tmp/learn-<topic-slug>/`) — all must be gone by Step 3.

- [ ] **Step 2: Rewrite the file** with these sections:

- `## Overview` — read on every domain, unconditionally; there is no skip flag. Write is an offer at Phase 7, not a flag.
- `## CLI Detection` — `ck --version`; absence is not an error.
- `## Library Scan (Phase 0.5)` — **runs for every domain.** `ck items list --json`, match on topic keywords, take up to 3, `ck items toc <id>`, then `ck items read "<id>:<pages>"`. Store as `ck_sources[]` with `{id, title, content_snippet}`.
- `## Field Research Offer (Phase 7)` — containing the following, verbatim:

  **Existence check must be format-tolerant.** Only one precedent book exists
  (`Claude Code Orchestration in Practice — Field Research 2026-08`); that is n=1, not a
  convention. Match case-insensitively on `field research` **plus** topic tokens, so an
  existing book is found whatever shape its title takes. A strict match would silently
  create duplicates.

  ```bash
  ck items list --json --no-session | python3 -c "
  import json,sys,re
  topic_tokens = [t for t in re.split(r'\W+', '<TOPIC>'.lower()) if len(t) > 3]
  items = json.load(sys.stdin)
  items = items if isinstance(items, list) else items.get('items', [])
  for i in items:
      t = (i.get('title') or '').lower()
      if 'field research' in t and any(tok in t for tok in topic_tokens):
          print(i['id'], '|', i['title'])
  "
  ```

  If nothing matches, create:

  ```bash
  ck items create "Field Research — <Topic>" \
    --description "Field research on <Topic>. Started by learn-toolkit on <YYYY-MM-DD>." \
    --no-session
  ck items enrich <id> \
    --add-prompt "Consult this book for field-research findings on <Topic>, including sources consulted and open questions." \
    --sample-question "What did the field research on <Topic> conclude?" \
    --no-session
  ```

  Append, then verify by reading back:

  ```bash
  ck items append <book-id> --file <path-to-entry.md> --no-session
  ck items read "<book-id>:<n>" --no-session   # the ONLY valid verification
  ```

- `## Entry Format` — one `#` H1 per page; `#` inside fences escaped; each entry dated and carrying subject, domain, sources consulted, key findings, open questions.
- `## Source Hierarchy` — note that ranking is per-domain and defined in `domains/<domain>.md`, not here.
- `## Local Files` — canonical path `$HOME/dev/learn-research/learn-<topic-slug>/`. **Never `/tmp`.**

- [ ] **Step 3: Verify**

```bash
cd ~/dev/learn-toolkit
F=plugins/learn-toolkit/skills/learn/references/candlekeep-integration.md
! grep -q '/tmp/learn-' $F && echo "NO TMP PATHS"
! grep -q 'no-ck-read\|--ck-write' $F && echo "OLD FLAGS GONE"
grep -q 'ck items append' $F && echo "APPEND DOCUMENTED"
grep -q 'ck items read' $F && echo "READBACK VERIFY DOCUMENTED"
grep -q 'add-prompt' $F && grep -q 'sample-question' $F && echo "ENRICH DOCUMENTED"
grep -qi '1,000,000\|1000000' $F && echo "SIZE CAP DOCUMENTED"
grep -qi 'badrecordmac' $F && echo "TLS TRAP DOCUMENTED"
grep -q 'field research' $F && echo "EXISTENCE CHECK PRESENT"
```

Expected: every line prints its OK message.

---

### Task 6: Update the NotebookLM references for optional mode

**Files:**
- Modify: `plugins/learn-toolkit/skills/learn/references/notebooklm-loading.md`
- Modify: `plugins/learn-toolkit/skills/learn/references/artifact-generation.md`

**Interfaces:**
- Consumes: the Global Constraints' language defaults.
- Produces: reference files that `SKILL.md` Phases 3–5 call into, with per-domain language and a documented skip path.

- [ ] **Step 1: Read both files first**

```bash
cd ~/dev/learn-toolkit/plugins/learn-toolkit/skills/learn/references
cat notebooklm-loading.md
cat artifact-generation.md
```

- [ ] **Step 2: Edit `notebooklm-loading.md`**

Add a section at the very top, before any existing content:

```markdown
## Optional — skip conditions

NotebookLM is **optional**. Phases 3, 4 and 5 form one unit and skip **together** when
either is true:

- NotebookLM tools were not found in Phase 0
- `--no-notebook` was passed

When skipped, emit exactly one notice — `NotebookLM not available — skipping the notebook
package. Research, local files and the CandleKeep offer are unaffected.` — omit the notebook
and artifact tables from the final report, and continue to Phase 6. **Never stop the
workflow because NotebookLM is missing.**
```

Then replace any hardcoded `language="he"` with a reference to the resolved domain language.

- [ ] **Step 3: Edit `artifact-generation.md`**

Replace hardcoded `language="he"` with `language=<resolved domain language>`, and add above the artifact table:

```markdown
The language is the resolved domain language from Phase 0.5 — `en` for `tech`, `he` for
`philosophy` and `judaism` — unless `--language <code>` overrode it. Do not hardcode `he`.
```

Adapt each artifact's focus to the domain's `## Output Settings` guidance rather than always using the implementation-focused Study Guide brief.

- [ ] **Step 4: Verify**

```bash
cd ~/dev/learn-toolkit/plugins/learn-toolkit/skills/learn/references
grep -q 'skip conditions' notebooklm-loading.md && echo "SKIP DOCUMENTED"
grep -qi 'never stop the workflow' notebooklm-loading.md && echo "NO-STOP RULE PRESENT"
! grep -q 'language="he"' artifact-generation.md && echo "NO HARDCODED HEBREW (artifacts)"
! grep -q 'language="he"' notebooklm-loading.md && echo "NO HARDCODED HEBREW (loading)"
grep -q 'domain language' artifact-generation.md && echo "DOMAIN LANGUAGE REFERENCED"
```

Expected: every line prints its OK message.

---

### Task 7: Documentation — WAVE C, run last

**Files:**
- Modify (full rewrite): `plugins/learn-toolkit/README.md`
- Modify: `README.md` (repo root)
- Modify: `plugins/learn-toolkit/references/setup-guide.md`

**Interfaces:**
- Consumes: the final state of Tasks 1–6. Read the actual files; do not describe intended behaviour.

**Background:** all three documents currently describe a three-command surface (`/learn-toolkit:visualize`, `/learn-toolkit:playground`, `/learn-toolkit:learn`). Two of those no longer exist. `plugins/learn-toolkit/CLAUDE.md` was deleted in Task 1 because a plugin-root CLAUDE.md is not loaded by Claude Code — any content worth keeping from it (the API-key safety notes) moves into the plugin README.

- [ ] **Step 1: Confirm what actually exists before writing about it**

```bash
cd ~/dev/learn-toolkit
ls plugins/learn-toolkit/skills/
ls plugins/learn-toolkit/skills/learn/references/ plugins/learn-toolkit/skills/learn/references/domains/
jq -r '.version, .description' plugins/learn-toolkit/.claude-plugin/plugin.json
```

- [ ] **Step 2: Rewrite `plugins/learn-toolkit/README.md`** covering: the single `/learn <subject>` command and its three flags; the three domains and how inference plus `--domain` works; the per-domain language defaults; setup for Tavily, Exa, CandleKeep, Sefaria, NotebookLM, marking each optional or required; what degrades when each is absent; and the API-key safety rules carried over from the deleted CLAUDE.md — **never ask for, display, or log a key value; if a user pastes one, tell them to rotate it; keys are `${ENV_VAR}` references in `.mcp.json` only.**

- [ ] **Step 3: Update the root `README.md`** to describe the marketplace and point at the plugin README. Remove every reference to `visualize` and `playground`.

- [ ] **Step 4: Update `references/setup-guide.md`** — same command-surface correction; `tvly auth` as the authentication check; the canonical Exa `tools=` list from Global Constraints.

- [ ] **Step 5: Verify no stale references survive anywhere**

```bash
cd ~/dev/learn-toolkit
! grep -rn 'learn-toolkit:visualize\|learn-toolkit:playground' \
    --include=*.md --include=*.json . && echo "NO STALE SKILL REFS"
! grep -rn 'crawling_exa\|deep_researcher' --include=*.md --include=*.json . \
    && echo "NO DEPRECATED EXA TOOLS"
! grep -rln '/tmp/learn-workflow-state.json' --include=*.md --include=*.sh . \
    && echo "NO UNSCOPED STATE FILE"
grep -rn 'tvly --status' --include=*.md . && echo "WRONG AUTH PROBE — FIX" || echo "AUTH PROBE OK"
claude plugin validate plugins/learn-toolkit --strict && echo "PLUGIN OK"
claude plugin validate . --strict && echo "MARKETPLACE OK"
shellcheck plugins/learn-toolkit/hooks/*.sh && echo "SHELLCHECK CLEAN"
```

Expected: every line prints its OK message. This is the final acceptance gate for the whole plan.

Note: the spec's own text legitimately mentions `crawling_exa` and `deep_researcher_*` when documenting what was removed. Scope the greps above to exclude `docs/` if it produces false positives:
`--exclude-dir=docs`.

---

## Self-Review

**Spec coverage.** §3 command surface → T4. §4 domain profiles → T3. §5 inference → T4 Phase 0.5. §6 phases → T4. §7 subagent contract and token economy → T4. §8 tool rules → T3 query patterns + T4. §9 CandleKeep field research → T5. §10 tooling upgrade → already done, no task needed; the plugin-side `.mcp.json` half → T1. §11 file inventory → T1, T2, T7. §12 out of scope → no task, correct. §13 risks → mitigations are embedded in T3 (domain files carry only overrides) and T4 (announce domain before spending).

**Additions beyond the spec**, found by running the validators during planning: `plugin.json`'s `mcp` and `requiredEnvVars` are unknown fields Claude Code ignores, and `mcp` additionally points outside the plugin directory; `plugins/learn-toolkit/CLAUDE.md` is never loaded. All three handled in T1.

**Type/name consistency.** `learn-toolkit:learn` is the skill name in T4 frontmatter and nowhere contradicted. The five domain-file headings in T3's Interfaces match what T4 Step 4 checks for. The state-file key set `topic, domain, notebooks, total_sources, local_path` is identical in T2's hook and T4's `echo`. The path `$HOME/dev/learn-research/learn-<topic-slug>/` is identical in T2, T4, T5.

**Placeholder scan.** No TBD/TODO. Every code step carries real content. `<Topic>`, `<id>`, `<domain>` are runtime substitutions inside documented commands, not plan placeholders.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-25-learn-single-skill-refactor.md`.
