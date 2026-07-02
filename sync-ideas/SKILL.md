---
name: sync-ideas
disable-model-invocation: true
description: "Projects the ideas-YYYY-MM-DD.md artifact into Odoo product records (one product per IDEA-###). Dry-run by default, writes a sync-plan artifact. Pass --apply for real writes, which produces a sync-result artifact. Idempotent — matches existing Odoo products by their [IDEA-###] title prefix. TRIGGER WHEN: 'sync ideas to Odoo', 'push ideation results to CRM', 'create Odoo tasks from ideas', after running /ideate. PREREQUISITE: ideas-YYYY-MM-DD.md must exist."
---

# /sync-ideas — Odoo Projection of Ideas Artifact

**Prompt version:** 1.0.0
**Pipeline version:** 1.4.1

You are acting as a **data-movement agent**. Your job is to project the ideas artifact into Odoo as a backlog. You are explicitly NOT a strategist, a curator, or an editor — sync is a projection, not a transformation.

## Prerequisites & When To Use

> **PREREQUISITE:** Requires `ideas-YYYY-MM-DD.md` from `/ideate`. Run `/ideate` first.

**Use when:**
- After `/ideate` completes and you want to push IDEA-### records to Odoo
- "sync ideas", "push to Odoo", "create CRM records from ideas"

## Validation (inline, no external file needed)

Before syncing, verify each idea record has:
- `IDEA-###` identifier
- title and one-paragraph description
- at least one `RISK-###` or `UNK-###` citation, or a direct file/line reference
- confidence: High / Medium / Low

If any field is missing, prompt the user rather than syncing an incomplete record.

## Before anything else

1. **Read the shared header** at `~/.claude/pipeline/header.md`.
2. **Read the target repo's `CLAUDE.md`** if present. Precedence per header §3.
3. **Locate the latest ideas artifact** — `~/.claude/skills/_shared/dated-filename.sh --latest ideas <repo>/.claude/pipeline` prints it (empty if absent). If absent, **stop** and tell the user:
   > "No ideas artifact found. Run `/ideate` first, then re-run `/sync-ideas`."
4. **Validate the artifact** per §5 of this file.
5. **Verify the Odoo MCP server is available.** Probe for `mcp__odoo__product_categories` (or equivalent tool). If the MCP server isn't reachable, stop and report — do NOT attempt a placeholder sync.
6. **Confirm arguments:**
   - `--apply` (default: absent → dry-run). When absent, the skill writes a sync-plan and performs no Odoo writes.
   - `--category-name <name>` (default: `<repo> / Audit Ideas`). Override the destination category.

## Invocation

```
/sync-ideas                                      # dry run; writes sync-plan-YYYY-MM-DD.md
/sync-ideas --apply                              # real writes; writes sync-result-YYYY-MM-DD.md
/sync-ideas --category-name "My Custom Category" # override category
```

## Design contract (non-negotiable)

- **Sync is idempotent.** Re-running with `--apply` must not duplicate products. Match existing Odoo products by exact `[IDEA-###]` prefix in title.
- **Sync is projection, not transformation.** Description content comes verbatim from the idea card fields. The skill does not rewrite, summarize, or "improve" idea text.
- **Sync is additive + updating.** Create missing products; update drifted products; never delete.
- **Sync is scoped.** Touches only products whose titles begin with `[IDEA-###]` inside the target category. Never modifies unrelated products.

## Validation of the ideas artifact

- Frontmatter parses.
- `repo` matches the current working directory's repo name.
- `pipeline_version` major.minor matches the header (patch differences are tolerated per §1 of header).
- `repo_head_sha` matches current `git rev-parse HEAD`, or `--force-stale` is passed.

If any check fails, stop and report the mismatch. Do NOT sync stale ideas silently.

## Phase 1 — Read current Odoo state

1. Call `mcp__odoo__product_categories` with the target category name. Record the `category_id` if it exists.
2. If the category does NOT exist:
   - In dry-run: record it as a planned create.
   - In `--apply`: call `mcp__odoo__product_create_category` with the target name. Record the new id.
3. Call `mcp__odoo__product_search` with `category = <name>` and parse the results. Build a map: `IDEA-### → {product_id, title, description_hash}`.

## Phase 2 — Compute diff

For each `IDEA-###` in the ideas artifact:

1. Construct the target title: `[IDEA-###] <title>` (exactly as in the artifact, stripping outer backticks/quotes).
2. Construct the target description: a plain-text version of the idea card (Category, Basis, Source, Observed Signal, Why, Recommended Change, Expected Impact, Effort, Confidence, Risk, Dependencies, Blocked-by-unknown if present, Status). Use the same field names and order as the ideate skill's idea card format — readable plain text, no markdown fences.
3. Look up the `IDEA-###` in the Odoo map:
   - **Not found** → planned create.
   - **Found, content matches** (exact title + description hash) → planned no-change.
   - **Found, content differs** → planned update.

Also detect **drift** — IDEA-### IDs present in Odoo but NOT in the current ideas artifact. Record under `## Manual Review (drift)`. Do NOT auto-archive or delete them. Common causes: user renamed an idea in Odoo; superseded idea that was later removed; old IDs from a previous pipeline run.

> **Shared classifier:** steps 2's *rendering* (idea-card → plain text) is yours,
> but the create/update/no-change/**drift** classification is mechanical and shared
> with `/sync-features` and `/sync-roadmap`. Render the desired cards to
> `[{id,title,body}]`, dump the `product_search` results to `[{product_id,name,description}]`,
> then run:
> ```bash
> ~/.claude/skills/_shared/odoo-sync-diff.py --desired desired.json --existing existing.json --field description
> ```
> It returns `{creates,updates,nochange,drift,manual_review}` as JSON — use that as the plan. The MCP create/update calls in Phase 3 stay yours.

## Phase 3 — Apply (only when `--apply`)

For each planned create, call `mcp__odoo__product_create` with:
- `name`: target title
- `product_type`: `service`
- `category`: target category name
- `sale_ok`: `false`
- `purchase_ok`: `false`
- `description`: target description text

For each planned update:
- If `mcp__odoo__product_update` is available, call it with the diff fields.
- Otherwise, log under `## Manual Review (drift)` with `action: update-tool-missing` and leave the product untouched.

Capture every response. If any call errors, record it under `## Errors`, continue with remaining items (do NOT abort the whole run on a single failure).

## Refusal rules (enforced)

Per header §9:

- **Do not** write to Odoo unless `--apply` is passed.
- **Do not** delete Odoo products, archive categories, or remove IDEA-### records that no longer appear in the ideas artifact. Flag under Manual Review (drift) for human decision.
- **Do not** rewrite, summarize, or "improve" idea text during projection.
- **Do not** touch products whose titles don't match the `[IDEA-###]` prefix pattern.
- **Do not** invent IDEA-### IDs or mint new ones — only reference IDs that exist in the ideas artifact.
- **Do not** exceed 200 lines in either the plan or the result artifact.

## Output

### Dry-run (default)

Write to `~/.claude/skills/_shared/dated-filename.sh sync-plan <repo>/.claude/pipeline` (i.e. `<repo>/.claude/pipeline/sync-plan-YYYY-MM-DD.md`) with:

- Frontmatter per header §4 (include `apply: false`, `inputs` referencing the ideas artifact hash).
- Required sections per header §11:
  ```
  ## Summary
  ## Planned Creates
  ## Planned Updates
  ## Planned No-Change
  ## Manual Review (drift)
  ## Tools Run
  ```
- **Summary** — 3 bullets: create count, update count, drift count.
- **Planned Creates** — list of IDEA-### titles that will be created.
- **Planned Updates** — per item: IDEA-###, which fields changed (title-only / description-only / both), old vs new hash.
- **Planned No-Change** — bullet list of IDEA-### IDs unchanged.
- **Manual Review (drift)** — Odoo products whose IDEA-### is no longer in the artifact; propose `action:` (e.g., `action: archive-candidate`, `action: rename-intended`).
- **Tools Run** — MCP tool invocations made (read-only in dry-run).

### Apply (`--apply` passed)

Write to `~/.claude/skills/_shared/dated-filename.sh sync-result <repo>/.claude/pipeline` (i.e. `<repo>/.claude/pipeline/sync-result-YYYY-MM-DD.md`) with:

- Frontmatter per header §4 (include `apply: true`, `inputs` referencing the ideas artifact + the sync-plan artifact if one exists).
- Required sections per header §11:
  ```
  ## Summary
  ## Created
  ## Updated
  ## No-Change
  ## Manual Review (drift)
  ## Errors
  ## Tools Run
  ```
- **Created** — per row: IDEA-###, Odoo product_id, category_id.
- **Updated** — per row: IDEA-###, Odoo product_id, fields changed.
- **Errors** — per row: IDEA-###, failure reason, raw error excerpt.
- **Tools Run** — every MCP call, its purpose, and whether it mutated state.

## After writing

Report to the user:

### Dry-run
1. Artifact path.
2. Counts: creates, updates, no-change, drift.
3. Sample of 3 planned creates and 3 planned updates (if any) — titles only.
4. Exact next command to apply: `/sync-ideas --apply`.
5. Flag any drift entries prominently.

### Apply
1. Artifact path.
2. Counts: created, updated, no-change, drift, errors.
3. Direct Odoo IDs for the newly created products (so the user can jump straight to them).
4. Error summary if non-empty.

Do NOT auto-invoke anything downstream. Stop after writing.
