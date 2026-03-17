# Artifact Generation Reference

## Tool Call Signatures

### Audio Podcast

```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="audio",
  audio_format="deep_dive",
  audio_length="default",
  language="he",
  focus_prompt="Explain the core concepts of [topic], how they relate to each other, and practical applications. Cover both fundamentals and advanced patterns.",
  confirm=true
)
```

Audio formats: `deep_dive` (default), `brief`, `critique`, `debate`
Audio lengths: `short`, `default`, `long`

### Infographic

```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="infographic",
  orientation="portrait",
  detail_level="detailed",
  infographic_style="bento_grid",
  language="he",
  focus_prompt="Key concepts, architecture, and relationships in [topic]. Include comparison of approaches and decision criteria.",
  confirm=true
)
```

Styles: `auto_select`, `sketch_note`, `professional`, `bento_grid`, `editorial`, `instructional`, `bricks`, `clay`, `anime`, `kawaii`, `scientific`
Orientations: `landscape`, `portrait`, `square`

### Mind Map

```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="mind_map",
  title="[topic in Hebrew]",
  language="he",
  confirm=true
)
```

### Flashcards

```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="flashcards",
  difficulty="medium",
  language="he",
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

### Study Guide (Action Items & Implementation)

```
mcp__notebooklm-mcp__studio_create(
  notebook_id=<id>,
  artifact_type="report",
  report_type="Study Guide",
  language="he",
  focus_prompt="Create an implementation-focused study guide for [topic]. Include: 1) Key concepts summary, 2) Step-by-step implementation guide with code examples, 3) Action items checklist — what to build first, what to configure, what to test, 4) Common pitfalls and how to avoid them, 5) Recommended next steps after initial implementation.",
  confirm=true
)
```

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
