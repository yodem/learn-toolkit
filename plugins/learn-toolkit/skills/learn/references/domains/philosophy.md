# Domain: philosophy

## Identity

Philosophical concepts, arguments, thinkers, and traditions — analytic or continental,
ancient or modern. Prefer this domain when the answer lives in argument and secondary
literature rather than in documentation or in a religious text tradition.

## Subagent Roster

Three subagents, dispatched in one message:

1. **literature** — Exa `web_search_advanced_exa` with `category: "publication"` for papers,
   plus `category: "personal site"` for essays. Exa's personal-site index is its documented
   strength; use it rather than domain-filtered Tavily here.
2. **overview** — Tavily general search for encyclopedic and orienting material
   (SEP, IEP, university course pages).
3. **library** — CandleKeep, prioritising per-author humanities books
   (see `../candlekeep-integration.md`).

## Source Ranking

primary texts > peer-reviewed literature > library (CandleKeep) > encyclopedic overviews (SEP/IEP) > essays > blog posts

## Query Patterns

Exa — describe the ideal page:

- GOOD: `"scholarly article analysing <thinker>'s argument about <concept> and its critics"`
- BAD: `"<thinker> <concept> criticism"`
- GOOD: `"clear introductory essay explaining the <concept> debate for a graduate reader"`
- BAD: `"<concept> introduction"`

Tavily:

`$OUT` is the subagent's own `mktemp -d` directory (see SKILL.md Phase 1); paste its
literal path.

```bash
tvly search "<subject> Stanford Encyclopedia of Philosophy overview" --depth advanced --chunks-per-source 3 --max-results 6 --json -o "$OUT/overview.json"
```

## Output Settings

- Language: `he`
- Learning ladder (Phase 2 synthesis and Phase 6b page): **Basics** — the question in
  plain words, why it matters and the key terms; **Advanced usage** — the main positions,
  their arguments, objections and replies; **Related research** — primary texts, SEP-style
  overviews and secondary literature.
- NotebookLM artifact focus: argument structure — positions, objections, replies.
