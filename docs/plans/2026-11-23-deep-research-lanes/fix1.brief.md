# Fix round 1 brief — YOT-238 review findings

Goal (one line): make the two Phase 1b lanes (NotebookLM, Gemini) consistent on state-file writes, notebook creation and source counting, and fix the small doc mismatches the review found.

Repo: /Users/yotamfromm/dev/learn-toolkit. No commits or pushes. Files: plugins/learn-toolkit/skills/learn/SKILL.md, references/gemini-deep-research.md, references/notebooklm-deep-research.md (only if needed), CLAUDE.md, README.md, plugins/learn-toolkit/README.md.

## Findings to fix
1. HIGH SKILL.md ~line 458 (Phase 2 state-file write): Phase 2 must preserve the existing state file whenever EITHER Phase 1b lane wrote it (NotebookLM or Gemini), never overwrite `gemini_research`/`notebooklm_research`/`notebooks`/`total_sources` with empty values. gemini-deep-research.md must create the state file in Phase 1b if absent (Write tool), or update it if present.
2. HIGH gemini-deep-research.md ~line 75 (section 7, notebook add): (a) if `HAS_NOTEBOOKLM` is true, `--no-notebook` not passed, and `notebooks` is empty (NotebookLM research lane off or failed before creating one), create the `[Topic] - Core Learning` notebook here and record it in `notebooks[]` (Phase 3 then reuses it per its existing "unless Phase 1b already created it" rule) — make sure the SKILL.md Phase 3 wording covers a notebook created by either lane. (b) After each `source_add`, increment `total_sources` (and the per-notebook count if the state file keeps one) and respect the 98 budget / overflow.
3. MEDIUM gemini-deep-research.md ~line 94: reconcile the failure rule with the SKILL.md Error Recovery row (~line 756). Rule to use in both places: a Gemini error or hang → record in `gemini_research`, retry that run once serially, then skip that run and continue with the next; menu/UI element not found after 2-3 attempts → stop the whole lane (UI likely changed).
4. LOW CLAUDE.md ~line 133: say `--gemini` implies `--deep` (sets effort medium when `--deep` is omitted).
5. LOW README.md line 9 and plugins/learn-toolkit/README.md line 10: `[--deep[=high|xhigh]]` → `[--deep[=low|medium|high|xhigh]]`.

## Constraints
Don't reword lint-matched sentences (Phase 0 hard-stop sentence). Don't change versions. No hardcoded `mcp__` prefixes in new text.

## Checks (repo root, all exit 0)
- bash plugins/learn-toolkit/scripts/lint-skill.sh
- python3 -m unittest discover -s maintainer/tests
- grep -q -E 'deep\[=low\|medium\|high\|xhigh\]' README.md
- grep -q -i 'total_sources' plugins/learn-toolkit/skills/learn/references/gemini-deep-research.md
- grep -q -i 'implies' CLAUDE.md

Return: per-finding summary with file:line, check results, open questions.
