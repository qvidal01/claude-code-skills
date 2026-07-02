---
name: audit
description: Produce a stack-adaptive, describe-only snapshot of the current repo — module map, risks, unknowns — feeding the /ideate and /roadmap pipeline. Use when the user wants to understand what's in a repo, baseline a codebase, or kick off the audit→ideate→roadmap pipeline.
---

# /audit — Repo Snapshot (Describe-Only)

**Prompt version:** 1.0.0
**Pipeline version:** 1.4.1

You are acting as a **senior staff engineer performing a cold-read audit**. Your job is to describe what exists, not to recommend, fix, or grade.

## When To Use

- "what's in this codebase?"
- "baseline this project"
- "map this codebase / give me a module map"
- "kick off the audit pipeline"
- Before /ideate or /roadmap — this is the first stage that produces the audit-YYYY-MM-DD.md artifact they consume

## When NOT To Use

- You want evidence-grounded feature ideas → use /ideate (requires this audit first)
- You want a phased delivery plan → use /roadmap
- You only want a dependency/CVE scan → use /audit-deps

## Before anything else

1. **Read the shared header** at `~/.claude/pipeline/header.md`. It is authoritative — this skill body extends it, never contradicts it.
2. **Read the target repo's `CLAUDE.md` if present.** Precedence: repo CLAUDE.md > header > this file.
3. **Confirm arguments:**
   - `depth: scan | deep` (default: `scan`)
   - If the user didn't specify, ask once, then proceed with `scan`.

## Header Dependency

This skill reads `~/.claude/pipeline/header.md` for shared pipeline rules. That file contains:
- §1: Role definition
- §2: Stack detection rules
- §3: CLAUDE.md precedence
- §4: Frontmatter format
- §5: Finding ID format (RISK-###, UNK-###)
- §6–§8: Output formatting
- §9: Refusal rules
- §10: Line limit (500 lines per artifact)
- §11: Required output sections

**If header.md is missing or unreadable:** use the inline fallbacks defined throughout this skill. Do not abort — proceed with inline rules and note "header.md unavailable" in the output frontmatter under `notes`.

## Invocation

```
/audit                     # defaults to depth: scan
/audit depth:deep
/audit depth:scan --force-stale   # re-run even if recent audit exists
```

## Phase 0 — Environment sanity

Run in order. Do NOT skip. Do NOT ask permission for read-only probes.

1. `git rev-parse HEAD` — capture the sha for frontmatter.
2. `git status --porcelain` — note if working tree is dirty (record in frontmatter).
3. Detect stack per header §2 — run `~/.claude/skills/_shared/detect-stack.sh [dir]` (shared with `/audit-deps` + `/harden-deps`) for a deterministic list. Record as `stack:` and `primary_stack:`. **Monorepo:** detect-stack is monorepo-aware — use `--json [dir]` to read each stack's `locations` (e.g. python at `["." , "backend"]`, node at `["frontend"]`) and reflect **all** tiers in the module map / `stack:` list, not just the repo root. A repo with a single primary stack at root is the common case; don't let it hide a second tier in a subdir.
4. Check for prior audit — `~/.claude/skills/_shared/dated-filename.sh --latest audit <repo>/.claude/pipeline` prints the most recent one (empty if none); read it and pull its IDs with `~/.claude/skills/_shared/extract-finding-ids.sh <that-file> RISK UNK` to preserve them.
5. Probe for tools you'll need with `command -v` before running them. Never assume presence. **Availability ≠ functionality:** if a probed tool is present but errors at runtime (wrong language version, broken toolchain), treat it as unavailable — degrade gracefully, record the gap as an `UNK-###`, and never block or abort the snapshot on it.

If the repo has no git, no recognized stack, and no source files, stop and report: "Nothing to audit — repo appears empty or uninitialized."

## Phase 1 — Discovery (both depths)

Gather these in parallel where possible. Run read-only commands only.

1. **Repo shape**
   - Top-level directory listing
   - LOC per module (`wc -l` on source files grouped by top-level dir)
   - Entry points (scripts in `package.json`, `pyproject.toml` `[project.scripts]`, `main.go`, etc.)
2. **Public API surface**
   - HTTP routes (grep for framework decorators: `@app.`, `router.`, `app.get`, etc.)
   - CLI commands (argparse/click/cobra definitions)
   - Library exports (`__init__.py`, `index.ts`, `mod.rs`)
3. **Dependency surface**
   - Direct deps count (production vs dev)
   - Lock file presence and last-modified
   - Pin style (exact vs range)
   - Do NOT run vulnerability scanners — that's `/audit-deps`.
4. **Test signal**
   - Test files count and location
   - Test framework detected
   - Coverage config presence (not coverage run — just config)
5. **Config & secrets surface**
   - Config files (`.env.example`, `settings.json`, `config.yaml`, etc.)
   - Env var references in code (grep `os.environ`, `process.env`, etc.)
   - Secrets-handling signals (keyring, vault, `.env`, hardcoded patterns — flag under Risks, do NOT quote values)
6. **Deploy & runtime surface**
   - Dockerfile, compose, k8s manifests, CI workflows
   - Health check endpoints

## Phase 2 — Deep extensions (only when `depth: deep`)

If and only if `depth: deep`:

7. **Data model** — infer primary data types / schemas from models, migrations, or DTOs.
8. **External integrations** — third-party API clients, webhooks, message queues.
9. **Observability** — logging/metrics/tracing presence and shape.
10. **Size outliers** — files over 500 LOC; functions over 50 LOC (sampled).
11. **Dead code signal** — exports with no references in the repo.

## Phase 3 — Risks

For each observed signal that represents a risk, produce a `RISK-###` entry. Categories:

- **Security** — exposed secrets, permissive CORS defaults, missing auth, injection surfaces.
- **Reliability** — single points of failure, in-memory state under horizontal scale, missing health checks.
- **Performance** — unbounded loops, N+1 patterns, synchronous expensive work in request path.
- **Maintainability** — oversized modules, duplicated logic, weak separation.
- **Testing** — untested critical paths, missing integration tests, coverage config gaps.
- **Operational** — missing logs/metrics, no rollback path, no health checks.

Each RISK entry (in `## Risks` section):

```
### RISK-00N — <one-line title>
- **Category:** Security | Reliability | Performance | Maintainability | Testing | Operational
- **Basis:** Evidence-Based | Assumption-Based
- **Signal:** <what was observed, with citation>
- **Scope:** <which module/path/surface>
- **Risk:** Low | Medium | High
- **Confidence:** Low | Medium | High
- **Citation:** <file:line or cmd:>
```

Do NOT recommend fixes. Do NOT rank beyond the Risk scale. Describe the signal.

## Phase 4 — Unknowns

Anything you could not determine — missing docs, opaque modules, ambiguous intent, unresolved config. File as `UNK-###`:

```
### UNK-00N — <question>
- **What's unclear:** <description>
- **Where to look:** <file/path/person to resolve>
- **Blocks:** <what downstream analysis this blocks>
```

Unknowns are load-bearing — they tell `/ideate` where confidence has to drop.

## Refusal rules (enforced)

Per header §9:

- **Do not** recommend fixes. If tempted, convert to a Risk or Unknown instead.
- **Do not** grade the codebase. No "excellent" / "poor" / quality scores.
- **Do not** speculate about author intent. "X is missing" is fine; "X was forgotten" is not.
- **Do not** run mutating commands. No installs, fixes, builds, tests, migrations.
- **Do not** exceed the depth's line cap (header §10).

## Output

Write to the path printed by `~/.claude/skills/_shared/dated-filename.sh audit <repo>/.claude/pipeline` (i.e. `<repo>/.claude/pipeline/audit-YYYY-MM-DD.md`) with:

1. Frontmatter per header §4 (including `depth`, stack list, HEAD sha, dirty flag if applicable).
2. Required H2 sections in this order (header §11):
   ```
   ## Summary
   ## Stack & Environment
   ## Module Map
   ## Dependency Surface
   ## Test & Coverage Signal
   ## Risks
   ## Unknowns
   ## Convention Conflicts
   ## Tools Run
   ## Appendix
   ```
3. **Summary** is 3–5 bullets only. No prose paragraphs.
4. **Module Map** is a table: module | LOC | purpose (inferred, one line) | entry points.
5. **Tools Run** lists every command invoked with its purpose (not output).
6. **Appendix** holds raw tool output if needed, collapsed under H3 subsections.

If a prior audit exists, preserve `RISK-###` / `UNK-###` IDs for findings whose underlying signal still holds. Mint new IDs only for new findings. Record any ID reassignment in `edit_log`.

## After writing

Report to the user:
1. Artifact path.
2. Line count vs. cap.
3. Top 3 risks by Risk level (just titles + IDs).
4. Count of unknowns.
5. Exact next command: `/ideate stage:<inferred>` — infer stage from signals (pre-launch if no deploy config + no tests; mature if versioned releases + CI + docs; in-use otherwise). User can override.

Do NOT auto-invoke `/ideate`. Stop after writing.
