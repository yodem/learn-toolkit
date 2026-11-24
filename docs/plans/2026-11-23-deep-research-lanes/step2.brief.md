# Step 2 brief — NotebookLM Deep Research lane (YOT-238)

Goal (one line): `/learn --deep` also runs 3 scoped NotebookLM Deep Research jobs in Phase 1b, imports each report plus its top 12 sources under the 98-source budget, and feeds the report text into the Phase 2 digests.

Repo: /Users/yotamfromm/dev/learn-toolkit (branch yot-238-deep-research-lanes). Run no git commands that commit or push. Edit only the files below.

## Files
1. NEW `plugins/learn-toolkit/skills/learn/references/notebooklm-deep-research.md`
2. `plugins/learn-toolkit/skills/learn/SKILL.md`
3. `plugins/learn-toolkit/skills/learn/references/notebooklm-loading.md`

## 1. The reference file (procedure)
- Runs only when `$DEEP_EFFORT` is set AND `HAS_NOTEBOOKLM_RESEARCH` is true AND `--no-notebook` was not passed.
- Create the topic notebook early (`notebook_create`, title `[Topic] - Core Learning`), write it into the state file `notebooks[]` (state file `/tmp/learn-workflow-state-<topic-slug>.json`) so Phase 3 reuses it instead of creating a second one.
- Derive 3 scoped questions from the subject (1: core concepts and how it works; 2: current best practices and tooling/approaches; 3: open debates, failure modes, evidence) — phrased in `$LANGUAGE`, shaped by the domain's Source Ranking.
- Jobs run one after another, never in parallel: `research_start(notebook_id, query, source="web", mode="deep")`, then poll `research_status(notebook_id, ...)` about every 30-60 s up to ~15 minutes per job. IMPORTANT lesson from a live run: the task id returned by `research_status` can differ from the one `research_start` returned; always use the id from the latest `research_status` result for `research_import`.
- Import: `research_import(notebook_id, task_id, source_indices=[...])` with the report (deep report source) plus the top 12 sources, not `cited_only` (one live cited_only import brought in ~37 sources). Before each import compute budget = 98 - total_sources; if the planned import would exceed it, trim the index list to fit; if budget is 0, create the overflow notebook per notebooklm-loading.md first. Update `total_sources` and `notebooks[]` after each import.
- Read back: fetch the imported report text with `source_get_content` and map its findings to `deep_research` digests (same JSON shape as the Phase 1 return contract, `kind: "deep_research"`), with URLs from the imported sources. Keep only distilled digests in context, never the full report.
- State key `notebooklm_research`: list of `{"query","task_id","status","imported","report_source_id"}`.
- Failure handling: quota/rate limit, auth error, `failed` status, or poll timeout → record status in `notebooklm_research`, skip that job (a quota error skips the remaining jobs), continue the run. Never stop the workflow. Auth expired → same rule as the existing NotebookLM auth row (user runs `nlm login`).
- Name tools by suffix (`research_start`, `research_status`, `research_import`, `source_get_content`, `notebook_create`) — never a hardcoded `mcp__…` prefix.

## 2. SKILL.md edits
- Phase 0 Step 0b item 4 (line ~100, `ToolSearch(query="+notebooklm")`): also look for `research_start`, `research_status`, `research_import`. Add a flag line in the "Set:" list: `HAS_NOTEBOOKLM_RESEARCH` = true if HAS_NOTEBOOKLM and the three research tools were found.
- Matrix line (~line 145-150): add `[NotebookLM research ✓/✗]` after `[NotebookLM ✓/✗]`.
- Deep research section ("### Deep research (only with --deep)", ~line 357): add a subsection `#### NotebookLM Deep Research` that summarises the lane in 5-8 lines and points to `${CLAUDE_SKILL_DIR}/references/notebooklm-deep-research.md`. Say it runs after the Exa/Tavily deep run, sequentially.
- Phase 2: the NotebookLM digests merge with other `deep_research` entries (one clause near line 399 is enough).
- Phase 3 (line ~484, step 1 "Create notebook"): change to "Create notebook `[Topic] - Core Learning`, unless Phase 1b already created it (`notebooks[-1]` in the state file) — then reuse it and keep counting from `total_sources`."
- Mention state key `notebooklm_research` where the state file is described (Phase 2 writes the state file; add it alongside `deep_run_id`).
- Error Recovery table: add rows for (a) NotebookLM research tools missing → `HAS_NOTEBOOKLM_RESEARCH=false`, skip lane; (b) research job failed / timed out → record in `notebooklm_research`, continue; (c) research quota hit → skip remaining jobs, continue; (d) import would pass 98 → trim indices or overflow.

## 3. notebooklm-loading.md
Add a short section: the notebook may already exist from Phase 1b (NotebookLM Deep Research); reuse `notebooks[-1]`, and the state key `notebooklm_research` records the jobs. Budget imports against the 98 threshold.

## Constraints
- Do NOT reword the hard-stop sentence at SKILL.md:154 or any existing lint-matched sentence. Do not touch the `version:` line (Step 4 does that).
- Follow the skill's "teach basics first" and degrade-never-stop rules. Concise, plain sentences.
- No hardcoded `mcp__` prefixes in SKILL.md or references.

## Checks (all must exit 0; run from repo root)
- grep -q research_import plugins/learn-toolkit/skills/learn/references/notebooklm-deep-research.md
- grep -q -E '98|source budget' plugins/learn-toolkit/skills/learn/references/notebooklm-deep-research.md
- grep -q 'HAS_NOTEBOOKLM_RESEARCH' plugins/learn-toolkit/skills/learn/SKILL.md
- grep -q 'notebooklm_research' plugins/learn-toolkit/skills/learn/SKILL.md
- bash plugins/learn-toolkit/scripts/lint-skill.sh

Return: summary of edits, the check outputs, open questions.
