# Step 4 brief — version 2.5.0 and docs (YOT-238)

Goal (one line): ship learn-toolkit as 2.5.0 with docs describing the two new `/learn --deep` lanes (NotebookLM Deep Research; opt-in Gemini app Deep Research via `--gemini`).

Repo: /Users/yotamfromm/dev/learn-toolkit. No commits or pushes. Read `plugins/learn-toolkit/skills/learn/references/notebooklm-deep-research.md` and `references/gemini-deep-research.md` and the `#### NotebookLM Deep Research` / `#### Gemini app Deep Research` subsections of `plugins/learn-toolkit/skills/learn/SKILL.md` first, so the docs match what was built.

## Version 2.4.0 → 2.5.0 (exactly these sites)
- plugins/learn-toolkit/.claude-plugin/plugin.json:3
- .claude-plugin/marketplace.json:13
- plugins/learn-toolkit/skills/learn/SKILL.md:8 (`version: 2.5.0`)
- README.md:67
- plugins/learn-toolkit/README.md:257
- plugins/learn-toolkit/references/setup-guide.md:116
Do not change versions anywhere else (no CHANGELOG unless one exists; if `CHANGELOG.md` exists, add a 2.5.0 entry).

## Docs
- plugins/learn-toolkit/README.md: describe both lanes where `--deep` is documented; document the `--gemini` / `--gemini=N` (N ≤ 3) flag with the account-risk note (Google Support has said automating the Gemini app is not permitted; it drives your signed-in account; opt-in only; reports take up to 60 minutes each, run one at a time; needs Claude in Chrome connected and signed in to Gemini). Add the two new reference files to the reference tree listing.
- README.md (root): one or two lines on the new lanes and `--gemini`.
- plugins/learn-toolkit/references/setup-guide.md: a short optional section "Claude in Chrome (optional, for --gemini)" and note the NotebookLM lane runs with `--deep` when NotebookLM is set up.
- CLAUDE.md: in the Step 4 Confirm table add a row for the Gemini lane (`--gemini`, needs Claude in Chrome, opt-in, account-risk); and one usage example `/learn-toolkit:learn agent harness engineering --deep --gemini`. Keep the "NEVER ask for API keys" rules untouched.

## Constraints
Plain short sentences. No API keys or emails. Don't edit SKILL.md beyond line 8.

## Checks (repo root, all exit 0)
- test "$(grep -c '2.5.0' plugins/learn-toolkit/.claude-plugin/plugin.json .claude-plugin/marketplace.json | grep -c ':1')" = 2
- grep -q 'version: 2.5.0' plugins/learn-toolkit/skills/learn/SKILL.md
- grep -q -- '--gemini' plugins/learn-toolkit/README.md
- ! grep -q '2\.4\.0' README.md plugins/learn-toolkit/README.md plugins/learn-toolkit/references/setup-guide.md
- bash plugins/learn-toolkit/scripts/lint-skill.sh

Return: summary per file, check results, open questions.
