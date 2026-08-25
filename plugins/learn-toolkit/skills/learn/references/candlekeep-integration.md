# CandleKeep Integration Reference

## Overview

CandleKeep provides bidirectional integration with the `/learn` workflow:
- **Read** (Phase 1): the `library` subagent, dispatched as part of every domain's
  Subagent Roster in Phase 1's fan-out, scans the library for existing knowledge on the
  topic and returns a digest alongside every other backend's — runs on **every domain,
  unconditionally**. There is no skip flag; the read-skipping flag from the old
  three-skill design is gone entirely.
- **Write** (Phase 7): offer, interactively, to append the session's findings to a
  per-topic field-research book. There is no write-enabling flag; the interactive offer
  replaces it outright.

CandleKeep is **never required** — the workflow proceeds normally if `ck` is not
installed. Every CandleKeep failure is non-fatal: warn and continue (see Error Recovery
in `SKILL.md`).

## Six hard-won constraints

These were learned in production, each the hard way. All six bind everything below.

1. **Pagination splits on `#` H1 and ignores code fences.** CandleKeep's pager only
   recognizes `#` headings at the top level to cut pages — it does not track whether a
   `#` is inside a fenced code block. Author content with exactly one H1 per intended
   page, or pages will fragment incorrectly.
2. **A `#` inside a fence gets a blank line injected above it on write.** CandleKeep
   treats any line starting with `#` as a heading candidate during ingestion, even
   inside a ` ``` ` fence, and inserts a blank line before it — which can break the
   fence's formatting. Escape `#` characters inside code fences at write time (e.g.
   `\#`) so they are not mistaken for headings.
3. **A book is capped at 1,000,000 bytes.** Overflow returns HTTP 413. Keep entries and
   compiled content under this ceiling; split oversized content across multiple items
   rather than one write that exceeds it.
4. **Appends use `ck items append <book-id>`, not `ck ms <id>`.** `ck ms` is a different,
   unrelated command surface — using it against a book id does not append content.
5. **Verify a write with `ck items read <id>:<n>`, never by reading the command's log
   output.** A `BadRecordMac` TLS error can hit the response stream while the write
   itself succeeded server-side — the log will show a failure that isn't real, and a
   silent success in the log doesn't prove the bytes landed either. The only valid
   verification is reading the item back.
6. **`ck items enrich --add-prompt` and `--sample-question` must be set at creation.**
   If a book is created without them and enriched later as an afterthought, it may not
   become agent-queryable. Always run `ck items enrich` immediately after `ck items
   create`, before any append.

## CLI Detection (Phase 0)

```bash
ck --version 2>/dev/null && echo "CK_CLI=true" || echo "CK_CLI=false"
```

Set `HAS_CANDLEKEEP = true/false`. Missing is not an error — just skip CandleKeep steps
silently and continue the workflow.

## Library Scan (Phase 1, `library` subagent)

**Condition:** `HAS_CANDLEKEEP = true`. That's it — the `library` subagent is part of
every domain's Subagent Roster, so this runs on every domain, unconditionally, as one
of the parallel subagents dispatched in Phase 1's fan-out (not a standalone Phase 0.5
step). There is no read-skip flag.

### Step 1: List items and match by topic

```bash
ck items list --json
```

Parse the JSON output. Match items whose title or description contains keywords from
the topic. Select up to 3 most relevant items.

### Step 2: Read matching items

For each matching item (max 3):

```bash
ck items toc <item-id>
```

Review the table of contents, identify relevant pages/sections.

```bash
ck items read "<item-id>:<relevant-pages>"
```

Extract content snippets (500-1000 words per item).

### Step 3: Return the digest

Like every other Phase 1 subagent, the `library` subagent returns the shared digest
contract (`kind: "library"`) rather than a standalone report — it does not print
"Found X relevant documents" to the user directly. The parent context sees the findings
folded into Phase 2's merge alongside every other backend's digests:

```json
[{"url": "item-id", "title": "Document Title", "kind": "library",
  "why_it_matters": "one sentence", "key_claims": ["...", "..."]}]
```

If nothing matches, the subagent returns an empty digest array and Phase 2's merge
simply has nothing to fold in from CandleKeep for this run.

## Source Hierarchy (Phase 2)

Where CandleKeep sources rank relative to other backends (official docs, tutorials,
blog posts, code repos) is **per-domain**, not fixed here — each `domains/<domain>.md`
defines its own source hierarchy. List CandleKeep sources under a "Library Sources"
heading in the research summary regardless of where the domain ranks them.

## NotebookLM Loading (Phase 3)

Add CandleKeep content as text sources to NotebookLM **before** URLs, after notebook
creation:

```
mcp__notebooklm-mcp__source_add(
  notebook_id=<id>,
  source_type="text",
  title="Library: [Item Title]",
  text=<content_snippet>,
  wait=false
)
```

Max 3 items = negligible impact on the 50-source limit.

## Local Files

Always save research to `$HOME/dev/learn-research/learn-<topic-slug>/`. **Never
`/tmp`** — `/tmp` is not durable across reboots and is not the canonical research output
location for this workflow.

```
$HOME/dev/learn-research/learn-<topic-slug>/
  README.md              — index with TOC, metadata, date
  research-summary.md    — 500-word synthesis
  sources/
    01-official-docs.md
    02-library.md         — CandleKeep sources (if any)
    03-tutorials.md
    04-articles.md
```

Each source file contains:
- URL or source identifier
- Title
- Backend that provided it (Tavily, Exa, CandleKeep)
- Content snippet

The `topic-slug` is the topic lowercased, spaces replaced with hyphens, special chars
removed. Example: `"Kafka Event Streaming"` → `kafka-event-streaming`.

## Field Research Offer (Phase 7)

**Condition:** `HAS_CANDLEKEEP = true`. At the end of the run, offer — interactively —
to append this session's findings to a per-topic field-research book. This replaces the
old write-enabling flag entirely; there is no flag to check, only a question to ask the
user.

**Existence check must be format-tolerant.** Only one precedent book exists
(`Claude Code Orchestration in Practice — Field Research 2026-08`); that is n=1, not a
convention. Match case-insensitively on `field research` **plus** topic tokens, so an
existing book is found whatever shape its title takes. A strict match would silently
create duplicates.

```bash
ck items list --json --no-session | python3 -c "
import json,sys,re
topic_tokens = [t for t in re.split(r'\W+', '<TOPIC>'.lower()) if len(t) > 3]
items = json.load(sys.stdin)
items = items if isinstance(items, list) else items.get('items', [])
for i in items:
    t = (i.get('title') or '').lower()
    if 'field research' in t and any(tok in t for tok in topic_tokens):
        print(i['id'], '|', i['title'])
"
```

If nothing matches, create the book — enriching it **at creation**, per constraint 6
above:

```bash
ck items create "Field Research — <Topic>" \
  --description "Field research on <Topic>. Started by learn-toolkit on <YYYY-MM-DD>." \
  --no-session
ck items enrich <id> \
  --add-prompt "Consult this book for field-research findings on <Topic>, including sources consulted and open questions." \
  --sample-question "What did the field research on <Topic> conclude?" \
  --no-session
```

Append the entry, then verify by reading back — never by trusting the append command's
own log output (constraint 5):

```bash
ck items append <book-id> --file <path-to-entry.md> --no-session
ck items read "<book-id>:<n>" --no-session   # the ONLY valid verification
```

If the append or the readback fails, report it plainly and leave the local entry file
in place under `Local Files` — do not silently drop the finding.

## Entry Format

Author one `#` H1 per intended page (constraint 1) — CandleKeep's pager splits on `#`
and does not understand fences, so an entry with multiple top-level `#` headings will
split into multiple pages unintentionally. Escape any `#` that appears inside a code
fence (constraint 2), and keep the entry well under the 1,000,000-byte book cap
(constraint 3).

The book (`Field Research — <Topic>`) is per-topic; each append is one per-session
entry inside it, and the book accumulates entries across many runs. Make the H1 the
session's specific subject, not the topic or book title again, so `ck items toc
<book-id>` lets a reader tell one page from another at a glance. Each entry is dated
and carries subject, domain, sources consulted, key findings, and open questions:

```markdown
# <Session Subject> (<YYYY-MM-DD>)

**Subject:** <what this specific session investigated>
**Domain:** <domain>
**Sources consulted:** <list>

## Key Findings

<findings>

## Open Questions

<open questions, if any>
```

## Error Recovery

See the Error Recovery table in `SKILL.md` for all CandleKeep error handling. The key
principle: every CandleKeep failure is non-fatal — warn and continue.
