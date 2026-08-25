# learn-toolkit → single `/learn` skill with domain routing

**Date:** 2026-08-25
**Status:** approved design, not yet implemented
**Author:** Yotam Fromm (design via Claude, brainstorming skill, architectural path)
**Repo:** `github.com/yodem/learn-toolkit` — working tree `~/dev/learn-toolkit`

---

## 1. Goal

Collapse the three-skill `learn-toolkit` plugin into **one** skill, `/learn <subject>`, that
routes research strategy and tool selection by subject domain. Ship three domains: `tech`,
`philosophy`, `judaism`. Make NotebookLM optional rather than required, and end each run by
offering to file findings into a per-topic CandleKeep field-research book.

Non-goal: adding domains beyond the three, changing the `playground:playground` plugin, or
building any Notion integration (see §11).

## 2. Decisions locked during brainstorming

| # | Decision | Rationale |
|---|---|---|
| D1 | One skill: `/learn <subject>`, with `--domain`, `--language`, `--no-notebook` | User requirement. Signature stays as stated. |
| D2 | Domain is **inferred** from the subject; `--domain` overrides | Keeps the `/learn <subject>` signature; announce the inferred domain before spending calls. |
| D3 | Community layer = **Exa + Tavily**, no Agent Reach | Exa reaches LinkedIn natively via `linkedin_search_exa`, and Reddit/HN/StackOverflow are publicly indexed and reachable through Tavily domain filtering. Agent Reach's cookie-export and burner-account cost buys nothing the plugin needs. Rejected as a dependency. |
| D4 | Shared workflow spine in `SKILL.md`; per-domain detail in `references/domains/*.md` | Matches the plugin's existing progressive-disclosure pattern. Avoids an 800-line skill file. |
| D5 | CandleKeep is scanned on **every** domain, unconditionally | User requirement. The `--no-ck-read` flag is deleted. |
| D6 | Phase 1 fans out **one subagent per search backend**, dispatched in one message | User requirement. Also the token win — see §7. |
| D7 | Default language: `tech` → **English**; `philosophy`, `judaism` → **Hebrew** | User requirement. `--language <code>` overrides. |
| D8 | NotebookLM optional; CandleKeep write is a **prompt**, not a flag | User requirement. Replaces `--ck-write`. |

## 3. Command surface

```
/learn <subject> [--domain tech|philosophy|judaism] [--language <code>] [--no-notebook]
```

The local `visualize` and `playground` skills are **deleted**. Nothing is lost:

- The ASCII diagram already renders inline in the current Phase 6a.
- Phase 6b already delegates to `playground:playground`, which is a **separate installed
  plugin**, not the local skill. It stays available and is invoked unchanged.

The playground step becomes domain-conditional: on for `tech`, off for `philosophy` and
`judaism`, where a parameter-toggle explorer does not fit the material.

## 4. Domain profiles

| | **tech** | **philosophy** | **judaism** |
|---|---|---|---|
| Primary sources | official docs, GitHub | CandleKeep author books, papers | Sefaria MCP |
| Web research | Tavily advanced + Exa `get_code_context_exa` | Tavily + Exa semantic | Tavily secondary only |
| Community layer | Tavily `include_domains: reddit.com, news.ycombinator.com, stackoverflow.com` + Exa `category: personal site` + `linkedin_search_exa` | Exa `category: publication` + `personal site` | off |
| CandleKeep | project shelf + full library scan | library scan, humanities author books | Judaica books |
| Playground | yes | no | no |
| Default language | **English** | Hebrew | Hebrew |

**Judaism sources:** `mcp__claude_ai_Sefaria__text_search`, `english_semantic_search`,
`get_topic_details`, `get_links_between_texts`.

**Wiki boundary — explicit.** Using Sefaria MCP *text* tools for personal study is fine; the
hard rule governs *where notes get filed*, not which tools get called. Everything `/learn`
produces goes to `~/dev/learn-research/` and, on acceptance, to CandleKeep. **Nothing from
this skill ever writes to `sefaria-wiki`.**

## 5. Domain inference

Classify the subject into exactly one of the three domains, then **announce it before
spending any research call**:

```
Domain: judaism (inferred) — Sefaria MCP + CandleKeep Judaica. Override with --domain.
```

`--domain` short-circuits inference entirely. Ambiguous subjects (e.g. "Maimonides on
causation") resolve to the domain whose *primary sources* would answer better — here
`judaism`, because Sefaria holds the primary text. The announcement is what makes a
misroute cheap to correct.

## 6. Workflow phases

| Phase | Name | Notes |
|---|---|---|
| 0 | Backend discovery | Probe Tavily (CLI + MCP), Exa, Sefaria, CandleKeep, NotebookLM. Report a one-line matrix. **Auth probe = `tvly auth`, not `tvly --status`** — see §8. |
| 0.5 | Domain resolution | Infer or take `--domain`; load `references/domains/<domain>.md`; announce. |
| 1 | **Parallel research fan-out** | One subagent per backend, single dispatch. See §7. |
| 2 | Merge + synthesize | Dedupe by URL, rank by domain source priority, write ~500-word synthesis. |
| 2.5 | Save local files | `~/dev/learn-research/learn-<slug>/` — always runs. |
| 3 | NotebookLM load | **Phases 3, 4 and 5 all skip together** if NotebookLM is absent or `--no-notebook` is set — they are one unit, not three independent gates. |
| 4 | Artifacts | Podcast, infographic, mind map, flashcards, study guide, in the domain language. |
| 5 | Poll + report | Summary tables. Omit the NotebookLM tables entirely when 3–5 skipped. |
| 6 | Companion visuals | 6a ASCII always; 6b playground **tech only**. |
| 7 | **CandleKeep field-research offer** | See §9. |

**Gate rule:** the only hard stop is Phase 0 finding *zero* search backends. Everything
else degrades with a notice and continues.

## 7. Subagent contract (Phase 1)

All subagents for a domain are dispatched **in a single message** so they run concurrently.

Subagents per domain:

- **tech** — ① Tavily official-docs ② Exa semantic + `get_code_context_exa` ③ community
  (Tavily domain-filtered + Exa `personal site` + `linkedin_search_exa`) ④ CandleKeep
- **philosophy** — ① Tavily general ② Exa `publication` + `personal site` ③ CandleKeep
- **judaism** — ① Sefaria MCP ② CandleKeep Judaica ③ Tavily + Exa secondary

Each subagent receives: the subject, its domain profile, its backend's usage rules (§8), and
a strict return contract. **Each returns findings, never raw pages:**

```json
[{"url": "...", "title": "...", "kind": "official_docs|tutorial|discussion|library|primary_text",
  "why_it_matters": "one sentence", "key_claims": ["...", "..."]}]
```

This is the point of the fan-out: ~10k tokens of search output stays inside the subagent and
~500 tokens of digest returns. Per the global convention, spawn counts stay low — 3–4 agents,
one per backend, no reviewers or verifiers.

**Token economy is per-backend, and the two backends need different levers.**

- *Tavily subagents* — MUST use the `tavily-dynamic-search` pattern (skill installed
  2026-08-25): pipe `tvly --json` through Python so raw HTML never enters context, a
  documented ~100–200x reduction. Never call bare `tvly`. This composes with the fan-out
  rather than replacing it: subagents give parallelism, dynamic-search gives token economy
  inside each.
- *Exa subagents* — there is no pipe to interpose; Exa MCP results arrive through the tool
  result directly. The equivalent lever is the §8 content mode: **`highlights` for triage of
  all results, then `text` with an explicit `maxCharacters` for only the 3–5 keepers.** An
  Exa subagent that requests full text for every result defeats the fan-out's purpose.

## 8. Tool usage rules — corrections against vendor docs

Verified 2026-08-25 against Tavily's search best-practices page and Exa's search
best-practices page plus the live MCP tool schemas.

### Tavily

| Current skill does | Docs say | Fix |
|---|---|---|
| `--max-results 10` | Default 5; "setting too high may return lower-quality results" | 5–8 |
| Appends `"tutorial guide 2025 2026"` to the query for recency | `time_range` (`day`/`week`/`month`/`year`), `topic: "news"` | Use the parameter, never the query text |
| `include_raw_content=true` on search **and** a separate extract | Two-step: search for snippets → Extract for content | Drop raw content from search; `include_raw_content: "markdown"` on extract only |
| 4-site `include_domains` list | "Keep domain lists short and relevant" | ≤3 sites |
| — | `auto_parameters` can silently set advanced depth (2 credits) | Set `search_depth` explicitly |
| — | Queries <1500 chars; split multi-topic into focused queries | One focused query per subagent |

**Auth detection — use `tvly auth`, not `tvly --status`.** Verified on 0.1.6: `tvly auth`
prints `> Authenticated via TAVILY_API_KEY environment variable` with a masked key and exits 0.
`tvly --status` prints a two-part banner (version, then auth) — the current SKILL.md's check
pipes it through `head -2`, which truncates the auth line and silently reports "not
authenticated". Presence check stays `tvly --version`; auth check becomes `tvly auth`.

### Exa

| Current skill does | Docs say | Fix |
|---|---|---|
| `query="$ARGUMENTS documentation"` (keyword style) | **Describe the ideal page, not keywords** — "blog post about embeddings and vector search", not "embeddings vector search" | Rewrite every Exa query as a natural-language page description |
| — | `type: "auto"` recommended default | Set explicitly |
| — | `highlights` cuts tokens ~10x for lookups; `text` + `maxCharacters` for deep reads | Highlights for triage, text for the 3–5 keepers |
| `crawling_exa` with defaults | Defaults to **3000 chars/page** | Set `maxCharacters` explicitly for deep dives |
| Uses `deep_researcher_start` | **Deprecated** | `deep_search_exa` |
| — | `category` filter: `publication`, `github`, `pdf`, `news`, `personal site`, `people`, `company` | Map to domain profiles (§4) |
| — | `personal site` is Exa's documented unique strength | Use it as the community-layer backbone |

## 9. CandleKeep field-research write

Triggered as a **prompt** at Phase 7, replacing the `--ck-write` flag.

**Existence check must be format-tolerant.** Only one precedent book exists
(`Claude Code Orchestration in Practice — Field Research 2026-08`), which is n=1, not a
convention. Match case-insensitively on `field research` **plus** topic tokens over
`ck items list --json`, so an existing book is found whatever its shape. Otherwise
"create if not exists" silently duplicates.

- **Create** as `Field Research — <Topic>`, and set `ck items enrich --add-prompt`
  and `--sample-question` **at creation** — without these the book joins the ~100 library
  books that are not agent-queryable.
- **Append** with `ck items append <book-id>` (not `ck ms <id>`).

**Hard-won CandleKeep constraints that the writer must respect:**

1. Pagination splits on `#` H1 — **one H1 per intended page**, and it ignores code fences.
2. CandleKeep injects a blank line above any `#` inside a fence — **escape `#` at write time**.
3. A book is capped at **1,000,000 bytes** (413 on overflow).
4. **Verify via `ck items read <id>:<n>`, never the command log** — a `BadRecordMac` TLS error
   can hit the *response* while the write succeeded.

## 10. Tooling upgrade — DONE 2026-08-25

Completed before implementation, on both machines. Both now at parity.

| Item | Mac before | Server before | After |
|---|---|---|---|
| `tavily-cli` (`tvly`) | 0.1.0 | 0.1.4 | **0.1.6** |
| tavily-ai skills | 7 (content current) | **0** | **8** |
| Exa MCP `tools=` | stale | stale | corrected |
| `ck` | 0.7.53 | 0.7.53 | unchanged |

- The 7 pre-existing Mac skills were **byte-identical** to the repo head; only
  `tavily-dynamic-search` was genuinely new. The server had none and now has all 8.
- Exa `tools=` filter, both machines:
  - **removed** `crawling_exa` (alias — *verified*: `src/tools/webFetch.ts:40` registers
    `toolName || "web_fetch_exa"` and line 94 sends `integrationHeaders("crawling-mcp", …)`,
    i.e. one tool, two names; no capability lost),
    `deep_researcher_start`, `deep_researcher_check` (deprecated)
  - **added** `web_fetch_exa` (referenced by other Exa tools' own descriptions),
    `linkedin_search_exa`, `deep_search_exa`
- Backups: `~/.claude.json.bak-20260825-132601` (Mac), timestamped equivalent on server,
  `~/.claude/skills-backup-20260825-132601.tgz`.
- `tvly` auth verified on both: `Authenticated via TAVILY_API_KEY` (env var).

**The plugin's own `.mcp.json` still carries the stale Exa tools list** — it is fixed as part
of implementation, not in the pre-work above.

### Security finding — open, needs user action

The **Exa API key sits in plaintext** in `~/.claude.json` on both machines, and was echoed
into a session transcript during discovery on 2026-08-25. **It should be rotated** at
dashboard.exa.ai. This is the third logged recurrence of this pattern (wiki entries
2026-07-30, 2026-08-09). Tavily is already on the correct pattern (`TAVILY_API_KEY` env var);
Exa should move to the same.

## 11. File change inventory

**Delete**
- `skills/visualize/SKILL.md`
- `skills/playground/SKILL.md`

**Rewrite**
- `skills/learn/SKILL.md` — domain-agnostic spine, profile table, fan-out, corrected tool rules
- `README.md` (433 lines) — documents a three-command surface
- `CLAUDE.md` — same
- `references/setup-guide.md` — same

**Create**
- `references/domains/tech.md`
- `references/domains/philosophy.md`
- `references/domains/judaism.md`

**Edit**
- `.mcp.json` — Exa `tools=` list (§10); drop deprecated entries
- `.claude-plugin/plugin.json` — version bump, description, `requiredEnvVars`
- `../.claude-plugin/marketplace.json` — **version mismatch: plugin says 1.5.2, marketplace
  says 1.5.1.** Bump both in the same commit or it recurs (standing finding).
- `hooks/validate-output.sh` — path filter still matches `/tmp/learn-*` though output moved to
  `~/dev/learn-research/learn-*/`. **Open since 2026-05-26.** Also a research-summary length
  check that is ~40x too permissive.
- `hooks/verify-artifacts.sh`, `hooks/hooks.json` — re-scope now that two skills are gone

**Fix while in there**
- `/tmp/learn-workflow-state.json` is **not topic-scoped** and collides across concurrent
  sessions. Domain modes make concurrency likelier → scope it to
  `/tmp/learn-workflow-state-<slug>.json`.
- Grep every `STOP workflow` occurrence. The NotebookLM row in Error Recovery contradicts the
  Phase 0 "degraded mode" instruction; this contradiction has survived multiple nightly
  reviews inside one long file. Remove the row.

## 12. Out of scope

- **Notion.** "maybe my notion tools as well" was hedged; the only concrete fit is the
  `add-ai-tool` skill's AI-Tools directory, which is tech-only and narrow. Deliberately not
  specced. Could later become an optional tech-domain side-effect.
- **Agent Reach.** Rejected as a dependency (D3). Not probed, not detected, not referenced.
- Domains beyond the three.

## 13. Risks

| Risk | Mitigation |
|---|---|
| Domain misroute on straddling subjects | Announce inferred domain before spending calls; `--domain` override |
| Workflow described in two places (spine + domain files) | Domain files carry *only* overrides, never restated phases |
| Subagent fan-out inflates spend | 3–4 agents max, one per backend; strict digest-only return contract |
| Marketplace refresh clobbers edits | Work in `~/dev/learn-toolkit`, push, then refresh the marketplace from origin |
| Exa/Tavily best practices drift again | §8 records the source pages; re-verify on major MCP version bumps |

## 14. Next step

Implementation plan via the `writing-plans` skill. No code written before that plan exists.
