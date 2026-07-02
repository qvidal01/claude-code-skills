---
name: sync-roadmap
disable-model-invocation: true
description: "Project the latest /roadmap artifact onto the IDEA-### products in Odoo. Stamps each product's `description_sale` field with `Phase:`, `Milestone:`, and `Theme:` so a Claude session can query Odoo and work through tasks in phased order. Dry-run by default; `--apply` actually writes. Hard-gates on the roadmap artifact and requires `/sync-ideas --apply` to have populated the IDEA-### products first. TRIGGER WHEN: 'sync roadmap to Odoo', 'push milestones to CRM', 'create project tasks from roadmap', after running /roadmap. PREREQUISITE: roadmap-YYYY-MM-DD.md must exist."
---

# /sync-roadmap — Odoo Phase/Milestone Projection

**Prompt version:** 1.0.0
**Pipeline version:** 1.4.1

You are acting as a **data-movement agent**. Your job is to project the roadmap artifact's phase and milestone metadata onto the IDEA-### products that already exist in Odoo. You are explicitly NOT a strategist or curator — projection only, no rewrites.

## Prerequisites & When To Use
> **PREREQUISITE:** Requires `roadmap-YYYY-MM-DD.md` from `/roadmap`. Run `/roadmap` first.

**Use when:** "sync roadmap", "push milestones to Odoo", "create project plan from roadmap artifact"

## header.md Dependency (inline fallback)
This skill may reference `~/.claude/pipeline/header.md` for output format rules. If that file is absent, use these inline rules:
- Output file: `<repo>/.claude/pipeline/sync-roadmap-YYYY-MM-DD.md`
- Frontmatter must include: `name`, `pipeline_version`, `repo`, `created_at`, `inputs`
- Required sections: `## Summary`, `## Milestones Synced`, `## Skipped`, `## Convention Conflicts`

## Field ownership (non-negotiable)

To avoid stepping on `/sync-ideas`, this skill owns a different field:

| Skill | Owns | Content |
|---|---|---|
| `/sync-ideas` | `description` | The idea card (Category, Basis, Source, etc.) |
| `/sync-roadmap` | `description_sale` | Phase, Milestone, Theme, Roadmap path |

Re-running either skill must never touch the other's field. If `description_sale` is found to contain non-roadmap content (operator-edited), the skill must refuse to overwrite it and flag under Manual Review.

## Before anything else

1. **Read the shared header** at `~/.claude/pipeline/header.md`. Authoritative.
2. **Read the target repo's `CLAUDE.md`** if present. Precedence per header §3.
3. **Locate the latest roadmap artifact** — `~/.claude/skills/_shared/dated-filename.sh --latest roadmap <repo>/.claude/pipeline` prints it (empty if absent). If absent, **stop** and tell the user:
   > "No roadmap artifact found. Run `/roadmap` first, then re-run `/sync-roadmap`."
4. **Validate the artifact** per §5 of this file.
5. **Verify the Odoo MCP server is available.** Probe for `mcp__odoo__product_search`. If unreachable, stop and report — do NOT attempt a placeholder sync.
6. **Confirm arguments:**
   - `--apply` (default: absent → dry-run). When absent, the skill writes a sync-roadmap-plan and performs no Odoo writes.
   - `--category-name <name>` (default: `<repo> / Audit Ideas`). Override the destination category. Must match what `/sync-ideas` used.

## Invocation

```
/sync-roadmap                                      # dry run; writes sync-roadmap-plan-YYYY-MM-DD.md
/sync-roadmap --apply                              # real writes; writes sync-roadmap-result-YYYY-MM-DD.md
/sync-roadmap --category-name "My Custom Category" # override category
```

## Design contract (non-negotiable)

- **Sync is idempotent.** Re-running with `--apply` on the same roadmap must report all rows as no-change.
- **Sync is projection, not transformation.** Description content comes verbatim from the roadmap milestone fields. The skill does not rewrite, summarize, or "improve" milestone text.
- **Sync is additive + updating.** Update missing/changed `description_sale` fields; never delete a product.
- **Sync is scoped.** Touches only products whose titles begin with `[IDEA-###]` inside the target category. Never modifies unrelated products.
- **Sync is field-isolated.** Only `description_sale` is written. Never touch `description`, `name`, `category`, or any other field — those belong to `/sync-ideas` or the operator.

## Validation of the roadmap artifact

- Frontmatter parses.
- `repo` matches the current working directory's repo name.
- `pipeline_version` major.minor matches the header (patch differences are tolerated per header §1).
- `repo_head_sha` matches current `git rev-parse HEAD`, or `--force-stale` is passed.

If any check fails, stop and report the mismatch. Do NOT sync stale roadmap data silently.

## Phase 1 — Parse the roadmap

Walk the artifact and build a map: `IDEA-### → {phase, milestone_id, milestone_title, theme}`.

Parsing rules (sanity-check your block IDs against `~/.claude/skills/_shared/extract-finding-ids.sh <roadmap-file> MS INV IDEA` — it gives the deterministic set of IDs present; the per-block field extraction below stays here since it needs structure the script doesn't parse):
- A milestone block starts with `### MS-NNN — <title>` or `### INV-NNN — <title>`.
- The block ends at the next `###`, `##`, or end-of-file.
- Within the block, extract:
  - `**Phase:** N` (or `- **Phase:** N` or compact form `**Phase:** N | **Theme:** ...`).
  - `**Theme:** <theme>`.
  - `**Ideas:** IDEA-001, IDEA-003` — the comma-separated IDEA list this milestone covers.
- INV-### blocks resolve UNK-###, NOT IDEA-###. Skip INV-### blocks for IDEA-product stamping.
- A given IDEA-### may appear in multiple MS-### blocks. If so, list both as `MS-002, MS-005` in the stamp.

If parsing finds zero IDEA-### references, stop and report — the roadmap is malformed for this skill's purposes.

## Phase 2 — Read current Odoo state

1. Call `mcp__odoo__product_categories` with the target category name. If absent, stop and report:
   > "Target category `<name>` not found in Odoo. Run `/sync-ideas --apply` first to create the products and category."
2. Call `mcp__odoo__product_search` with `category=<name>` and `query="[IDEA-"`, limit 100. Build a map: `IDEA-### → product_id` from the title prefix.
3. For each matched product, call `mcp__odoo__product_get` to fetch the current `description_sale`. (N+1 calls — acceptable for typical ~10–30 ideas.)

## Phase 3 — Compute diff

For each `IDEA-###` in the parsed roadmap mapping:

1. Construct the target `description_sale` content:
   ```
   Phase: <N>
   Milestone: <MS-NNN> — <milestone title>
   Theme: <theme>
   Roadmap: <basename of roadmap artifact>
   ```
   If the IDEA appears in multiple milestones, render `Milestone:` as a comma-joined list and use the lowest-numbered milestone's phase/theme.

2. Look up the IDEA-### in the Odoo product map:
   - **Not found in Odoo** → record under `## Missing IDEA-### Products`. Common cause: `/sync-ideas --apply` was not re-run after a new IDEA was added.
   - **Found, current `description_sale` exactly matches target** → planned no-change.
   - **Found, current `description_sale` is empty or matches the prior roadmap-stamp pattern but has different values** → planned update.
   - **Found, current `description_sale` is non-empty and does NOT match the roadmap-stamp pattern** (i.e., operator wrote something there) → record under `## Manual Review (drift)` with `action: refusal-operator-edit`. Do NOT overwrite.

Detection of "roadmap-stamp pattern": the content begins with `Phase:` on line 1 and contains `Milestone:`, `Theme:`, `Roadmap:` lines. Anything else is treated as operator content.

> **Shared classifier:** the same `_shared/odoo-sync-diff.py` that `/sync-ideas`
> and `/sync-features` use also implements this operator-edit guard. Render the
> desired stamps to `[{id,title,body}]`, dump the product map to
> `[{product_id,name,description_sale}]`, then run:
> ```bash
> ~/.claude/skills/_shared/odoo-sync-diff.py --desired desired.json --existing existing.json \
>     --field description_sale --protect-marker "Phase:"
> ```
> `--protect-marker "Phase:"` routes any non-empty `description_sale` that doesn't
> start with `Phase:` into `manual_review` (the refusal-operator-edit case) instead
> of `updates`. The `## Missing IDEA-### Products` case (IDEA in roadmap, no product) is the inverse of `drift` — derive it from the diff (desired ids absent from existing).

Also detect:
- **Drift (extra)** — IDEA-### products in Odoo not referenced by the roadmap. Could be Quick Wins not yet sequenced. Record under `## Manual Review (drift)` with `action: not-in-roadmap`. Do NOT clear their `description_sale` (might be from a prior roadmap that did include them).

## Phase 4 — Apply (only when `--apply`)

For each planned update or planned stamp:
- Call `mcp__odoo__product_update` with `product_id` and `description_sale=<target content>`. No other fields.

Capture every response. If any call errors, record it under `## Errors` and continue with remaining items (do NOT abort the whole run on a single failure).

## Refusal rules (enforced)

Per header §9 and the field-ownership rule above:

- **Do not** write to Odoo unless `--apply` is passed.
- **Do not** modify the `description` field — that belongs to `/sync-ideas`.
- **Do not** modify any field besides `description_sale`.
- **Do not** overwrite a non-empty `description_sale` that is not in roadmap-stamp format. Flag for Manual Review instead.
- **Do not** delete Odoo products, archive categories, or remove IDEA-### records that no longer appear in the roadmap. Flag under Manual Review (drift).
- **Do not** touch products whose titles don't match the `[IDEA-###]` prefix pattern.
- **Do not** invent IDEA-### IDs — only project IDs that exist in the roadmap.
- **Do not** create the target category — that's `/sync-ideas`'s job. If missing, refuse and tell the user to run `/sync-ideas --apply` first.
- **Do not** exceed 250 lines in either the plan or the result artifact.

## Output

### Dry-run (default)

Write to `~/.claude/skills/_shared/dated-filename.sh sync-roadmap-plan <repo>/.claude/pipeline` (i.e. `<repo>/.claude/pipeline/sync-roadmap-plan-YYYY-MM-DD.md`) with:

- Frontmatter per header §4 (include `apply: false`, `inputs` referencing the roadmap artifact hash).
- Required sections:
  ```
  ## Summary
  ## Planned Stamps
  ## Planned Updates (Phase Changed)
  ## No-Change
  ## Missing IDEA-### Products
  ## Manual Review (drift)
  ## Tools Run
  ```
- **Summary** — 4 bullets: stamp count, update count, no-change count, drift count.
- **Planned Stamps** — IDEA-### that currently have empty `description_sale` and will get a fresh stamp. Show: IDEA-###, target phase, target milestone.
- **Planned Updates (Phase Changed)** — IDEA-### that already have a roadmap stamp but the values differ (e.g., milestone moved between phases). Show old vs new.
- **No-Change** — IDEA-### already correct.
- **Missing IDEA-### Products** — IDEA-### in roadmap but no matching Odoo product.
- **Manual Review (drift)** — operator-edited `description_sale` fields and IDEA-### products not in the roadmap.
- **Tools Run** — read-only MCP calls.

### Apply (`--apply` passed)

Write to `~/.claude/skills/_shared/dated-filename.sh sync-roadmap-result <repo>/.claude/pipeline` (i.e. `<repo>/.claude/pipeline/sync-roadmap-result-YYYY-MM-DD.md`) with:

- Frontmatter per header §4 (include `apply: true`, `inputs` referencing roadmap + sync-roadmap-plan if present).
- Required sections:
  ```
  ## Summary
  ## Stamped
  ## Updated (Phase Changed)
  ## No-Change
  ## Missing IDEA-### Products
  ## Manual Review (drift)
  ## Errors
  ## Tools Run
  ```
- **Stamped** — per row: IDEA-###, product_id, phase, milestone.
- **Updated (Phase Changed)** — per row: IDEA-###, product_id, old phase/milestone → new phase/milestone.
- **Errors** — per row: IDEA-###, failure reason, raw error excerpt.
- **Tools Run** — every MCP call, its purpose, mutated yes/no.

## After writing

Report to the user:

### Dry-run
1. Artifact path.
2. Counts: stamps, updates, no-change, missing, drift.
3. Sample of 3 planned stamps and 3 planned updates (if any).
4. Exact next command to apply: `/sync-roadmap --apply`.
5. Flag drift entries prominently, especially operator-edit refusals.

### Apply
1. Artifact path.
2. Counts: stamped, updated, no-change, missing, drift, errors.
3. Tip on how to query: `mcp__odoo__product_search(category="<name>", query="[IDEA-")` returns titles; pair with `product_get(product_id=N)` to read `description_sale` for phase info.
4. Error summary if non-empty.

Do NOT auto-invoke anything downstream. Stop after writing.

## Working from Odoo in a Claude session

Once `/sync-roadmap --apply` has run, a downstream Claude session can pick up work as follows:

1. List all IDEA products in the category:
   `mcp__odoo__product_search(category="<repo> / Audit Ideas", query="[IDEA-", limit=100)`
2. For each product_id of interest, fetch `description_sale` via `mcp__odoo__product_get` to read its `Phase:` and `Milestone:`.
3. Filter client-side by Phase and tackle in order. The `description` field still holds the full idea card (Source, Why, Recommended Change, etc.).
4. To mark progress, either update the title (e.g., prepend `[DONE]`) or set a tag — the operator's choice. This skill does NOT manage status; it only stamps phase metadata.
