# Artifact Generation Reference

The language is the resolved domain language from Phase 0.5 — `en` for `tech`, `he` for
`philosophy` and `judaism` — unless `--language <code>` overrode it. Do not hardcode `he`.
The signatures below show `language=<resolved domain language>` as a placeholder for that
value.

Each artifact's `focus_prompt` MUST follow the domain's `## Output Settings` →
NotebookLM artifact focus line: implementation-oriented (code examples, pitfalls, action
items) for `tech`; argument structure (positions, objections, replies) for `philosophy`;
text-and-commentary (sugya structure, commentators' positions, practical halakhic upshot)
for `judaism`. Do not always send the `tech`-framed brief — that framing only fits
`tech`. Audio Podcast and Infographic below use the same domain-adapted-brief pattern as
the Study Guide further down this file: `focus_prompt=<domain-specific brief, see
below>` in the call, with the actual text taken from the table underneath it.

## Tool Call Signatures

### Audio Podcast (domain-adapted brief)

```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="audio",
  audio_format="deep_dive",
  audio_length="default",
  language=<resolved domain language>,
  focus_prompt=<domain-specific brief, see below>,
  confirm=true
)
```

| Domain | `focus_prompt` |
|--------|-----------------|
| `tech` | "Explain the core concepts of [topic], how they relate to each other, and practical applications. Cover both fundamentals and advanced patterns, with concrete code examples and common pitfalls." |
| `philosophy` | "Discuss [topic] as a philosophical debate. Lay out the central argument(s) and the positions in play, the strongest objections raised against each, and how their proponents reply. Keep the discussion structured around the argument, not just historical background." |
| `judaism` | "Discuss [topic] as a sugya. Walk through the structure of the text, the positions of the major commentators and where they disagree, and close with the practical halakhic upshot where relevant." |

Audio formats: `deep_dive` (default), `brief`, `critique`, `debate`
Audio lengths: `short`, `default`, `long`

### Infographic (domain-adapted brief)

```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="infographic",
  orientation="portrait",
  detail_level="detailed",
  infographic_style="bento_grid",
  language=<resolved domain language>,
  focus_prompt=<domain-specific brief, see below>,
  confirm=true
)
```

| Domain | `focus_prompt` |
|--------|-----------------|
| `tech` | "Key concepts, implementation steps, and relationships in [topic]. Include a comparison of approaches, common pitfalls, and concrete action items." |
| `philosophy` | "The structure of the argument in [topic]: central positions, the objections raised against each, and the replies made to them. Show how the positions relate to and contend with each other." |
| `judaism` | "The structure of the sugya in [topic]: the text, the major commentators' positions, their key points of dispute, and the practical halakhic upshot." |

Styles: `auto_select`, `sketch_note`, `professional`, `bento_grid`, `editorial`, `instructional`, `bricks`, `clay`, `anime`, `kawaii`, `scientific`
Orientations: `landscape`, `portrait`, `square`

### Mind Map

```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="mind_map",
  title="[topic, in the resolved domain language]",
  language=<resolved domain language>,
  confirm=true
)
```

### Flashcards

```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="flashcards",
  difficulty="medium",
  language=<resolved domain language>,
  confirm=true
)
```

Difficulty: `easy`, `medium`, `hard`

## Polling

After creating all artifacts, poll status:

```
mcp__notebooklm-mcp__studio_status(notebook_id=<id>)
```

Poll every 30 seconds. Audio typically takes 2-4 minutes. Infographics take 1-2 minutes. Mind maps and flashcards are usually instant.

### Study Guide (domain-adapted brief)

The `focus_prompt` MUST match the resolved domain's `## Output Settings` → NotebookLM
artifact focus line. Do not always send the implementation-focused brief — that framing
only fits `tech`.

```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="report",
  report_type="Study Guide",
  language=<resolved domain language>,
  focus_prompt=<domain-specific brief, see below>,
  confirm=true
)
```

| Domain | `focus_prompt` |
|--------|-----------------|
| `tech` | "Create an implementation-focused study guide for [topic]. Include: 1) Key concepts summary, 2) Step-by-step implementation guide with code examples, 3) Action items checklist — what to build first, what to configure, what to test, 4) Common pitfalls and how to avoid them, 5) Recommended next steps after initial implementation." |
| `philosophy` | "Create a study guide analyzing [topic]. Include: 1) Summary of the central argument(s), 2) Key positions and their proponents, 3) Major objections and the replies made to them, 4) How this debate connects to the broader literature, 5) Suggested further reading." |
| `judaism` | "Create a study guide for [topic]. Include: 1) Summary of the sugya/text structure, 2) Positions of the major commentators, 3) Key points of dispute among them, 4) Practical halakhic upshot where relevant, 5) Suggested related texts for further study." |

Report types: `Briefing Doc`, `Study Guide`, `Blog Post`

## Additional Artifact Types (optional)

Users can request these by modifying the skill or asking explicitly:

| Type | Parameter | Key Options |
|------|-----------|-------------|
| Video | `video` | `explainer`, `brief`, `cinematic` |
| Slides | `slide_deck` | `detailed_deck`, `presenter_slides` |
| Report | `report` | `Briefing Doc`, `Study Guide`, `Blog Post` |
| Quiz | `quiz` | `question_count`, `difficulty` |
| Data Table | `data_table` | `description` (required) |
