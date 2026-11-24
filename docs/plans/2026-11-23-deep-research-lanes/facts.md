# Facts — YOT-238

Facts pass for YOT-238. All paths are under /Users/yotamfromm/dev/learn-toolkit/plugins/learn-toolkit/ ("P/") unless stated. I edited nothing. The repo is at /Users/yotamfromm/dev/learn-toolkit, and SKILL.md is P/skills/learn/SKILL.md ("S").

**Key finding: the notebook is created in Phase 3, after Phase 1b.** NotebookLM deep research needs a notebook first, so the lane has to create or hoist the notebook, or hold its queries until Phase 3.

## 1. SKILL.md
- **Size:** 703 lines, 6355 words (`wc -l -w`). The first `wc` run listed 703 / 6355, so word and line counts are confirmed.
- **Frontmatter (S:1-12):**
  - S:4 `argument-hint` already has `[--deep[=low|medium|high|xhigh]]`.
  - S:5 `allowed-tools: Task, Write, Read, Artifact, Bash(tvly *), Bash(firecrawl *), Bash(uv tool list), Bash(uv tool upgrade tavily-cli), Bash(pipx upgrade tavily-cli), Bash(mktemp *), Bash(python3 *), Bash(trove *), Bash(ck *), Bash(echo *), Bash(mkdir *), Bash(test *), Bash(cat *), Bash(cp *)`.
  - **No MCP tool is listed in allowed-tools.** NotebookLM and Exa MCP calls are not whitelisted there, so no allowed-tools change is needed for them. Check 2 only inspects Bash commands.
  - S:8 `version: 2.4.0`.
  - S:9 `mcp-server: tavily, exa, exa-agent, firecrawl, web-research, notebooklm-mcp`.
- **Important section (S:25-27):** "NotebookLM notebooks cap at 100 sources. Track the running count... overflow before the cap is hit". The threshold is 98 and is defined in `notebooklm-loading.md`.
- **Phase 0 tool discovery (S:44-196):**
  - S:48-81 are Bash probes for the Tavily and Firecrawl CLIs. S:133-143 is the Trove CLI probe.
  - S:85-107 run six `ToolSearch` calls in parallel. Item 4 at S:100-101 is `ToolSearch(query="+notebooklm")`, looking for `mcp__notebooklm-mcp__notebook_create`, `source_add`, `studio_create`, `studio_status`. It does not look for `research_start`, `research_status` or `research_import`.
  - S:109-110 detect `Artifact` by checking the tool list.
  - **Flags (S:112-124):** `HAS_TAVILY_MCP`, `HAS_TAVILY`, `HAS_EXA`, `HAS_EXA_AGENT`, `HAS_SEFARIA`, `HAS_NOTEBOOKLM` (S:120), `HAS_ARTIFACT`, `HAS_WEB_RESEARCH`, `HAS_FIRECRAWL_MCP`, `HAS_FIRECRAWL`. The Tavily CLI flags are set at S:69-71. Chrome has no flag and no probe yet.
  - **Matrix line (S:147-149):** `Research backends: [Tavily MCP ✓/✗] [Tavily CLI ✓/✗] [Tavily CLI auth ✓/✗] [Exa ✓/✗] [Exa Agent ✓/✗] [Sefaria ✓/✗] [Trove ✓/✗] [NotebookLM ✓/✗] [Artifact ✓/✗] [Web research ✓/✗] [Firecrawl MCP ✓/✗] [Firecrawl CLI ✓/✗]`.
  - The hard stop (S:154) is fixed as "HAS_TAVILY, HAS_EXA, HAS_FIRECRAWL and HAS_WEB_RESEARCH all false".
  - S:189-195 list the degrade-instead-of-stop rules, including `HAS_NOTEBOOKLM = false — see Phase 3-5`.
- **Deep-mode parsing (S:223-227):** bare `--deep` sets `$DEEP_EFFORT=medium`, `--deep=<effort>` sets that value, otherwise it is unset. `$WEB_LANES` is 3 when `--deep` is set (S:239-241).
- **Phase 1b "Deep research (only with --deep)" (S:357-393):**
  - It is a `###` heading with no "Phase" prefix, and it sits between Phase 1 and Phase 2.
  - S:361 skips silently unless `$DEEP_EFFORT` is set.
  - S:361-372 give the Tavily CLI fallback, used only when `HAS_EXA_AGENT` is false and the Tavily research CLI and auth flags are true:
    - Write the schema to a `mktemp -d` dir.
    - Run `tvly research ... --no-wait --output-schema`.
    - Run one blocking `tvly research poll` with a 330000 ms Bash timeout.
  - S:374-383 are the Exa path. The `agent_run` question uses `effort=$DEEP_EFFORT`, `systemPrompt` is the domain Source Ranking line plus language, and `outputSchema` is the JSON at S:382 (basics, findings, open_questions).
  - S:385-393 poll `agent_run` with `runId`, at most 6 re-calls. Findings map to `kind: "deep_research"` digests, with URLs taken from `output.grounding[].citations[]`. The run ID is kept as `DEEP_RUN_ID`.
  - Phase 2 writes it as `deep_run_id` in the state file.
  - The Phase 1 return contract (S:282) lists `deep_research` among the `kind` values.
- **Phase 2 (S:395-427):**
  - S:421 writes the state file with `echo "{...}"`, with these keys:
    - `topic`
    - `domain`
    - `notebooks: []`
    - `total_sources: 0`
    - `candlekeep: {read_ids, write_id}`
    - `deep_run_id`
    - `local_path`
  - The state file is `/tmp/learn-workflow-state-$TOPIC_SLUG.json`.
  - The Phase 2 gate (S:426-427) checks the 5 hook keys plus `candlekeep`.
- **Phase 2.5 (S:429-459):** saves local files under `$HOME/dev/learn-research/learn-<slug>/`, with `sources/01-primary.md` to `04-articles.md`.
- **Phase 3-5 NotebookLM unit (S:461-505):**
  - It skips as one unit when `HAS_NOTEBOOKLM` is false or `--no-notebook` is passed. The exact skip notice is at S:471-472.
  - S:477-481 point to `notebooklm-loading.md` and `artifact-generation.md`.
  - **Phase 3 (S:483-489):**
    - (1) Create the notebook `[Topic] - Core Learning`.
    - (2) Add Trove sources first (`wait=false`, title `"Library: …"`).
    - (3) Add URL and primary-text sources (`wait=false`).
    - (4) Add the research summary as a text source (`wait=true`).
    - (5) Update `notebooks[]` and `total_sources` after each addition.
    - (6) Overflow at 98.
  - **Phase 4 (S:491-498):** five artifacts in parallel with `confirm=true`. `language=<resolved domain language>` is used everywhere. `focus_prompt` follows the domain's NotebookLM artifact focus line.
  - **Phase 5 (S:500-505):** poll `studio_status` every 30 s, at most 10 polls.
- **Phase 6 (S:507-559):** 6a is an ASCII diagram. 6b is the learning page, published with `Artifact` after a `quickstart` call.
- **Phase 7 (S:561-584):** the Trove offer. The Final Report is at S:586-598.
- **Examples (S:600-671):**
  - Ex 1 tech full package (S:602-622)
  - Ex 2 judaism with NotebookLM absent (S:624-647)
  - Ex 3 philosophy with degraded search (S:649-663)
  - Ex 4 "tech, deep research with a blank Exa key" (S:665-671), which uses Tavily research. A new example would be Example 5.
- **Error Recovery table (S:673-703):** the header is at S:675-676 and there are 27 rows. The relevant existing rows are:
  - S:677 hard stop
  - S:688 `agent_run` 401
  - S:689 `agent_run` still running
  - S:692 NotebookLM missing or `--no-notebook`
  - S:693 NotebookLM auth expired (asks the user to run `nlm login`)
  - S:694 source add fails for one URL
  - S:695 "Notebook source count reaches 98"
  - S:696 studio artifact generation fails
  - New rows for research timeout, import over the cap, and Chrome or Gemini failures would go near S:695-696.

## 2. References (in P/skills/learn/references/, not P/references/)
Files: `artifact-generation.md` (137 lines), `notebooklm-loading.md` (101), `trove-integration.md` (241), `web-research.md` (80), `firecrawl.md` (51), and `domains/{tech,philosophy,judaism}.md`.

- **notebooklm-loading.md:**
  - L1-13 give the skip conditions. L9-11 repeat the skip notice with slightly different wording from SKILL.md S:471.
  - L17-25 are the notebook-creation table: `[Topic] - Core Learning`, overflow `[Topic] - Deep Dive`, overflow `[Topic] - Community`.
  - L29-40 are the URL `source_add` pattern. It uses a **hardcoded** `mcp__notebooklm-mcp__source_add(notebook_id, source_type="url", url, wait=false)`.
  - L44-52 are the text source.
  - L56-69 are the overflow logic. L59 reads `notebooks[-1].source_count` and L61 triggers at `>= 98`. Then it waits 10 s and checks `studio_status`.
  - L71-92 give the state file schema: `topic`, `domain`, `notebooks[{id, name, url, source_count}]`, `total_sources`, `candlekeep`, `local_path`. It omits `deep_run_id`.
  - L94-99 say the hook requires 5 keys and that the sixth, `candlekeep`, is unchecked.
  - L101 says update the state file after every notebook creation and source addition.
  - **It does not mention `research_start`, `research_status` or `research_import`, and it has no `notebook_create` signature.**
- **artifact-generation.md:**
  - L3-4 say the language is the resolved domain language and must never be hardcoded to `he`.
  - L22, 45, 69, 81 are hardcoded `mcp__notebooklm-mcp__studio_create(...)` calls with `language=<resolved domain language>`. L97 is `studio_status`.
  - It has per-artifact signatures for podcast, infographic, mind map, flashcards, study guide (L19-125), and an optional additional artifact types section at L127.
  - It has no `research_*` content and no source-cap mention.
- Hardcoded `mcp__notebooklm-mcp__` prefixes already exist in the references, so new `research_*` signatures can follow the same style without breaking lint. Lint check 9 does not scan notebooklm or claude-in-chrome.

## 3. scripts/lint-skill.sh (13 checks, defined in P/scripts/lint-skill.sh)
Check names are the `report` labels at L942-954. `TOTAL_CHECKS=13`. It reads SKILL.md, `.mcp.json`, README.md, `setup-guide.md`, `references/domains/*.md` and `web-research.md`.
1. **undefined-vars:** every `$VAR` or `${VAR}` in SKILL.md must be defined somewhere. A definition is `NAME=`, or a line containing the var plus `=`, "is the", or determine/resolve/derive/compute/define/extract/set. The whitelist is HOME, ARGUMENTS, CLAUDE_SKILL_DIR, CLAUDE_PLUGIN_ROOT, TAVILY_API_KEY, EXA_API_KEY, SHELL. Any new `$X` (for example `$DEEP_LANES`) needs a defining line.
2. **allowed-tools:** the first command word in every ```bash fence line, and in inline backticks that lead a line or follow "Run", must be covered by a `Bash(...)` entry in the frontmatter. Fences with "the user" in the 5 preceding lines, and lines starting `! ` or `#`, are skipped. ALL_CAPS words and `/slash-commands` are ignored. Any new Bash command such as `nlm` or `jq` needs an allowed-tools entry.
3. **count-drift:** a phrase like "three sections" or "five keys" must match the list or JSON object count within the next 16 lines.
4. **exa-agreement:** `*_exa` tool names and `agent_run` mentioned in prose must exist in the `tools=` query of the Exa URLs in `.mcp.json`.
5. **deprecated-tools:** deprecated Exa tool names and categories (github, pdf, tweet, linkedin, research paper) must appear with prohibition wording (never/not/no longer/deprecated/removed). Mentioning "research paper" or "pdf" as an Exa category could trip this.
6. **references-exist:** every `references/....md` path in SKILL.md must exist under `skills/learn/`. A new reference file linked from SKILL.md passes if it exists. Nothing enforces that every reference file be linked.
7. **phase-order:** `### Phase N` or `### Phase N-M` headings must be non-decreasing and unique. The "### Deep research (only with --deep)" heading has no "Phase" prefix, so it is ignored by this check.
8. **mcp-config:** every `.mcp.json` server must be `type: http`, have no `apiKey=` in the URL, no `_API_KEY` env references, and any `${user_config.X}` must be declared sensitive in plugin.json.
9. **no-hardcoded-mcp-prefix:** grep for `mcp__(exa|exa-agent|tavily|web-research)__` in SKILL.md, `references/domains/` and `web-research.md`. **The pattern covers only those four servers. `mcp__notebooklm-mcp__` and `mcp__claude-in-chrome__` are not flagged.** AGENTS.md says to discover tools via ToolSearch with no hardcoded prefix, so follow that in SKILL.md even though lint would allow it.
10. **key-advice / agent-polling:** SKILL.md must not advise `export EXA_API_KEY` or `export TAVILY_API_KEY`. If `agent_run` appears, both `runId` and `completed` must also appear.
11. **web-research-optional:** `.mcp.json` web-research must be http, with url `${user_config.web_research_url}` and a Bearer token header. The plugin.json userConfig entries must be `required:false` and `sensitive:true`.
12. **web-research-tools-known:** backticked snake_case identifiers within 40 characters of "web-research", or in table rows of `web-research.md`, must be one of the 16 known tools or prompts or the 2 settings.
13. **web-research-in-matrix:** SKILL.md must contain the literal `[Web research ✓/✗]`, `HAS_WEB_RESEARCH`, and the flattened sentence `` `HAS_TAVILY`, `HAS_EXA`, `HAS_FIRECRAWL` and `HAS_WEB_RESEARCH` are all false ``. Do not reword S:154.
- **There is no word cap, line cap, required-sections check, or SKILL.md size check anywhere in lint.** The only constraints on a new SKILL.md are the 13 checks above.

## 4. Hooks (P/hooks/)
- **hooks.json:** a PostToolUse hook on matcher `Write` runs `validate-output.sh`. A Stop hook with an empty matcher runs `verify-artifacts.sh`.
- **validate-output.sh:**
  - It acts only on files under `$HOME/dev/learn-research/learn-*` or `/tmp/learn-workflow-state-*.json`.
  - A README.md needs a line starting with `#`. `research-summary.md` under 2500 chars only warns.
  - For the state file it requires valid JSON (jq) and the 5 keys `topic domain notebooks total_sources local_path` (L44), and exits 2 if any is missing.
  - **Extra keys are ignored, so new fields such as `deep_notebooklm` or `gemini_deep_research` will not break it.** The state file must keep the 5 keys and stay valid JSON.
- **verify-artifacts.sh:**
  - It reads only `.topic`, `.local_path` and `.total_sources`, for state files under 12 hours old.
  - It warns if `local_path` is missing, `research-summary.md` is missing, or `total_sources == 0`. It reaps files older than 12 hours.
  - **It ignores other keys.** It treats `total_sources` as a number. If imported deep-research sources are added to the NotebookLM count, keep `total_sources` an integer.

## 5. maintainer/tests
- Only one test file exists, `maintainer/tests/test_check_backends.py` (plus a `fixtures/toolRegistry.ts`). Nothing asserts on SKILL.md prose or reference content directly.
- `LintShell.test_lint_detects_prefix_when_rg_is_absent_from_path` copies the plugin, appends `mcp__exa__web_search_exa` to SKILL.md, and expects lint to FAIL on `no-hardcoded-mcp-prefix` with a stripped PATH containing only python3, grep, dirname and basename. Lint must therefore not gain new external dependencies (such as `jq` or `rg`) in its checks.
- `ReviewFixes.test_lint_flags_deprecated_category_without_tool_name` modifies `domains/tech.md` and expects lint to flag it.
- The others test backend-drift and registry parsing (`check-backends.py`, which runs offline against `maintainer/backend-snapshot.json`). They do not read SKILL.md.
- **Practical risk:** lint on the real tree must be clean, because these tests copy the tree and assert on the lint output. Run `bash plugins/learn-toolkit/scripts/lint-skill.sh` and `python3 -m unittest discover -s maintainer/tests`.

## 6. Version locations (current: 2.4.0, per AGENTS.md "Rules")
- `P/.claude-plugin/plugin.json:3` has `"version": "2.4.0"`.
- `/Users/yotamfromm/dev/learn-toolkit/.claude-plugin/marketplace.json:13` has `"version": "2.4.0"`.
- `P/skills/learn/SKILL.md:8` has `version: 2.4.0`. It is not named in AGENTS.md, but bump it with the others.
- `/Users/yotamfromm/dev/learn-toolkit/README.md:67` has `(v2.4.0)`.
- `P/README.md:257` has `version 2.4.0`.
- `P/references/setup-guide.md:116` has `(v2.4.0)`.
- Not version-bearing but worth updating for the feature:
  - the plugin.json description
  - the SKILL.md `description` and `argument-hint` (S:3-4), if a new flag is added
  - the CLAUDE.md Step 3 and Step 4 tables
  - the `P/README.md` NotebookLM section (L177)
  - the `P/README.md` reference-file tree (L277) and the setup-guide, if a new reference file is added
  - the `mcp-server` metadata line (S:9)

## 7. Current SKILL.md size
703 lines and 6355 words. No lint or hook enforces a cap on either.

## Design implications
- **Notebook ordering:** NotebookLM deep research needs a notebook, but notebooks are created in Phase 3, after Phase 1b. Options are to create the notebook inside the NotebookLM deep-research lane, or to defer `research_start` until Phase 3 and run it inside the Phase 3-5 unit. Skip conditions (`HAS_NOTEBOOKLM`, `--no-notebook`) must also cover this lane.
- **Source cap:** `research_import` with `cited_only` or `source_indices` has to respect the 98 threshold in `notebooklm-loading.md` L56-69. Imports need `notebooks[-1].source_count` updated, and a new notebook if the cap would be exceeded.
- **Probes to add:** the NotebookLM probe at S:100-101 should also look for `research_start`, `research_status` and `research_import`. Chrome needs a new `ToolSearch` probe, a new `HAS_*` flag and a matrix entry. Do not reword S:154, because check 13 matches it exactly.
- **No new tool whitelist needed:** allowed-tools holds no MCP tools. A Bash step such as `jq` would need an allowed-tools entry, and `Bash(echo *)` and `Bash(cat *)` already exist.