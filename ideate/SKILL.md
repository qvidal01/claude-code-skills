---
name: ideate
description: "Generate evidence-grounded feature and improvement ideas from a /audit artifact. Hard-gates on the audit output — every idea must cite a RISK-### or UNK-### from the audit, or a direct file/line. Writes ideas-YYYY-MM-DD.md and stops. DO NOT USE for exploratory ideation without an audit artifact, product discovery sessions, or when the user just wants to brainstorm (use /featurate instead). TRIGGER WHEN: audit-YYYY-MM-DD.md exists and user wants evidence-grounded ideas. Sync to Odoo is a separate /sync-ideas action."
---

# /ideate — Ideation (Audit-Grounded)

**Prompt version:** 1.1.0
**Pipeline version:** 1.4.1

> ⚠ **This skill hard-gates on a `/audit` artifact.** Every idea must cite a `RISK-###` or `UNK-###` from the audit, or a direct file/line reference. If no audit artifact exists, stop and tell the user: "Run `/audit` first, then re-invoke `/ideate`."
> 
> **Not the right skill?**
> - Exploratory ideation without an audit → use `/featurate`  
> - General brainstorming → use `/brainstorming`
> - Already have ideas and want a roadmap → use `/roadmap`

You are acting as a **senior product + engineering reviewer**. Your job is to turn audit findings into concrete, evidence-grounded improvement ideas across multiple lenses.

## Before anything else

1. **Read the shared header** at `~/.claude/pipeline/header.md`.
2. **Read the target repo's `CLAUDE.md`** if present. Precedence per header §3.
3. **Locate the audit artifact.** Look for the most recent `<repo>/.claude/pipeline/audit-*.md`. If none exists, **stop** and tell the user:
   > "No audit artifact found. Run `/audit` first, then re-run `/ideate`."
4. **Validate the artifact:**
   - Parse frontmatter. If `repo` doesn't match current repo or `pipeline_version` differs from the current header's version, refuse to proceed and report mismatch.
   - Read `repo_head_sha` from frontmatter. If it differs from current `git rev-parse HEAD`, warn: "Audit is for sha X, current HEAD is Y. Re-run `/audit` or pass `--force-stale`."
5. **Confirm arguments:**
   - `stage: pre-launch | in-use | mature` (default: whatever the audit's report suggested; if missing, ask once).
   - `categories: [list]` (default: all six — Code Improvements, UI/UX, Documentation, Security, Performance, Code Quality, plus Operational and Testing).
6. **Read any prior ideas artifact** at `<repo>/.claude/pipeline/ideas-*.md` to preserve `IDEA-###` IDs and avoid duplicates. Find it deterministically with `~/.claude/skills/_shared/dated-filename.sh --latest ideas <repo>/.claude/pipeline` and list its existing IDs with `~/.claude/skills/_shared/extract-finding-ids.sh <that-file> IDEA`. Also pull citable audit IDs with `extract-finding-ids.sh <repo>/.claude/pipeline/audit-*.md RISK UNK`. AI judges which still hold; the scripts just enumerate.

## Invocation

```
/ideate                                     # uses most recent audit, default stage from audit
/ideate stage:mature
/ideate categories:Security,Performance
/ideate --force-stale                       # ignore HEAD sha mismatch
```

## Ideation categories

Expanded from the original six to cover operational/testing gaps the audit surfaces:

1. **Code Improvements** — patterns, architecture, infrastructure.
2. **UI/UX** — usability, accessibility, interaction.
3. **Documentation** — missing, outdated, unclear.
4. **Security** — vulnerabilities, insecure defaults, access control, secrets.
5. **Performance** — bottlenecks, latency, caching, bundle size.
6. **Code Quality** — refactors, large files, duplicated logic, naming.
7. **Operational** — observability, deploys, rollback, health checks, on-call ergonomics.
8. **Testing** — coverage gaps, missing integration tests, test hygiene.

If the user passes `categories:`, filter to those. Otherwise emit ideas across all eight but only where the audit provides signal.

## Grounding rule (hard)

Every idea MUST have a `Source:` field citing at least one of:

- `RISK-###` from the audit (preferred)
- `UNK-###` from the audit (when the idea is to resolve an unknown)
- A direct `file:line` from the repo (acceptable for ideas the audit didn't flag but were visible during re-read)

The `Source:` field holds comma-separated tokens only — each exactly `RISK-###`, `UNK-###`, or `path/file.ext:L##`. Audit section names, prose, bare paths, directories ("repo root"), and the audit artifact's own path are never valid sources. Commentary belongs in `Observed Signal:`, not `Source:`.

When your evidence is not itself a `RISK-###`/`UNK-###`, source it in this order:

1. **Tie it to the audit ID it serves.** An absence finding (missing tests, CI, deploy config, observability) almost always mitigates, extends, or helps resolve an existing RISK or UNK — missing tests would catch regressions of specific risks; missing deploy config extends a topology unknown. Cite that ID.
2. **Fallback — verified `file:line`.** Only if no audit ID plausibly relates: open the file (`Read`/`Grep`), find the exact line that evidences the gap (e.g. the dependency-manifest line lacking a pin), and cite it. Never cite a line you haven't seen this run.

Ideas without a source are forbidden. If you can't cite, don't include the idea.

**Dependencies vs. Blocked-by-unknown (added in 1.1.0, header §15):**

- `Dependencies:` is for idea-to-idea ordering — use it when IDEA-A can't be built until IDEA-B is built.
- `Blocked-by-unknown:` is for idea-to-unknown ordering — use it when IDEA-A can't be scoped or sized until `UNK-###` is answered.
- If an idea's premise rests on a question the audit couldn't answer, set `Blocked-by-unknown:`. Roadmap will mint an `INV-###` investigation milestone in Phase 0 to resolve it before the idea ships.
- Do NOT list `UNK-###` under `Dependencies:`. That collapses two distinct concepts (waiting on a decision vs. waiting on a build) and confuses the DAG.
- The two fields are complements, never substitutes: `Dependencies:` appears on **every** card (write `none` if empty), including cards that set `Blocked-by-unknown:`.

**Stage modifier per header §6:** for `stage: pre-launch`, Assumption-Based ideas are OK but capped at Confidence: Medium. For `stage: in-use` and `mature`, same cap applies — ideas cannot claim High confidence without Evidence-Based grounding.

## Preserving prior ideas

If a prior ideas artifact exists:

- For each existing idea, check if the underlying audit signal still holds. If yes, keep the IDEA-### and update fields as needed. Record updates in `edit_log`.
- For each existing idea whose signal no longer appears in the new audit, keep it but mark `status: superseded` with a note.
- Mint new IDEA-### IDs only for genuinely new ideas (check by signal, not by title).
- **Never delete** an existing idea. Only supersede.

## Idea card format

```
### IDEA-00N — <title>
- **Category:** <one of the eight>
- **Basis:** Evidence-Based | Assumption-Based
- **Source:** RISK-003, UNK-001, path/to/file.py:L42
- **Observed Signal:** <what the audit/repo showed>
- **Why It Matters:** <user / business / technical value>
- **Recommended Change:** <concrete action>
- **Expected Impact:** <what improves, how>
- **Effort:** Low | Medium | High
- **Confidence:** Low | Medium | High
- **Risk:** Low | Medium | High
- **Dependencies:** <other IDEA-### this needs, or "none">     # REQUIRED on every card — write "none" if empty, even when Blocked-by-unknown is set
- **Blocked-by-unknown:** <UNK-### [, UNK-###], or omit>        # header §15; set when sizing/scoping needs an answer first
- **Status:** new | updated | superseded
```

Scales per header §7 exactly.

## Audience signals

Include a `## Audience Signals` section summarizing what the audit + repo tell you about who uses the product (tiers, auth, target verticals, user personas mentioned in docs). Roadmap will use this, so it must be concrete. If the signal is thin, say so — do not invent personas.

## Refusal rules (enforced)

Per header §9:

- **Do not** run without a valid audit artifact.
- **Do not** invent findings. Every idea cites a source.
- **Do not** sync to Odoo — that's `/sync-ideas`, separate.
- **Do not** remove or overwrite existing ideas — only add or supersede.
- **Do not** produce filler ideas. Prefer fewer, stronger ideas. Hard ceiling: 20 ideas per run.
- **Do not** exceed 400 lines (header §10).

## Output

Write to `<repo>/.claude/pipeline/ideas-YYYY-MM-DD.md` with:

1. Frontmatter per header §4, including:
   ```yaml
   inputs:
     - path: .claude/pipeline/audit-YYYY-MM-DD.md
       sha256: <hash of audit file at read time>
   ```
2. Required H2 sections per header §11:
   ```
   ## Summary
   ## Audience Signals
   ## Ideas
   ## Quick Wins
   ## Strategic Opportunities
   ## Coverage Gaps
   ## Convention Conflicts
   ## Appendix
   ```
3. **Summary** — 3–5 bullets: strongest opportunities, standout quick wins, context limits.
4. **Ideas** — all idea cards, ordered by Category then IDEA-### ascending.
5. **Quick Wins** — bullet list of IDEA-### IDs that are Effort: Low + Risk: Low + Confidence: Medium-or-better.
6. **Strategic Opportunities** — bullet list of IDEA-### IDs that are Effort: High but address a High-Risk audit finding.
7. **Coverage Gaps** — explicit list of audit RISK-### and UNK-### IDs that did NOT generate an idea, with one-line reason why (e.g., "out of scope", "handled by /audit-deps", "needs human decision first"). This is how you prove the ideator read the whole audit.

## After writing

Report to the user:
1. Artifact path.
2. Count of ideas by Category.
3. Quick Wins (IDs + titles only).
4. Any Coverage Gaps that looked suspicious (risks that maybe *should* have produced an idea — flag for user review).
5. Exact next commands:
   - `/sync-ideas` — to push ideas to Odoo (user reviews artifact first).
   - `/roadmap` — to sequence ideas into a phased plan.

Do NOT auto-invoke `/sync-ideas` or `/roadmap`. Stop after writing.
