# Step 3 brief — Gemini-app Deep Research lane via Claude in Chrome (YOT-238)

Goal (one line): with `--gemini` (or `--gemini=N`, N ≤ 3) and Claude in Chrome connected, `/learn` runs Gemini-app Deep Research reports one at a time, saves each locally, adds it to the notebook as a text source and feeds it to the digests; without the flag the lane never runs.

Repo: /Users/yotamfromm/dev/learn-toolkit (branch yot-238-deep-research-lanes). No git commits or pushes. Edit only:
1. NEW `plugins/learn-toolkit/skills/learn/references/gemini-deep-research.md`
2. `plugins/learn-toolkit/skills/learn/SKILL.md`

Step 2 already added the NotebookLM lane (see `#### NotebookLM Deep Research` ~line 397 and `references/notebooklm-deep-research.md`); mirror its style and place the Gemini subsection right after it.

## 1. Reference file (procedure)
- Top: account-risk note — Google Support has told users that automating the Gemini app is not permitted; the lane drives the user's signed-in Google account, so it is opt-in only. Include the exact sentence: "The lane never runs without `--gemini`."
- Conditions: `$GEMINI_RUNS` set (from `--gemini`), `HAS_CHROME` true. Runs in Phase 1b after the NotebookLM lane.
- Load the Chrome tools in ONE ToolSearch select call (tabs_context_mcp, tabs_create_mcp, navigate, computer, find, get_page_text, tabs_close_mcp) — name them by suffix, never a hardcoded `mcp__` prefix in prose.
- Call tabs_context first; create a new tab; never reuse the user's tabs.
- Navigate to https://gemini.google.com/app. Open the "Upload & tools" button (the `+` left of the prompt box). "Deep research" is a direct item on tall viewports; on short viewports it sits under "More tools" — reach it by keyboard: ArrowUp to "More tools", ArrowRight, then Return on "Deep research". Confirm the chip "Deep research" shows in the prompt box.
- Prompt: build a thorough prompt from the subject + one scoped angle per run (run 1: architecture/core concepts; run 2: verification, quality and evaluation; run 3: operations, economics and roles), asking for a detailed report (not a summary), citations for every claim, in `$LANGUAGE`, newcomer-friendly basics first.
- Gemini shows a research plan; click "Start research" (it may also start by itself). The report says it can take up to 60 minutes.
- Exactly one run at a time: never start the next run until the current report is finished or abandoned. (Live run 2026-11-23: two concurrent runs failed with "I encountered an error" / "Sorry, something went wrong", and a retry hung on "Generating research plan".)
- Poll about every 5 minutes (screenshot at reduced scale or find "Creating your report"), up to 60 minutes. Past 60 min: record status `running` with the chat URL and move on; the final report lists it.
- Read the finished report: open the report panel, `get_page_text` on the tab. Save it to `~/dev/learn-research/learn-<topic-slug>/gemini-reports/NN-<slug>.md` (NN = 01..03), with the chat URL at the top.
- Notebook: when a notebook exists (Phase 1b NotebookLM lane or `notebooks[-1]`), `source_add` with `source_type=text`, title `Gemini Deep Research NN: <title>`, counting against the 98 budget (overflow per notebooklm-loading.md). With `--no-notebook` or no NotebookLM, keep the local file only.
- Digests: distil the report into `deep_research` digests (citations from the report's source list) for Phase 2; never paste the full report into context.
- State key `gemini_research`: list of `{"n","chat_url","status","local_path","source_id"}`.
- Failure handling: stop the lane after 2-3 failed browser attempts on one step (menu not found, error banner, no response); record it and continue the run. Do not trigger browser dialogs. Signed out of Google → tell the user to sign in themselves; never type credentials.
- Close every tab the lane opened.
- End: a dated note "UI labels as of 2026-11-23: Upload & tools, More tools, Deep research, Start research, Creating your report. If Gemini renames them, fix this file only."

## 2. SKILL.md edits
- Frontmatter argument-hint (line 4): add ` [--gemini[=N]]`.
- Phase 0.5 deep-mode parsing (~line 225): add parsing — bare `--gemini` sets `$GEMINI_RUNS=1`; `--gemini=N` sets N for N in 1..3 (anything else: print allowed values, use 1). `--gemini` alone implies deep mode: if `$DEEP_EFFORT` is unset set it to `medium`. Strip `--gemini`/`--gemini=N` from `$SUBJECT` (update the list of stripped flags). Without the flag leave `$GEMINI_RUNS` unset; the Gemini lane never runs without `--gemini`.
- Phase 0: add a Chrome probe item in Step 0b — `ToolSearch(query="+claude-in-chrome tabs_context")` — and in "Set:" `HAS_CHROME` = true if a tool ending in `__tabs_context_mcp` was found. Only matters with `--gemini`.
- Matrix line: add `[Chrome ✓/✗]` (show `(Gemini lane: N runs)` when `$GEMINI_RUNS` set).
- New `#### Gemini app Deep Research (only with --gemini)` subsection after the NotebookLM one: 6-9 lines summary + pointer to the reference file; include the account-risk sentence, one-at-a-time rule, 60-minute wait, local save, and "With `--no-notebook` or no NotebookLM, reports stay local and still feed the digests."
- Phase 2 state file: add `gemini_research` alongside `notebooklm_research` (and in the echo JSON as `"gemini_research":[]`).
- Error Recovery rows: Chrome not connected with `--gemini` → `HAS_CHROME=false`, skip lane, tell user to connect Claude in Chrome; Gemini shows an error or hangs → record, retry once serially, then skip; Deep research menu item not found → stop lane after 2-3 attempts, note the UI may have changed (fix in gemini-deep-research.md); report still creating after 60 min → record chat URL, continue; signed out of Google → ask user to sign in.
- Example 5 after Example 4: `/learn-toolkit:learn agent harness engineering --deep --gemini=2` — short walk-through in the style of the other examples.

## Constraints
- Do NOT reword the hard-stop sentence (Phase 0 "The only hard stop…" sentence) or any lint-matched sentence; don't touch `version:`.
- No hardcoded `mcp__` prefixes in new content.
- Plain, short sentences; degrade never stop.

## Checks (repo root, all exit 0)
- test -f plugins/learn-toolkit/skills/learn/references/gemini-deep-research.md
- grep -q -- '--gemini' plugins/learn-toolkit/skills/learn/SKILL.md
- grep -q 'HAS_CHROME' plugins/learn-toolkit/skills/learn/SKILL.md
- grep -q -i 'never runs without' plugins/learn-toolkit/skills/learn/references/gemini-deep-research.md
- bash plugins/learn-toolkit/scripts/lint-skill.sh

Return: summary of edits with SKILL.md line ranges, check outputs, open questions.
