# NotebookLM Deep Research lane

An extra research lane for `--deep`. NotebookLM runs its own web Deep Research on three
scoped questions, and the reports and best sources land in the topic notebook. It is
Phase 1b work, after the Exa/Tavily deep run, and it always runs one job at a time.

## When it runs

All three must hold, otherwise skip it silently:

- `$DEEP_EFFORT` is set (`--deep` was passed)
- `HAS_NOTEBOOKLM_RESEARCH` is true
- `--no-notebook` was not passed

Tools are found by suffix with `ToolSearch` in Phase 0: `research_start`,
`research_status`, `research_import`, plus `notebook_create` and `source_get_content`.
Never write a server prefix in a call.

## 1. Create the notebook early

Call `notebook_create` with title `[Topic] - Core Learning`. Phase 3 reuses it, so
record it at once. Use the `Write` tool to create the state file
`/tmp/learn-workflow-state-<topic-slug>.json` with the five required keys (`topic`,
`domain`, `notebooks`, `total_sources`, `local_path`), `candlekeep`, `deep_run_id`,
`notebooklm_research: []`, and `gemini_research: []`. Put the notebook in `notebooks[]` as
`{"id","name","url","source_count":0}`. Phase 2 updates this file instead of replacing it.

## 2. Three scoped questions

Phrase each question in `$LANGUAGE` and shape it by the domain's `## Source Ranking`
line (prefer the sources it ranks first):

1. Core concepts: what the subject is and how it works.
2. Current best practices: the approaches and tooling used today.
3. Open debates, failure modes and the evidence for each side.

## 3. Run the jobs, one after another

For each question, in order:

1. `research_start(notebook_id, query, source="web", mode="deep")`.
2. Poll `research_status(notebook_id, ...)` every 30 to 60 seconds, for up to about 15
   minutes, until the status is `completed`.
3. Take the `task_id` from the **latest** `research_status` result. It can differ from
   the one `research_start` returned, and `research_import` needs the latest one.

Never start the next job before the current one is imported or skipped.

## 4. Import under the 98-source budget

Import the report plus the top 12 sources, by index, never `cited_only` (one live
`cited_only` import brought in about 37 sources).

1. Compute `budget = 98 - total_sources` from the state file.
2. Plan the import as the report index plus the 12 best source indices.
3. If the plan is larger than the budget, trim the source indices to fit. If the budget is
   0, create the overflow notebook first, as described in
   `${CLAUDE_SKILL_DIR}/references/notebooklm-loading.md`, and import there.
4. `research_import(notebook_id, task_id, source_indices=[...])`.
5. Update `total_sources` and `notebooks[]` in the state file straight after.

## 5. Read the report back

Call `source_get_content` on the imported report source and map its findings to
`deep_research` digests: the same JSON shape as the Phase 1 return contract, with
`kind: "deep_research"` and URLs taken from the imported sources. Keep only the distilled
digests in context, never the full report. Phase 2 merges them with the other
`deep_research` entries.

## State key

`notebooklm_research` is a list with one entry per job:

```json
{"query": "...", "task_id": "...", "status": "completed|failed|timeout|skipped", "imported": 0, "report_source_id": "..."}
```

## Failure handling

Never stop the workflow. Record the status in `notebooklm_research`, skip that job and
continue.

- `failed` status or a poll timeout: record it, skip the job, go on to the next one.
- Quota or rate limit: record it and skip all remaining jobs.
- Auth error: the same rule as the NotebookLM auth row in the Error Recovery table. Ask
  the user to run `nlm login` themselves, then retry once; if it still fails, skip the lane.
- Research tools missing: `HAS_NOTEBOOKLM_RESEARCH=false`, skip the lane.
