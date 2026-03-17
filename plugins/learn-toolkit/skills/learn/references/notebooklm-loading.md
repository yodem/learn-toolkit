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
current_count = read /tmp/learn-workflow-state.json -> notebooks[-1].source_count

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
  "local_path": "/tmp/learn-<topic-slug>/"
}
```

Update the state file after EVERY notebook creation and source addition. Read it before any operation.
