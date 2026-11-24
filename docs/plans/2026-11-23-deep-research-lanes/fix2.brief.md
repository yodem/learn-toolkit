# Fix round 2 brief — YOT-238 follow-ups

Goal: align the remaining docs and state schema across the two Phase 1b lanes. Repo /Users/yotamfromm/dev/learn-toolkit; no commits. Edit only the cited files.

- MEDIUM plugins/learn-toolkit/skills/learn/references/notebooklm-deep-research.md:24 — Also include `deep_run_id` and `gemini_research: []` when creating `/tmp/learn-workflow-state-<topic-slug>.json` in the NotebookLM lane so the state file schema matches `gemini-deep-research.md` (Section 9) and `SKILL.md` (Phase 2).
- LOW plugins/learn-toolkit/skills/learn/references/notebooklm-loading.md:105 — Mention the Gemini Deep Research lane (`--gemini`, `references/gemini-deep-research.md`) and `gemini_research` here as well, since `gemini-deep-research.md` Section 7 also creates `[Topic] - Core Learning` in Phase 1b when the NotebookLM lane did not.
- LOW plugins/learn-toolkit/skills/learn/SKILL.md:439 — Include the Gemini Deep Research lane alongside the NotebookLM Deep Research lane (`Digests from the NotebookLM and Gemini Deep Research lanes merge with the other deep_research entries.`).
- LOW plugins/learn-toolkit/references/setup-guide.md:128 — Add a row for `Gemini Deep Research (optional, opt-in)` to the Step 4 Confirm table in `setup-guide.md` to match the corresponding table in `CLAUDE.md`.

## Checks (repo root, exit 0)
- bash plugins/learn-toolkit/scripts/lint-skill.sh
- python3 -m unittest discover -s maintainer/tests
- grep -q gemini_research plugins/learn-toolkit/skills/learn/references/notebooklm-deep-research.md
- grep -q -i gemini plugins/learn-toolkit/references/setup-guide.md

Return: per-item summary, check results.
