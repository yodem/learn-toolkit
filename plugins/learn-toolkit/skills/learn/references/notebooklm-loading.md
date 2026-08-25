## Optional — skip conditions

NotebookLM is **optional**. Phases 3, 4 and 5 form one unit and skip **together** when
either is true:

- NotebookLM tools were not found in Phase 0
- `--no-notebook` was passed

When skipped, emit exactly one notice — `NotebookLM not available — skipping the notebook
package. Research, local files and the CandleKeep offer are unaffected.` — omit the notebook
and artifact tables from the final report, and continue to Phase 6.

**Never stop the workflow because NotebookLM is missing.**

# NotebookLM Loading Reference

## Notebook Creation Strategy

Create notebooks with clear naming that reflects content scope:

| Priority | Notebook Name | Contents |
|----------|---------------|----------|
| 1 | `[Topic] - Core Learning` | Official docs, tutorials, main articles, research summary |
| 2 (overflow) | `[Topic] - Deep Dive` | Code examples, comparisons, advanced content |
| 3 (overflow) | `[Topic] - Community` | Blog posts, discussions, alternatives |

## Source Addition

### URLs (bulk, non-blocking)

```
mcp__notebooklm-mcp__source_add(
  notebook_id=<id>,
  source_type="url",
  url=<url>,
  wait=false
)
```

Add URLs in rapid succession without waiting. NotebookLM processes them asynchronously.

### Research Summary (text, blocking)

```
mcp__notebooklm-mcp__source_add(
  notebook_id=<id>,
  source_type="text",
  title="Research Summary - [Topic]",
  text=<compiled summary>,
  wait=true
)
```

Wait for the summary to process before generating artifacts.

## Overflow Logic

```
current_count = read /tmp/learn-workflow-state-<topic-slug>.json -> notebooks[-1].source_count

if current_count >= 48:
  1. Create new notebook with next-tier name
  2. Update state file with new notebook ID
  3. Continue adding to new notebook

After all sources added:
  1. Wait 10 seconds for async processing
  2. Check studio_status to confirm sources are ready
```

## State File Schema

```json
{
  "topic": "string",
  "domain": "tech|philosophy|judaism",
  "notebooks": [
    {
      "id": "uuid",
      "name": "string",
      "url": "string",
      "source_count": 0
    }
  ],
  "total_sources": 0,
  "candlekeep": {
    "read_ids": [],
    "write_id": null
  },
  "local_path": "$HOME/dev/learn-research/learn-<topic-slug>/"
}
```

State file lives at `/tmp/learn-workflow-state-<topic-slug>.json` — topic-scoped, so
concurrent `/learn` runs on different subjects don't clobber each other's state. The
five keys `topic`, `domain`, `notebooks`, `total_sources`, `local_path` are all
required; the workflow's validation hook rejects the file if any is missing.

Update the state file after EVERY notebook creation and source addition. Read it before any operation.
