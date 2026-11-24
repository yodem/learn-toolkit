# YOT-238: /learn --deep runs NotebookLM and Gemini-app Deep Research lanes (2026-11-23)

repo: /Users/yotamfromm/dev/learn-toolkit
worktree: /Users/yotamfromm/dev/learn-toolkit
branch: yot-238-deep-research-lanes
base sha: b3e79cefe5c9b64d54b21b718c94e5059a8df86d
kind: feature
ticket: YOT-238
page: https://claude.ai/artifact/UHWmy84No1WbqXjrURP2ux

## In plain words
`/learn --deep` gets two more deep-research lanes. The NotebookLM lane creates the topic's notebook early, in Phase 1b, and runs three focused NotebookLM Deep Research jobs one after another. From each job it imports the report plus the top sources, staying under the 98-source threshold, and reads the reports back into the digests. The Gemini lane runs only with a new `--gemini` flag (`--gemini=N`, up to 3). It drives gemini.google.com through Claude in Chrome, one report at a time. Each report is read from the page, saved locally and added to the notebook as a text source. Both lanes skip cleanly when their tools are missing.

## Goal criteria
- G1 With --deep and NotebookLM available, /learn creates the notebook in Phase 1b and runs scoped NotebookLM Deep Research jobs one at a time, importing the report and top sources within the 98-source threshold. The report text feeds the Phase 2 digests.
- G2 With --gemini (or --gemini=N, N up to 3) and Claude in Chrome available, /learn runs Gemini-app Deep Research reports one at a time, saves each locally and adds it to the notebook as a text source. Without the flag the lane never runs.
- G3 Each lane degrades instead of stopping when its tools, auth or quota are missing. Phase 0 reports both lanes in the backend matrix, and the error table covers their failures.
- G4 The plugin ships as 2.5.0 with docs describing the lanes, and lint, tests and plugin validate all pass.

## Decisions
- Q1 When does the Gemini app lane run? Decision: A Only with a new --gemini flag: one report by default, --gemini=N for up to 3, run one after another. Alternatives: B Automatically with every --deep run when Chrome is connected; C Don't ship the Gemini lane; ship only the NotebookLM lane; D A separate skill (/learn-toolkit:gemini-research) you run on its own, outside /learn. Consequences: Long Gemini reports in the notebook without you doing the clicking. If skipped: Only NotebookLM's built-in Deep Research runs; no Gemini app reports.
- Q2 When should NotebookLM Deep Research run? Decision: A In Phase 1b: create the notebook early, run the jobs, read the reports back into the digests. Alternatives: B In Phase 3: run the jobs after the notebook is created; the synthesis doesn't use them. Consequences: Either a richer synthesis, or a smaller change. If skipped: The lane can't run, because it needs a notebook.
- Q3 How does a Gemini report get into the notebook? Decision: A Read the report text from the page, save it locally, add it as a text source. Alternatives: B Export to Google Docs, then add the Doc as a Drive source. Consequences: The report as a notebook source, plus a local copy in the research folder. If skipped: Reports stay only in the Gemini chat.
- D1 NotebookLM Deep Research jobs per --deep run: 3 focused jobs, one after another (default kept). Alternatives: 1 job. Consequences: a small call, changeable later.
- D2 Sources imported per job: The report plus the top 12 sources, kept under the 98-source threshold (default kept). Alternatives: All cited sources. Consequences: a small call, changeable later.
- D3 Wait for a Gemini report: Up to 60 minutes, checking about every 5 minutes; then report it as still running (default kept). Alternatives: Up to 20 minutes. Consequences: a small call, changeable later.
- D4 Release version: 2.5.0 (default kept). Alternatives: 3.0.0. Consequences: a small call, changeable later.
- Challenge: It adds two optional deep-research lanes to /learn --deep, each with its own reference file. Alternatives: The simplest version is the NotebookLM lane only, which uses tools the plugin already connects to and carries no account risk. Consequences: The Gemini lane depends on Gemini's web UI, which changed twice in today's run (the menu moved under More tools), so it will need upkeep.

## Changes
- none yet

## Insights
- none yet

## Assumptions
- proven: Phase 0 probes NotebookLM with ToolSearch "+notebooklm" but does not list the research tools (plugins/learn-toolkit/skills/learn/SKILL.md:100).
- proven: the notebook is created in Phase 3, after the deep-research section (plugins/learn-toolkit/skills/learn/SKILL.md:484).
- proven: lint check 9 flags hardcoded prefixes only for exa, exa-agent, tavily and web-research (plugins/learn-toolkit/scripts/lint-skill.sh:814); AGENTS.md still asks for ToolSearch discovery in SKILL.md.
- proven: lint check 13 matches the hard-stop sentence verbatim, so the sentence at plugins/learn-toolkit/skills/learn/SKILL.md:154 must not be reworded.
- proven: the validate-output hook requires only 5 state keys and ignores extra ones (plugins/learn-toolkit/hooks/validate-output.sh:44).
- proven: allowed-tools lists no MCP tools, so MCP calls need no frontmatter change (plugins/learn-toolkit/skills/learn/SKILL.md:5).
- inferred: Gemini runs one Deep Research job at a time: in today's live run two concurrent runs failed with "I encountered an error"; Step 5's live run settles it.
- inferred: the research_status task id can differ from the research_start one, and cited_only can import about 37 sources (seen in today's live run); Step 5's live run settles it.
- inferred: the Gemini web UI labels (Upload & tools, More tools, Deep research, Start research) stay stable enough to drive; Step 5's live run settles this.

- inferred: the live run needs Chrome signed in to Gemini with Deep Research quota left, and NotebookLM authenticated (`nlm login --check`); Step 5 records whether this held.

## Out of scope
- Gemini API (AI Studio) deep research.
- Running Gemini reports in parallel.
- Changing the studio artifacts (podcast, mind map and the rest).

scope-ok: docs/plans/2026-11-23-deep-research-lanes/step2.brief.md builder brief for step 2
scope-ok: docs/plans/2026-11-23-deep-research-lanes/step3.brief.md builder brief for step 3
scope-ok: docs/plans/2026-11-23-deep-research-lanes/step4.brief.md builder brief for step 4

## Review focus
- Lead calls from the plan review (lens B):
  - `--gemini` alone implies `--deep` (it sets `$DEEP_EFFORT=medium` when unset).
  - With `--no-notebook` or no NotebookLM, Gemini reports are saved locally and still feed the digests; only the notebook add is skipped.
  - Steps 2, 3 and 4 run one after another because all three edit SKILL.md.
  - The live run loads this branch with `claude --plugin-dir plugins/learn-toolkit`.
- The Gemini lane must stay strictly opt-in, serial, and capped at 3 reports per run.
- The source budget must never push a notebook past 98 without overflow.
- SKILL.md must keep its exact lint-matched sentences.

## Step 1: Commit the plan [G1] [G2] [G3] [G4]
executor: lead
files: docs/plans/2026-11-23-deep-research-lanes.md, docs/plans/2026-11-23-deep-research-lanes/page.json
Produces: the approval record.
- check: test -n "$(git -C /Users/yotamfromm/dev/learn-toolkit log -1 --format=%s -- docs/plans/2026-11-23-deep-research-lanes.md)"
- check: test -z "$(git -C /Users/yotamfromm/dev/learn-toolkit status --porcelain -- docs/plans/2026-11-23-deep-research-lanes.md)"

## Step 2: NotebookLM Deep Research lane [G1] [G3]
executor: auto
files: plugins/learn-toolkit/skills/learn/references/notebooklm-deep-research.md (new), plugins/learn-toolkit/skills/learn/SKILL.md, plugins/learn-toolkit/skills/learn/references/notebooklm-loading.md
Runs after: Step 1. Steps 2, 3 and 4 run one at a time.
Produces:
- A reference file with the procedure:
  - Create the notebook early.
  - Run 3 scoped queries one after another.
  - `research_start` in deep mode.
  - Poll `research_status` by notebook and use the task id it returns.
  - `research_import` with `source_indices` for the report plus the top 12, under the 98 budget, with overflow.
  - Read the report back through `source_get_content` and turn it into `deep_research` digests.
  - State key `notebooklm_research`.
  - Quota and timeout handling.
- SKILL.md changes:
  - The Phase 0 probe and a `HAS_NOTEBOOKLM_RESEARCH` flag.
  - A matrix entry.
  - A NotebookLM subsection in the deep-research section.
  - Phase 3 reuses the early notebook and keeps `notebooks[]`, `total_sources` and overflow at 98 correct.
  - The report text feeds the Phase 2 digests as `deep_research` entries.
  - Error rows.
- notebooklm-loading.md notes the early notebook and the new state key.
- check: grep -q research_import plugins/learn-toolkit/skills/learn/references/notebooklm-deep-research.md
- check: grep -q -E '98|source budget' plugins/learn-toolkit/skills/learn/references/notebooklm-deep-research.md
- check: grep -q 'HAS_NOTEBOOKLM_RESEARCH' plugins/learn-toolkit/skills/learn/SKILL.md
- check: grep -q 'notebooklm_research' plugins/learn-toolkit/skills/learn/SKILL.md
- check: bash plugins/learn-toolkit/scripts/lint-skill.sh

## Step 3: Gemini-app Deep Research lane via Claude in Chrome [G2] [G3]
executor: auto
files: plugins/learn-toolkit/skills/learn/references/gemini-deep-research.md (new), plugins/learn-toolkit/skills/learn/SKILL.md
Produces:
- A reference file with the procedure:
  - The account-risk note.
  - The opt-in only rule.
  - Tab context, then a new tab.
  - Open the Upload & tools menu. Deep research sits there, or under More tools, reached with the keyboard (ArrowUp, ArrowRight).
  - Submit a thorough prompt with search grounding and citations.
  - Click Start research.
  - Poll about every 5 minutes, up to 60 minutes.
  - Read the report text, then save it as `gemini-reports/NN-<slug>.md`.
  - `source_add` text.
  - Exactly one run at a time.
  - Stop after 2-3 failed browser attempts.
  - Close the tabs.
  - A dated note on the UI labels, so a changed UI is fixed in this one file.
- SKILL.md changes:
  - `--gemini` and `--gemini=N` parsing (N up to 3; the flag sets `$DEEP_EFFORT=medium` when unset).
  - The lane never runs without `--gemini`.
  - With no notebook, reports stay local and still feed the digests.
  - Argument-hint update.
  - A Chrome probe with a `HAS_CHROME` flag and a matrix entry.
  - A Gemini subsection.
  - Error rows.
  - Example 5.
- check: test -f plugins/learn-toolkit/skills/learn/references/gemini-deep-research.md
- check: grep -q -- '--gemini' plugins/learn-toolkit/skills/learn/SKILL.md
- check: grep -q 'HAS_CHROME' plugins/learn-toolkit/skills/learn/SKILL.md
- check: grep -q -i 'never runs without' plugins/learn-toolkit/skills/learn/references/gemini-deep-research.md
- check: bash plugins/learn-toolkit/scripts/lint-skill.sh

## Step 4: Version 2.5.0 and docs [G4]
executor: auto
files: plugins/learn-toolkit/.claude-plugin/plugin.json, .claude-plugin/marketplace.json, plugins/learn-toolkit/skills/learn/SKILL.md, README.md, plugins/learn-toolkit/README.md, plugins/learn-toolkit/references/setup-guide.md, CLAUDE.md
Produces:
- 2.5.0 in every version location.
- READMEs, the setup guide and CLAUDE.md describe the two lanes and the `--gemini` account-risk note.
- The plugin README reference tree lists the two new files.
- check: test "$(grep -c '2.5.0' plugins/learn-toolkit/.claude-plugin/plugin.json .claude-plugin/marketplace.json | grep -c ':1')" = 2
- check: grep -q 'version: 2.5.0' plugins/learn-toolkit/skills/learn/SKILL.md
- check: grep -q -- '--gemini' plugins/learn-toolkit/README.md
- check: ! grep -q '2\.4\.0' README.md plugins/learn-toolkit/README.md plugins/learn-toolkit/references/setup-guide.md

## Step 5: Verify [G1] [G2] [G3] [G4]
executor: lead
files: none
Produces: evidence that the suite passes and that the lanes work live.
- check: bash plugins/learn-toolkit/scripts/lint-skill.sh
- check: python3 -m unittest discover -s maintainer/tests
- check: claude plugin validate plugins/learn-toolkit
- check: python3 maintainer/check-backends.py --offline
- check: manual load this branch with claude --plugin-dir plugins/learn-toolkit, then run /learn-toolkit:learn on a small topic with --deep --gemini. Expect NotebookLM research sources, one Gemini report in the new notebook, and gemini-reports/ in the research folder. Then run with --deep only and confirm no Gemini tab opens. If a step fails, the fix goes into the reference file as a fix round.

## Publish
- Push the branch, open a draft PR against main and link it on YOT-238. The merge and the marketplace release wait for Yotam's go-ahead.
