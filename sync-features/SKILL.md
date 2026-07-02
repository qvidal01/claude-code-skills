---
name: sync-features
disable-model-invocation: true
description: "Projects the features-YYYY-MM-DD.md artifact (from /featurate) into Odoo product records (one product per FEAT-###) in a dedicated Offerings category. Dry-run by default, writes a sync-features-plan artifact. Pass --apply for real writes, which produces a sync-features-result artifact. Idempotent — matches existing Odoo products by their [FEAT-###] title prefix. Field-isolated to `description`; never touches price or description_sale. TRIGGER WHEN: user says 'sync features to Odoo', 'push feature ideas to CRM', 'create Odoo tasks from features', or after running /featurate. PREREQUISITE: features-YYYY-MM-DD.md must exist. DO NOT USE WHEN: no features artifact exists (run /featurate first)."
---

# /sync-features — Odoo Projection of Features Artifact

**Prompt version:** 1.0.0
**Pipeline version:** 1.4.1
**Added in:** pipeline 1.4.1

You are acting as a **data-movement agent**. Your job is to project the `/featurate` features artifact into Odoo as a sellable-offering backlog. You are explicitly NOT a strategist, a curator, an editor, or a pricer — sync is a projection, not a transformation.

This skill is the feature-side analogue of `/sync-ideas`. It exists because `/featurate` produces a parallel product backlog (`FEAT-###`) that `/sync-ideas` intentionally does not touch.

## When To Use
- After running `/featurate` and wanting to push results to Odoo CRM
- "sync my features", "push feature ideas to Odoo", "create CRM records from features"

## Prerequisites
> **PREREQUISITE:** Requires `features-YYYY-MM-DD.md` from `/featurate`. If absent, run `/featurate` first.

## Feature Card Format
Each feature synced to Odoo must include:
- **name** — short, unique feature title
- **description** — one-paragraph explanation of the feature
- **rationale** — evidence citation (file/line or audience insight)
- **confidence** — High / Medium / Low
- **mode** — evidence | exploratory

If any required field is missing, prompt the user to fill it in before syncing.

## Field ownership (non-negotiable)

| Skill | Owns | Content |
|---|---|---|
| `/sync-ideas` | `description` on `[IDEA-###]` products | The idea card |
| `/sync-features` | `description` on `[FEAT-###]` products | The feature card |
| operator | `list_price` on all products | Pricing — NEVER set or changed by this skill |
| `/sync-roadmap` | `description_sale` | Phase/Milestone stamp (out of scope here) |

Re-running this skill must never touch `list_price`, `description_sale`, `name` (except on create), or any `[IDEA-###]` product. It writes only `description` on `[FEAT-###]` products in the target category.

## Before anything else

1. **Read the shared header** at `~/.claude/pipeline/header.md`. Authoritative.
2. **Read the target repo's `CLAUDE.md`** if present. Precedence per header §3.
3. **Locate the latest features artifact** — `~/.claude/skills/_shared/dated-filename.sh --latest features <repo>/.claude/pipeline` prints it (empty if absent). If absent, **stop** and tell the user:
   > "No features artifact found. Run `/featurate` first, then re-run `/sync-features`."
4. **Validate the artifact:** frontmatter parses; `repo` matches; `pipeline_version` major.minor matches the header; `repo_head_sha` matches `git rev-parse HEAD` or `--force-stale` is passed. On failure, stop and report.
5. **Verify the Odoo MCP server is available** (`mcp__odoo__product_categories` / `crm_health_check`). If unreachable, stop and report — no placeholder sync.
6. **Confirm arguments:**
   - `--apply` (default: absent → dry-run; writes a plan, no Odoo writes).
   - `--category-name <name>` (default: `<repo> / Offerings`). Distinct from `/sync-ideas`' `<repo> / Audit Ideas` so sellable offerings stay separate from the engineering backlog.

## Invocation

```
/sync-features                                   # dry run; writes sync-features-plan-YYYY-MM-DD.md
/sync-features --apply                           # real writes; writes sync-features-result-YYYY-MM-DD.md
/sync-features --category-name "Custom Offerings"
```

## Design contract (non-negotiable)

- **Idempotent.** Re-running with `--apply` must not duplicate products. Match by exact `[FEAT-###]` title prefix in the target category.
- **Projection, not transformation.** Description content comes verbatim from the feature-card fields. No rewriting, summarizing, or "improving."
- **Additive + updating.** Create missing products; update drifted `description`; never delete.
- **Scoped.** Touches only products whose titles begin with `[FEAT-###]` in the target category.
- **Sellable by default.** Created products use `sale_ok=true`, `purchase_ok=false`, `product_type=service`, `list_price=0` (placeholder — the operator sets real prices later; this skill never writes `list_price`).
- **No pricing.** The skill must not set or change `list_price`, even on update.

## Phase 1 — Read current Odoo state

1. `mcp__odoo__product_categories` for the target name. Record `category_id` if present.
2. If absent:
   - dry-run: record as planned category create.
   - `--apply`: `mcp__odoo__product_create_category(name=<target>)`. (Unlike `/sync-roadmap`, this skill MAY create its own category — it owns the Offerings space.)
3. `mcp__odoo__product_search(category=<name>, query="[FEAT-")` → map `FEAT-### → {product_id, title}`.

## Phase 2 — Compute diff

For each `FEAT-###` in the artifact:
1. Title: `[FEAT-###] <title>` (strip outer backticks/quotes).
2. Description: plain-text feature card — Theme, Mode, Rationale, Source, User Outcome, Shape, Audience fit, Effort, Confidence, Risk, Dependencies, Notes (if present), Status. Same field order as the `/featurate` card format. No markdown fences.
3. Look up in the Odoo map: not found → planned create; found + matches → no-change; found + differs → planned update (description only).

Detect **drift**: `[FEAT-###]` products in Odoo not in the artifact → `## Manual Review (drift)`, never auto-delete.

> **Shared classifier:** the create/update/no-change/drift classification is the
> same mechanical step used by `/sync-ideas` and `/sync-roadmap`. After rendering
> step 2, run `~/.claude/skills/_shared/odoo-sync-diff.py --desired desired.json --existing existing.json --field description`
> (desired = `[{id,title,body}]`, existing = the `product_search` results). It
> returns the plan as JSON. Only the rendering (above) and the MCP writes (Phase 3) are yours.

## Phase 3 — Apply (only when `--apply`)

- Planned create → `mcp__odoo__product_create(name, product_type="service", category=<name>, sale_ok=true, purchase_ok=false, description=<text>)`. Do NOT pass `list_price`.
- Planned update → `mcp__odoo__product_update(product_id, description=<text>)`. ONLY `description`.
- Capture every response. On error, record under `## Errors` and continue.

## Refusal rules (enforced)

- **Do not** write to Odoo unless `--apply` is passed.
- **Do not** set or modify `list_price` (operator owns pricing) or `description_sale`.
- **Do not** modify `[IDEA-###]` products or any product outside the target category.
- **Do not** delete products or remove `FEAT-###` records no longer in the artifact — flag under Manual Review.
- **Do not** rewrite/summarize feature text — projection only.
- **Do not** invent `FEAT-###` IDs — only those in the artifact.
- **Do not** exceed 250 lines in either artifact.

## Output

### Dry-run (default) → `dated-filename.sh sync-features-plan <repo>/.claude/pipeline` (`<repo>/.claude/pipeline/sync-features-plan-YYYY-MM-DD.md`)

Frontmatter per header §4 (`apply: false`, `inputs` → features artifact hash). Sections:
```
## Summary
## Planned Category
## Planned Creates
## Planned Updates
## Planned No-Change
## Manual Review (drift)
## Tools Run
```

### Apply (`--apply`) → `dated-filename.sh sync-features-result <repo>/.claude/pipeline` (`<repo>/.claude/pipeline/sync-features-result-YYYY-MM-DD.md`)

Frontmatter (`apply: true`, `inputs` → features artifact + plan if present). Sections:
```
## Summary
## Category
## Created
## Updated
## No-Change
## Manual Review (drift)
## Errors
## Tools Run
```
- **Created** — per row: FEAT-###, product_id, category_id. Note `list_price=0` placeholder (operator to price).

## After writing

Report: artifact path; counts (category create?, creates, updates, no-change, drift, errors); the newly created product_ids; and a reminder that **`list_price` is unset (0)** — the operator prices the offerings. Do NOT auto-invoke anything downstream.
