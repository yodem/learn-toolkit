## Summary
`/learn --deep` gets two more deep-research lanes (YOT-238), and the plugin goes to 2.5.0.
- **NotebookLM Deep Research (Phase 1b, with `--deep`):** the topic notebook is created early. Three scoped Deep Research jobs run one after another. Each imports its report plus its top 12 sources, kept under the 98-source budget with overflow. The reports are read back as `deep_research` digests. New state key: `notebooklm_research`.
- **Gemini app Deep Research (opt-in, `--gemini` / `--gemini=N`, N ≤ 3):** drives gemini.google.com through Claude in Chrome, one report at a time, waiting up to 60 minutes. Each report is saved to `gemini-reports/`, added to the notebook as a text source and turned into digests. New state key: `gemini_research`.
- Both lanes degrade instead of stopping. Phase 0 probes for them and shows them in the backend matrix, and the error table covers their failures.

## Decisions
- Q1 The Gemini lane runs only with `--gemini` (default 1 report, up to 3, one after another).
- Q2 The NotebookLM lane runs in Phase 1b, and its reports feed the synthesis.
- Q3 A Gemini report reaches the notebook as copied page text, plus a local copy.
- D1 3 NotebookLM jobs. D2 the report plus the top 12 sources per job. D3 a 60-minute Gemini wait. D4 version 2.5.0.

## Design
- New reference files: `references/notebooklm-deep-research.md` and `references/gemini-deep-research.md`. SKILL.md summarises each lane and points to its file.
- `--gemini` on its own implies `--deep`. With `--no-notebook`, Gemini reports stay local and still feed the digests.
- Either Phase 1b lane may create the notebook and the state file. Phase 2 and Phase 3 preserve and reuse them.
- Gemini UI labels sit in one dated note in the Gemini reference file, so a UI change is fixed in that one file.
- Plan: `docs/plans/2026-11-23-deep-research-lanes.md`.

## QA checklist
- [x] `lint-skill.sh` 13/13; maintainer tests: 14 OK; `claude plugin validate` passed; `check-backends --offline`: 0 findings
- [x] Cross-harness review: `code-review-x: round 2 verdict=PASS new_critical_high=0` (reviewer agy/gemini; Codex was out of quota). The follow-ups are applied.
- [ ] skill: load the learn skill and follow its first step on a toy input
- [ ] manual: `claude --plugin-dir plugins/learn-toolkit`, run `/learn-toolkit:learn <small topic> --deep --gemini`, and expect NotebookLM research sources plus one Gemini report in the notebook and in `gemini-reports/`. Then run with `--deep` only and confirm no Gemini tab opens.

CI: runs on push. QA: not run (the skill's live lanes need Yotam's signed-in Chrome and NotebookLM).

## Risk
- Google Support has said automating the Gemini app is not permitted, so the Gemini lane carries account risk. It is opt-in only, serial, and capped at 3 reports.
- The Gemini web UI changes often, so the lane needs upkeep in one file.
- The NotebookLM research tools come from the third-party notebooklm-mcp server. When they are missing, the lane is skipped.

## Revert
`git revert` the branch commits, or return the marketplace to 2.4.0. The change is markdown and version strings only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_013DiV1ijho8xt5yMqQW5yNT
