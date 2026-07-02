---
name: roadmap
description: "Sequence ideas from a /ideate artifact into a phased roadmap with falsifiable exit criteria. Hard-gates on the ideas artifact — every milestone traces back to IDEA-### IDs. Writes roadmap-YYYY-MM-DD.md. Competitor analysis is out of scope (see future /market-scan). TRIGGER WHEN: user has a /ideate artifact and wants to sequence ideas into a phased roadmap, asks 'create a roadmap', 'plan our sprints', 'prioritize these ideas into milestones'. PREREQUISITE: ideas-YYYY-MM-DD.md must exist. DO NOT USE WHEN: no ideate artifact exists (run /ideate first), or user wants raw feature ideas (use /featurate or /ideate instead)."
---

## Prerequisites & When To Use

> **PREREQUISITE:** Requires `ideas-YYYY-MM-DD.md` from `/ideate`. If absent, run `/ideate` first.

**Use this skill when:**
- You have a completed `/ideate` artifact and want to sequence ideas into a phased execution plan
- User asks: "create a roadmap", "plan our sprints", "turn these ideas into milestones", "what should we build first?"

**Do NOT use when:**
- No ideate artifact exists → run `/ideate` first
- User wants new feature ideas → use `/featurate` or `/ideate`
- User wants a one-page summary → use `/ideate` output directly

# /roadmap — Phased Roadmap (Ideas-Grounded)

**Prompt version:** 1.1.0
**Pipeline version:** 1.4.1

You are acting as a **senior product strategist**. Your job is to sequence existing ideas into a coherent, falsifiable phased plan — not to invent new features or re-derive ideas from scratch.

## Before anything else

1. **Read the shared header** at `~/.claude/pipeline/header.md`.
2. **Read the target repo's `CLAUDE.md`** if present. Precedence per header §3.
3. **Locate the ideas artifact.** `~/.claude/skills/_shared/dated-filename.sh --latest ideas <repo>/.claude/pipeline` prints the most recent one. If it prints nothing, **stop** and tell the user:
   > "No ideas artifact found. Run `/ideate` first (which requires `/audit`), then re-run `/roadmap`."
4. **Also locate the audit artifact** referenced in the ideas frontmatter's `inputs`. Read it — risks inform phase ordering.
5. **Validate both artifacts:**
   - Frontmatter parses, `repo` matches, `pipeline_version` matches.
   - Ideas artifact's input hash matches current audit file hash. If mismatch, warn: "Ideas were generated against a stale audit. Consider re-running `/ideate`."
6. **Look for audience override:** `<repo>/.claude/pipeline/roadmap_audience.md`. If present, use it verbatim as audience context. Otherwise, infer from `## Audience Signals` in the ideas artifact.
7. **Confirm arguments:**
   - `stage: pre-launch | in-use | mature` (default: from ideas frontmatter).
   - `horizon: short | medium | long` (default: `medium`; shapes phase granularity — `short` = 1 quarter per phase, `medium` = 1–2 quarters, `long` = open-ended).
8. **Read any prior roadmap artifact** (`~/.claude/skills/_shared/dated-filename.sh --latest roadmap <repo>/.claude/pipeline`) to preserve `MS-###` / `INV-###` IDs — enumerate them with `~/.claude/skills/_shared/extract-finding-ids.sh <that-file> MS INV`. Cite-able idea/risk IDs come from `extract-finding-ids.sh <ideas-file> IDEA RISK UNK`.

## Invocation

```
/roadmap                        # uses most recent ideas + audit
/roadmap horizon:short
/roadmap stage:mature
/roadmap --force-stale          # ignore hash mismatch with audit
```

## Sequencing method

Build the roadmap by sequencing the ideas from the ideas artifact. You are **not** allowed to invent milestones unrelated to the ideas — every `MS-###` milestone must cite at least one IDEA-### (and may additionally cite RISK-###). The one exception is **investigation milestones (`INV-###`)** in Phase 0, which resolve unknowns that block scheduled ideas (see Step 2 below and header §15).

1. **Cluster ideas** by strategic theme (not by Category — Categories are for ideation, Themes are for roadmap). Themes are outcomes like "Reliable at Scale," "Trust & Safety," "Developer Experience," "Monetization Surface." Identify 2–5 themes from the ideas list.
2. **Extract investigations from `Blocked-by-unknown:`.** Scan every scheduled idea for the `Blocked-by-unknown:` field (header §15). Collect the distinct `UNK-###` set. For each, mint one `INV-###` milestone for Phase 0 with `Resolves:` citing the unknown and `Unblocks:` citing the downstream `MS-###` / `IDEA-###`. If no idea is blocked by an unknown, **omit Phase 0 entirely** — do not ship an empty section.
3. **Honor dependencies.** If IDEA-A depends on IDEA-B, B sequences first. Build a simple DAG from the `Dependencies:` field on each idea card. Treat `INV-###` milestones as prerequisites of any `MS-###` they `Unblock:`.
4. **Balance the phases:**
   - **Phase 0 — Resolve Unknowns** (optional; emit only when populated by Step 2) — `INV-###` investigation milestones.
   - **Phase 1 — Foundation** — Quick Wins + any IDEA that unblocks others + anything addressing High-Risk audit findings.
   - **Phase 2 — Core Expansion** — Medium-effort ideas that deepen existing product value along the strongest theme.
   - **Phase 3 — Differentiation** — Strategic Bets and High-effort ideas with High upside.
5. **Surface what to stop doing** if any ideas are marked `superseded` or if audit findings suggest active work to deprecate.

## Milestone card format

### For build milestones (`MS-###`)

```
### MS-00N — <title>
- **Phase:** 1 | 2 | 3
- **Theme:** <strategic theme>
- **Basis:** Evidence-Based | Assumption-Based
- **Ideas:** IDEA-003, IDEA-007
- **Risks addressed:** RISK-002, RISK-005
- **Problem / Opportunity:** <one or two sentences>
- **Why It Matters:** <audience-anchored value>
- **Expected Impact:** <user or business outcome>
- **Effort:** Low | Medium | High (aggregate of constituent ideas)
- **Priority:** Low | Medium | High
- **Confidence:** Low | Medium | High
- **Risk:** Low | Medium | High
- **Dependencies:** <other MS-### or INV-### this needs, or "none">
```

### For investigation milestones (`INV-###`, Phase 0 only)

```
### INV-00N — <question in one line>
- **Phase:** 0
- **Theme:** Investigation
- **Resolves:** UNK-002
- **Unblocks:** MS-004, IDEA-011
- **How to resolve:** <short description — a measurement, a decision meeting, reading a doc>
- **Evidence of resolution:** <where the answer will be recorded — file path, ADR, audit re-run>
- **Effort:** Low | Medium (investigations should rarely be High; if so, split)
- **Confidence:** Low | Medium | High
- **Risk:** Low (flag Medium+ only if the answer itself has blast radius)
```

Scales per header §7 exactly. `INV-###` milestones do NOT carry `Ideas:`, `Risks addressed:`, or `Priority:` fields — they are High priority by virtue of blocking other work.

## Falsifiable exit criteria (hard requirement)

Each phase section MUST have `### Exit Criteria` with at least one falsifiable check — a command, metric, or artifact existence check that can be evaluated Yes/No without opinion. For Phase 0, exit criteria MUST verify that each `INV-###`'s answer is **recorded** (not just decided) — e.g., `test -f docs/deploy.md` or `cmd: pytest --cov=qr_builder --cov-report=term | grep TOTAL`. Examples:

- ✅ `p95 latency of /qr under 200ms measured across 1000 requests`
- ✅ `redis-backed rate limiter deployed in staging; quota correctly enforced across 2 replicas (test: two parallel clients, verify combined quota)`
- ✅ `audit at depth:scan shows zero RISK-*** with Risk: High in the Security category`
- ❌ "performance improved" (not falsifiable)
- ❌ "users are happier" (not falsifiable)

If you cannot write a falsifiable criterion for a phase, the phase scope is wrong — split or rescope it. Do not ship vague criteria.

## Audience & Product Understanding

Include a `## Audience & Product Understanding` section with:

- **Audience** — primary users (from override file if present, else inferred from ideas artifact's Audience Signals section).
- **Product stage** — from `stage:` argument.
- **Non-goals** — explicitly out of scope for this roadmap (e.g., "market expansion," "platform rewrite"). This keeps the roadmap honest.

The 2–5 named themes that organize the milestones get their own standalone `## Strategic Themes` section (one bullet per theme with a one-line description) — do not fold them into this section.

## Refusal rules (enforced)

Per header §9:

- **Do not** run without a valid ideas artifact.
- **Do not** introduce `MS-###` milestones untraceable to an IDEA-### or RISK-###. (`INV-###` milestones trace to a `UNK-###` and at least one `MS-###` or `IDEA-###` they `Unblock:`.)
- **Do not** write vibes-based exit criteria.
- **Do not** include competitor analysis. That's `/market-scan`, future.
- **Do not** reorder based on taste when dependencies exist — honor the DAG.
- **Do not** exceed 300 lines (header §10).

## Output

Write to the path from `~/.claude/skills/_shared/dated-filename.sh roadmap <repo>/.claude/pipeline` (i.e. `<repo>/.claude/pipeline/roadmap-YYYY-MM-DD.md`) with:

1. Frontmatter per header §4, including:
   ```yaml
   inputs:
     - path: .claude/pipeline/ideas-YYYY-MM-DD.md
       sha256: <hash>
     - path: .claude/pipeline/audit-YYYY-MM-DD.md
       sha256: <hash>
   ```
2. Required H2 sections per header §11:
   ```
   ## Summary
   ## Audience & Product Understanding
   ## Strategic Themes
   ## Phase 0 — Resolve Unknowns        (optional; emit only when populated)
   ## Phase 1 — Foundation
   ## Phase 2 — Core Expansion
   ## Phase 3 — Differentiation
   ## Quick Wins
   ## Strategic Bets
   ## Assumptions & Limitations
   ## Convention Conflicts
   ```
   Phase 0 is the ONLY conditional section. Phases 1–3 are always emitted, even when a phase has no milestones — in that case write one line explaining why it's empty (e.g. "No differentiation-scale ideas in the current ideas artifact; revisit after Phase 2") plus `### Exit Criteria` gating progression beyond it.
3. **Summary** — 3–5 bullets: product direction, strongest bets, biggest assumption.
4. **Each Phase** — milestone cards under it, followed by `### Exit Criteria`.
5. **Quick Wins** — list MS-### IDs that are Phase 1 + Effort: Low.
6. **Strategic Bets** — list MS-### IDs that are Phase 3 + Priority: High.
7. **Assumptions & Limitations** — enumerate anything Assumption-Based that shaped phase ordering, plus any ideas you couldn't fit and why.

## After writing

Report to the user:
1. Artifact path.
2. Milestone count per phase.
3. Quick Wins (IDs + titles).
4. Strategic Bets (IDs + titles).
5. Any ideas from the ideas artifact that did NOT make it into a milestone, with one-line reason each.
6. Suggested review checkpoint: "Read Phase 1 Exit Criteria — if any feel vague, flag and I'll tighten."

Do NOT auto-invoke anything downstream. Stop after writing.
