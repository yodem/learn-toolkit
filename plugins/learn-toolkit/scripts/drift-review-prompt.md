You are updating the learn-toolkit Claude Code plugin after its weekly Exa/Tavily drift check.
Read the report JSON. For each finding:
- breaking: fix the plugin so it uses the current tool/parameter (read the upstream docs:
  https://exa.ai/docs/llms.txt, https://docs.tavily.com/llms.txt, the exa-mcp-server and
  tavily-ai GitHub repos). Keep lint-skill.sh's deprecated lists in step with the change.
- info: decide whether the new tool, page or version improves /learn. If yes, make the smallest
  change; if no, say why. Then run `python3 plugins/learn-toolkit/scripts/check-backends.py --update-snapshot`.
Never write an API key anywhere. Never touch .git config. Finish by running
`bash plugins/learn-toolkit/scripts/lint-skill.sh` and
`python3 -m unittest discover -s plugins/learn-toolkit/tests`, and print a short summary:
what drifted, what you changed, what you left and why.
