# Gemini app Deep Research lane

An opt-in research lane. It drives the Gemini web app in the user's Chrome through Claude in
Chrome and runs up to three Deep Research reports, one at a time. It is Phase 1b work, after
the NotebookLM Deep Research lane.

Account risk: Google Support has told users that automating the Gemini app is not permitted.
This lane drives the user's signed-in Google account, so it is opt-in only.

The lane never runs without `--gemini`.

## When it runs

Both must hold, otherwise skip it silently:

- `$GEMINI_RUNS` is set (`--gemini` or `--gemini=N`, N from 1 to 3)
- `HAS_CHROME` is true (Phase 0 found a tool ending in `__tabs_context_mcp`)

If `--gemini` was passed but `HAS_CHROME` is false, tell the user to connect Claude in Chrome
and skip the lane.

## 1. Load the Chrome tools once

Load every tool in ONE `ToolSearch` call with a `select:` query naming these tools by
suffix: `tabs_context_mcp`, `tabs_create_mcp`, `navigate`, `computer`, `find`,
`get_page_text`, `tabs_close_mcp`. Use the full discovered names in later calls. Never write a
server prefix in prose or in a prompt.

## 2. Open a tab

1. Call `tabs_context_mcp` first.
2. Create a new tab with `tabs_create_mcp`. Never reuse the user's tabs.
3. Navigate to `https://gemini.google.com/app`.
4. If Google asks to sign in, stop the lane and tell the user to sign in themselves.
   Never type credentials.

## 3. Start Deep Research

1. Open the "Upload & tools" button (the `+` left of the prompt box).
2. "Deep research" is a direct item on tall viewports. On short viewports it sits under
   "More tools". Reach it by keyboard: ArrowUp to "More tools", ArrowRight, then Return on
   "Deep research".
3. Confirm the chip "Deep research" shows in the prompt box.
4. Type the prompt. Build it from the subject plus one scoped angle per run:
   - Run 1: architecture and core concepts.
   - Run 2: verification, quality and evaluation.
   - Run 3: operations, economics and roles.

   Ask for a detailed report (not a summary), citations for every claim, written in
   `$LANGUAGE`, with newcomer-friendly basics first.
5. Gemini shows a research plan. Click "Start research" (it may also start by itself).
   The report says it can take up to 60 minutes.

## 4. One run at a time

Never start the next run until the current report is finished or abandoned. A live run on
2026-11-23 showed why: two concurrent runs failed with "I encountered an error" and "Sorry,
something went wrong", and a retry then hung on "Generating research plan".

## 5. Wait

Poll about every 5 minutes, for up to 60 minutes. Check with a screenshot at reduced scale,
or use `find` for "Creating your report". Past 60 minutes, record the run with status
`running` and its chat URL, then move on. The final report lists it.

## 6. Read and save the report

1. Open the report panel and call `get_page_text` on the tab.
2. Save it to `~/dev/learn-research/learn-<topic-slug>/gemini-reports/NN-<slug>.md`
   (NN is 01 to 03), with the chat URL at the top.
3. Use `Bash(mkdir *)` and `Write` for the folder and file.

## 7. Notebook

If `HAS_NOTEBOOKLM` is true, `--no-notebook` was not passed and `notebooks` in the state
file is empty (the NotebookLM research lane was off or failed before creating one), create
the `[Topic] - Core Learning` notebook now and record it in `notebooks[]`. Phase 3 reuses it.

When a notebook exists, call `source_add` with `source_type=text`, title
`Gemini Deep Research NN: <title>`. It counts against the 98-source budget: compute
`98 - total_sources` first, and handle overflow per
`${CLAUDE_SKILL_DIR}/references/notebooklm-loading.md`. After each `source_add`, increment
`total_sources` (and the per-notebook count if the state file keeps one) in the state file.
With `--no-notebook` or no NotebookLM, keep the local file only.

## 8. Digests

Distil each report into `deep_research` digests, with citations from the report's own source
list, for Phase 2. Never paste the full report into context.

## 9. State

Record each run in the state key `gemini_research`, a list of
`{"n","chat_url","status","local_path","source_id"}`. Use `null` for fields that do not
exist yet. If the state file `/tmp/learn-workflow-state-<topic-slug>.json` does not exist
yet, create it with the `Write` tool (the five required keys `topic`, `domain`, `notebooks`,
`total_sources`, `local_path`, plus `candlekeep`, `deep_run_id`, `notebooklm_research`,
`gemini_research`). If it exists, Read it and update only the keys this lane changes.

## 10. Failures

- A Gemini error or hang ("Something went wrong", stuck on "Generating research plan"):
  record it in `gemini_research`, retry that run once serially, then skip that run and
  continue with the next.
- A menu or UI element not found after 2-3 attempts: stop the whole lane (the UI likely
  changed) and record it.
- Do not trigger browser dialogs.
- Signed out of Google: tell the user to sign in themselves.
- Close every tab the lane opened with `tabs_close_mcp`, even after a failure.

UI labels as of 2026-11-23: Upload & tools, More tools, Deep research, Start research,
Creating your report. If Gemini renames them, fix this file only.
