# Domain: judaism

## Identity

Torah, Talmud, halakha, midrash, Jewish thought and its commentators. Prefer this domain
when a primary Jewish text is the thing being studied, even when the framing is
philosophical.

## Subagent Roster

Three subagents, dispatched in one message:

1. **primary** — Sefaria MCP. This is the authoritative source for this domain and always
   runs first: `mcp__claude_ai_Sefaria__text_search`,
   `mcp__claude_ai_Sefaria__english_semantic_search`,
   `mcp__claude_ai_Sefaria__get_topic_details`,
   `mcp__claude_ai_Sefaria__get_links_between_texts` for commentary chains.
2. **library** — CandleKeep Judaica books (see `../candlekeep-integration.md`).
3. **secondary** — Tavily and Exa, **secondary only**: scholarship and shiurim that
   contextualise the primary text. Never used in place of Sefaria.

## Source Ranking

primary text (Sefaria) > classical commentators > library (CandleKeep) > academic scholarship > shiurim and popular writing

## Query Patterns

Sefaria first. Resolve the topic to a citation before searching the open web, so that
secondary sources are evaluated against the text rather than substituting for it.

Exa secondary research — use `web_search_advanced_exa` with `category: "publication"`;
describe the ideal page:

- GOOD: `"academic article on the reception history of <text> among medieval commentators"`
- BAD: `"<text> commentary history"`

## Output Settings

- Language: `he`
- Learning ladder (Phase 2 synthesis and Phase 6b page): **Basics** — the primary text
  and its plain meaning, with key terms explained; **Advanced usage** — the commentators'
  positions, the sugya's structure and the practical halakha; **Related research** —
  academic scholarship, shiurim and library sources.
- NotebookLM artifact focus: text-and-commentary — sugya structure, positions of the
  commentators, practical halakhic upshot where relevant.
