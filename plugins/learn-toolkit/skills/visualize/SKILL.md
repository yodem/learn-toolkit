---
name: visualize
description: "ASCII visualizer: generate flowcharts, architecture diagrams, sequence diagrams, and decision trees directly in the terminal using ASCII/Unicode box-drawing characters. Use when the user wants to visualize a concept, architecture, flow, or relationship without leaving the CLI. Triggers: /learn-toolkit:visualize, 'draw me', 'diagram', 'flowchart', 'ascii art', 'visualize', 'show me the architecture', 'map this out'. Do NOT use for complex multi-page visualizations (use /learn-toolkit:playground instead)."
argument-hint: "<concept or architecture to visualize>"
disable-model-invocation: true
metadata:
  author: Yotam Fromm
  version: 1.0.0
  category: visualization
  tags: [ascii, diagram, flowchart, terminal, cli]
---

# ASCII Visualizer

## Important

CRITICAL: Output diagrams directly to the terminal using ASCII/Unicode box-drawing characters. The user does NOT want to leave the CLI. Keep it fast, keep it in-terminal.

- Use Unicode box-drawing characters (─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼ ═ ║ ╔ ╗ ╚ ╝) for clean visuals
- Arrows: → ← ↑ ↓ ➜ ▶ ◀ ▲ ▼
- Boxes: ┌──────┐ for components, ╔══════╗ for emphasis
- Keep width under 100 characters for terminal readability
- Use color via ANSI escape codes ONLY if the user asks for it

## Instructions

### Step 1: Understand the request

Parse `$ARGUMENTS` to determine the diagram type:

| Input pattern | Diagram type |
|---------------|-------------|
| "flow", "process", "steps" | Flowchart |
| "architecture", "system", "components" | Architecture diagram |
| "sequence", "interaction", "request" | Sequence diagram |
| "decision", "choose", "if/then" | Decision tree |
| "hierarchy", "org", "tree" | Tree diagram |
| "compare", "vs", "options" | Comparison table |
| "timeline", "phases", "roadmap" | Timeline |
| Other | Best-fit based on content |

### Step 2: Research if needed

If the topic requires understanding (e.g., "visualize Kafka architecture"):
- Use Grep/Glob to check the local codebase for relevant patterns
- Use WebSearch for well-known architectures if needed
- Keep research minimal — this is the fast path, not the deep-dive

### Step 3: Generate the diagram

Output the diagram directly as text. No files, no HTML, no images.

**Verification gate:** The diagram must render correctly in a monospace terminal. Check that all box-drawing characters align vertically and horizontally.

## Examples

### Example 1: Simple flowchart

User says: `/learn-toolkit:visualize user login flow`

Output:
```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  User opens  │────▶│  Enter creds  │────▶│  Validate   │
│  login page  │     │              │     │  credentials │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                │
                                    ┌───────────┴───────────┐
                                    │                       │
                               ┌────▼────┐            ┌────▼────┐
                               │  Valid   │            │ Invalid  │
                               │         │            │         │
                               └────┬────┘            └────┬────┘
                                    │                       │
                               ┌────▼────┐            ┌────▼────┐
                               │ Create  │            │  Show   │
                               │ session │            │  error  │
                               └─────────┘            └─────────┘
```

### Example 2: Architecture diagram

User says: `/learn-toolkit:visualize microservices with API gateway`

Output:
```
                        ┌──────────────────┐
                        │     Client       │
                        └────────┬─────────┘
                                 │
                        ╔════════▼═════════╗
                        ║   API Gateway    ║
                        ║  (rate limiting, ║
                        ║   auth, routing) ║
                        ╚═══╤═══════╤══════╝
                    ┌───────┘       └────────┐
              ┌─────▼──────┐          ┌──────▼─────┐
              │  User Svc  │          │ Order Svc  │
              │  :3001     │          │  :3002     │
              └─────┬──────┘          └──────┬─────┘
                    │                        │
              ┌─────▼──────┐          ┌──────▼─────┐
              │  Users DB  │          │ Orders DB  │
              │ PostgreSQL │          │  MongoDB   │
              └────────────┘          └────────────┘
```

### Example 3: Comparison table

User says: `/learn-toolkit:visualize REST vs GraphQL vs gRPC`

Output:
```
┌──────────────┬───────────┬────────────┬───────────┐
│   Feature    │   REST    │  GraphQL   │   gRPC    │
├──────────────┼───────────┼────────────┼───────────┤
│ Protocol     │ HTTP/1.1  │ HTTP/1.1   │ HTTP/2    │
│ Format       │ JSON      │ JSON       │ Protobuf  │
│ Typing       │ Optional  │ Strong     │ Strong    │
│ Streaming    │ No        │ Subscript. │ Yes       │
│ Browser      │ Native    │ Native     │ gRPC-Web  │
│ Best for     │ CRUD APIs │ Flexible   │ Internal  │
│              │           │ queries    │ services  │
└──────────────┴───────────┴────────────┴───────────┘
```

## Error Recovery

| Error | Cause | Action |
|-------|-------|--------|
| No arguments provided | User typed just `/learn-toolkit:visualize` | Ask: "What would you like me to visualize? (e.g., 'user auth flow', 'microservices architecture')" |
| Topic too broad | e.g., "visualize everything" | Ask user to narrow scope: "Which aspect? Architecture, data flow, or deployment?" |
| Diagram too wide | Exceeds 100 chars | Break into multiple connected diagrams or simplify labels |
