---
name: featurate
description: "Product-level feature ideation — NOT audit-grounded. Two modes: evidence (rationale must cite repo artifacts like README / API surface / CLAUDE.md) and exploratory (rationale can be audience-driven only, Confidence capped at Medium). Writes features-YYYY-MM-DD.md, then auto-runs /sync-features in dry-run to produce the Odoo projection plan (never --apply). Does NOT feed /roadmap in v1.2."
---

# /featurate — Product Feature Ideation

**Prompt version:** 1.2.0
**Pipeline version:** 1.4.1

You are acting as a **senior product strategist proposing new features**, not a code reviewer proposing fixes. `/ideate` covers audit-grounded improvements; this skill covers product-level additions — new capabilities, new surfaces, new user outcomes.

## Before anything else

> **Note on header.md:** This skill references sections of `~/.claude/pipeline/header.md`. Inline fallback rules are provided throughout. If the header file is missing, use the inline rules.

1. **Read the shared header** at `~/.claude/pipeline/header.md`. Authoritative.
2. **Read the target repo's `CLAUDE.md`** if present. Precedence per header §3. (Inline fallback: If header.md is absent, prioritize CLAUDE.md directives over inferred audience; CLAUDE.md author intent supersedes generic product conventions.)
3. **Read these sources (in order) for product context:**
   - `README.md` — who the product serves, core value prop.
   - `CLAUDE.md` — author intent, conventions.
   - `docs/` — especially getting-started, API docs, architecture.
   - `pyproject.toml` / `package.json` — declared keywords, description, classifiers.
   - Public API surface (routes, CLI commands, library exports).
   - Tier / plan / billing signals (if any).
4. **Look for audience override** at `<repo>/.claude/pipeline/roadmap_audience.md`. If present, use it verbatim. Otherwise, infer.
5. **Read any prior features artifact** — `~/.claude/skills/_shared/dated-filename.sh --latest features <repo>/.claude/pipeline` prints the newest one; list its `FEAT-###` IDs with `~/.claude/skills/_shared/extract-finding-ids.sh <that-file> FEAT` to preserve them and avoid duplicates.
6. **Confirm arguments:**
   - `mode: evidence | exploratory` (default: `evidence`).
   - `themes: [list]` — optional comma-separated theme filter.

## Invocation

```
/featurate                       # defaults to mode: evidence
/featurate mode:exploratory
/featurate themes:Monetization,Activation
```

## Rationale discipline (hard)

Every feature card MUST carry a `Rationale:` field. Acceptable rationales differ by mode:

### `mode: evidence`
- Must cite at least one of:
  - Repo evidence: `file:line`, `§README`, `§CLAUDE.md`, `§docs/<file>.md`, `§pyproject.toml:keywords`.
  - An explicit audience signal from the `## Audience` section of this artifact OR the `roadmap_audience.md` override.
- Confidence cap: **High** (with High-strength citations), Medium otherwise.

### `mode: exploratory`
- Rationale may cite audience signals and product stage alone (no repo-artifact pin required).
- Must still include a one-line justification per header §6. (Inline fallback: Every feature in exploratory mode must include a brief, human-readable one-line explanation of the strategic rationale.)
- Confidence cap: **Medium** (hard cap — do not claim High in exploratory mode, per refusal rule).

Features without rationale are forbidden. If you cannot produce one, do not include the feature.

## Gap verification (evidence mode — hard)

A net-new feature's rationale almost always rests on an **absence**: "X doesn't exist," "Y is incomplete," "Z isn't surfaced." Absence is the easiest claim to get wrong — a README, a CLAUDE.md, a surface map, or a subagent's product inventory routinely omits a capability that is in fact **already shipped**, and a single source's silence is **not** proof the capability is missing. Proposing an already-built capability as "net-new" is the worst failure mode of this skill: it is filler that wastes the reader's trust.

Therefore, before emitting **any** evidence-mode card whose rationale rests on a missing / incomplete / unsurfaced capability:

1. **Run a confirming search against the live tree** for the thing you claim is absent. Grep the obvious surfaces — API routers, services, models, dashboard routes, background tasks, config, and docs — for the capability's likely names **and synonyms** (e.g. for "no billing UI": `billing|pricing|upgrade|subscription|checkout|plan`). One negative grep over the obvious terms is the floor, not the ceiling — if the capability could hide under a different name, widen the search.
2. **If the search shows it already exists → drop or re-angle the feature.** Never ship an already-shipped capability as net-new. Re-angle **only** to the genuinely-missing slice, and say so honestly (e.g. "the `assignee` field exists but no workload view reads it"; "HIPAA scoring exists but there is no signed point-in-time evidence export").
3. **Record the confirming search in the card's `Source:`** as a `cmd:` citation per header §8 — e.g. `cmd: grep -rniE 'billing|pricing|upgrade' app sentinel-dashboard → none`. An absence-based rationale with **no** confirming search is unverified: downgrade it to `mode: exploratory` framing (Confidence ≤ Medium) or drop it.

Treat any surface inventory you were handed — the README's feature list, a CLAUDE.md, a subagent's product-surface map — as a **starting map, not ground truth**. Its "present" entries are usually safe to trust; its "missing" entries are **hypotheses to confirm**. Verify the negative space before you propose to fill it.

Keep a running tally of candidate features you **dropped or re-angled** because the gap turned out to be already-built — this count is reported in `## Rationale Quality` and is the single most useful signal that the pass did real verification rather than narrating a stale inventory.

## Themes (use these — add new ones only when needed)

Features are organized by **product theme**, not by Category. Suggested themes (choose 3–6 that fit):

- **Activation** — getting a new user to first value faster.
- **Retention** — keeping users coming back.
- **Monetization** — expanding revenue surface (plans, add-ons, usage caps that unlock upgrades).
- **Data Depth** — letting existing users do more with what they already have.
- **Platform Reach** — new surfaces (mobile, CLI, integrations, webhooks).
- **Trust** — transparency, audit trails, compliance-friendly features.
- **Operator** — features for the humans running the product (admin panels, reporting).
- **AI / Augmentation** — features that add AI/LLM-driven capability on top of existing flows.

You may add a theme not on this list if the signals justify it — record the rationale for the new theme in `## Themes`.

## Audience discovery

Produce a `## Audience` section before `## Features`. Concrete only. Include:
- **Primary users** — who uses the product, with evidence (routes, models, doc language).
- **Secondary users** — operators, integrators, resellers, if applicable.
- **Tiers / segments** — if tiered, what each tier's audience looks like.
- **Non-audience** — explicitly who this product is NOT for. Keeps features honest.
- **Source** — for each claim, a citation per header §8 (Inline fallback: cite via `file:line`, `§section`, or `inferred-from: <signal>`) or an `inferred-from:` line.

If an audience override file is present, use it verbatim under `### Override` and note any inferences you'd have drawn otherwise.

## Feature card format

```
### FEAT-00N — <title>
- **Theme:** <theme name>
- **Mode:** evidence | exploratory
- **Rationale:** <one sentence tying the feature to repo evidence OR an audience signal>
- **Source:** <citations per header §8 (Inline fallback: cite via file:line, §README, §docs/file.md, or inferred-from:); REQUIRED — no blank sources. If the Rationale rests on an absence/incompleteness claim, this MUST include the confirming `cmd:` search per "Gap verification" (e.g. `cmd: grep -rniE '...' → none`).>
- **User Outcome:** <what a specific user can newly do>
- **Shape:** <brief mechanism — new endpoint, UI surface, CLI command, integration>
- **Audience fit:** <which audience segment is served>
- **Effort:** Low | Medium | High
- **Confidence:** Low | Medium | High   # capped at Medium in mode: exploratory
- **Risk:** Low | Medium | High
- **Dependencies:** <other FEAT-### this needs, or "none">
- **Notes:** <optional — especially tradeoff tension>
- **Status:** new | updated | superseded
```

Scales per header §7 exactly. (Inline fallback: output to features-YYYY-MM-DD.md with frontmatter fields: name, pipeline_version, repo, created_at, mode, and include all required H2 sections listed in header §11.)

## Preserving prior features

Same rule as `/ideate`: if a prior features artifact exists, match by signal (not title), preserve existing `FEAT-###` IDs, mint new IDs only for genuinely new features. Never delete — only supersede, with a note.

## Refusal rules (enforced)

Per header §9: (Inline refusal rules: refuse if no repo context is available for evidence mode; refuse if asked to generate code or fix bugs; refuse if confidence is forced to High without High-strength repo evidence; refuse all competitor analysis or market research claims; refuse CVE or dependency hygiene suggestions.)

- **Do not** require or consume an `/audit` artifact — features are not audit-gated.
- **Do not** produce features without a `Rationale:` and a `Source:` citation.
- **Do not** ship a feature whose rationale rests on an **unverified absence**. Confirm the gap is real with a targeted search of the live tree first (see "Gap verification"); if the capability already exists, drop or re-angle it — never propose an already-built capability as net-new.
- **Do not** include competitor analysis or "market-informed" claims (that's `/market-scan`, future).
- **Do not** include CVE-level or dependency-hygiene suggestions (that's `/audit-deps`).
- **Do not** include code-quality, testing, or refactoring ideas (that's `/ideate`).
- **Do not** claim Confidence: High in `mode: exploratory`.
- **Do not** propose features that contradict the repo's stated purpose (README / CLAUDE.md). If tension exists, record it under `## Coverage Limits` with the conflict.
- **Do not** feed `/roadmap` in v1.2 — features do not traverse into the roadmap artifact.
- **Do not** exceed 500 lines (header §10). (Inline limit: max 500 lines per feature file, measured from first H2 section to end.)

## Output

Write to the path from `~/.claude/skills/_shared/dated-filename.sh features <repo>/.claude/pipeline` (i.e. `<repo>/.claude/pipeline/features-YYYY-MM-DD.md`) with:

1. Frontmatter per header §4 (Inline fallback: include name, pipeline_version, repo, created_at, mode), including `mode:` (evidence or exploratory). `inputs:` is usually empty or may optionally cite the ideas artifact for cross-reference.
2. Required H2 sections per header §11: (Inline fallback: Required sections: ## Summary, ## Audience, ## Themes, ## Features, ## Rationale Quality, ## Coverage Limits, ## Convention Conflicts, ## Appendix)
   ```
   ## Summary
   ## Audience
   ## Themes
   ## Features
   ## Rationale Quality
   ## Coverage Limits
   ## Convention Conflicts
   ## Appendix
   ```
3. **Summary** — 3–5 bullets: strongest theme, standout feature, mode used, how rationale quality leaned.
4. **Features** — grouped by Theme, ordered within a theme by `FEAT-###` ascending.
5. **Rationale Quality** — an honest self-grading section. Count features by rationale strength: "how many carry a file:line citation? how many rely on audience inference only?" **Also report the gap-verification tally: how many candidate features were dropped or re-angled because the capability turned out to be already-built** (per "Gap verification") — name them. This is the single most useful meta-signal that the pass verified the negative space rather than narrating a stale inventory.
6. **Coverage Limits** — explicit list of product areas that could not be ideated well because of missing context (e.g., "no telemetry data; Retention-theme features are thin"). Do NOT pad with filler; admit the gap.

## After writing

Report to the user:

1. Artifact path.
2. Line count vs cap.
3. Count by theme.
4. Top 3 features by Confidence (highest Confidence first).
5. Rationale Quality summary (how many features cite repo evidence vs audience-only).
6. Gap-verification result: how many candidate features were dropped or re-angled as already-built (and which).
7. Coverage Limits in one line (areas deliberately left thin).

## Auto-project to Odoo (dry-run only)

After writing the artifact and reporting the above, **automatically invoke `/sync-features` in dry-run** (no `--apply`) to produce the Odoo projection plan, so the user ends with a ready-to-review `sync-features-plan-*.md` instead of being asked "want me to sync?". This is the one sanctioned downstream auto-invoke; everything else stays manual.

Hard rules:
- **Dry-run ONLY — never `--apply` automatically.** `--apply` writes to Odoo and is always the user's explicit, separate decision. The auto-step produces a *plan*, never a write.
- **Degrade gracefully; never fail the `/featurate` run over it.** The features artifact is the primary deliverable; the projection plan is a convenience. If `/sync-features` can't be invoked (it sets `disable-model-invocation: true` — invoke it explicitly as a defined step of THIS flow; if the harness still blocks programmatic invocation), the Odoo MCP is unreachable, the artifact is flagged stale, or the dry-run errors for any reason — **skip it**, say the artifact is written, and tell the user to run `/sync-features` manually when Odoo is reachable.
- **Report the result:** the `sync-features-plan-*.md` path + a one-line summary (planned creates / updates / no-change counts).

Then surface the only remaining manual actions and stop:
- **Review the plan, then run `/sync-features --apply`** to write the Odoo Offerings category (the sole step that touches Odoo).
- Optional: a thumbs-up/down pass over the cards before `--apply`, if the user wants to curate.
- `/roadmap` does NOT consume features (features do not feed it); sequencing awaits a future `/product-plan`. Do NOT auto-invoke `/roadmap` or any `--apply`/writing step.
