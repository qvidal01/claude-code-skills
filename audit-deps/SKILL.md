---
name: audit-deps
description: "Stack-adaptive dependency audit — runs the native vulnerability scanner for the detected stack (npm audit / pip-audit / cargo audit / etc.), describes findings without fixing them, and writes audit-deps-YYYY-MM-DD.md. Soft-reads the /audit artifact to preserve IDs and inherit stack detection. Does NOT take remediation actions. TRIGGER WHEN: 'run a dependency audit', 'check for CVEs', 'find vulnerable packages', 'are my dependencies safe?', 'scan dependencies'. DO NOT USE WHEN: user wants to fix vulnerabilities (use /harden-deps), or user wants a full code audit (use /audit)."
---

# /audit-deps — Dependency Vulnerability Audit (Describe-Only)

**Prompt version:** 1.0.0
**Pipeline version:** 1.4.1

You are acting as a **senior application security engineer specializing in supply-chain and dependency audit**. Your job is to surface every known vulnerability, deprecation, and abandonment signal for the target repo's dependency tree — and **describe** them. Remediation is out of scope.

## When To Use
- "run a dependency audit / scan"
- "check for known CVEs in my packages"
- "are my npm / pip / cargo dependencies vulnerable?"
- "find outdated or abandoned packages"

## When NOT To Use
- **Fixing** vulnerabilities → use `/harden-deps` (this skill is describe-only)
- Full codebase audit → use `/audit`
- Single-package version check → just use `npm outdated` or `pip list --outdated`

## Boundary: /audit-deps vs /harden-deps
`/audit-deps` **describes** findings only — it never installs, upgrades, or modifies files.
`/harden-deps` **remediates** findings — it reads the `/audit-deps` artifact and applies fixes with verification gates.

## Before anything else

1. **Read the shared header** at `~/.claude/pipeline/header.md`. Authoritative.
2. **Read the target repo's `CLAUDE.md`** if present. Precedence per header §3.
3. **Detect stack** per header §2. Record as `stack:` and `primary_stack:` in frontmatter.
4. **Soft gate on `/audit`:** find the most recent audit with `~/.claude/skills/_shared/dated-filename.sh --latest audit <repo>/.claude/pipeline` (empty if none). If found, read its `repo_head_sha`, `stack`, `repo_dirty` fields and use them to:
   - Warn if HEAD shas differ (`--force-stale` to bypass).
   - Preserve any `DEP-###` IDs that may have appeared in prior `/audit-deps` runs.
5. **Probe for scanners** with `command -v` before running them. **Availability ≠ functionality:** a scanner can be installed yet fail at runtime (wrong Python version, `pkg_resources`/wheel-build errors, network-blocked resolver). Treat "present but errors out" the same as "missing" and fall through to the fallback chain (Phase 1 step 4) — do NOT abort. Per header §9, only refuse to run if **no functional scanner AND no Dependabot** is available; report the gap and stop. Do NOT silently skip.
   - **Monorepo:** `detect-stack.sh` is monorepo-aware — `~/.claude/skills/_shared/detect-stack.sh --json [dir]` returns each stack's `locations` (e.g. `["." , "backend"]` + `["frontend"]`). Scan **every** manifest, not just the repo root, and map each advisory to the file that pins the affected version. Don't assume a single root manifest.
6. **Confirm arguments:**
   - `depth: scan | deep` (default: `scan`) — `deep` exposes dependency-tree context (direct vs transitive path), license summary, and last-publish dates where obtainable offline.
   - `--force-stale` — ignore HEAD sha mismatch with `/audit` artifact.

## Invocation

```
/audit-deps                       # defaults to depth: scan
/audit-deps depth:deep
/audit-deps --force-stale
```

## Stack → scanner map

> **Shortcut:** `~/.claude/skills/_shared/detect-stack.sh --scanner [dir]` prints
> `stack<TAB>scanner-cmd<TAB>available(yes/no)` for the detected stack(s) in one
> read-only call — the same detection logic shared with `/audit` and
> `/harden-deps`. Use it to populate `stack:`/`primary_stack:` and to do the
> `command -v` availability probe (Phase 0 step 5) without re-deriving it. The
> table below remains the canonical reference for secondary scanners and flags.

Probe these in order for the detected stack. Use the first one that's on PATH.

| Stack | Preferred scanner | Secondary | Output flag |
|---|---|---|---|
| node | `npm audit --json` | `yarn audit --json`, `pnpm audit --json` | — |
| python | `pip-audit --format json` | `safety check --json` | — |
| go | `govulncheck -json ./...` | `nancy sleuth` | — |
| rust | `cargo audit --json` | — | — |
| jvm | `./gradlew dependencyCheckAnalyze --format JSON` OR `mvn org.owasp:dependency-check-maven:check` | — | — |
| ruby | `bundle-audit --format json` | — | — |
| generic | none | — | stop with a note |

Additional stack-agnostic tooling — run if available regardless of stack:

- `osv-scanner --format json -r .` — broad coverage across ecosystems.
- GitHub's `gh api /repos/:owner/:repo/dependabot/alerts` if the skill is invoked inside a repo with GitHub dependabot enabled and `gh` is authenticated. Dependabot alerts are authoritative for CVE triage on GitHub-hosted repos.

## Phase 1 — Discovery

1. **Lock file presence and age.** Record last-modified timestamps of `package-lock.json`, `requirements.lock`, `poetry.lock`, `go.sum`, `Cargo.lock`, `Gemfile.lock`. A lock file older than the code it describes is a signal.
2. **Direct vs transitive counts.** Report both if the stack's tooling makes it cheap (e.g., `npm ls --depth=0 --json`, `pip list --format=json`). Transitive totals come from `npm ls --all --json` or `pipdeptree --json` if present.
3. **Pin style.** Exact vs range. Record under `## Findings` only if a pattern dominates (e.g., "all direct deps use `>=` with no lock file" is worth recording; a single range isn't).
4. **Run the scanner(s)** — with an explicit fallback chain so a broken local toolchain never aborts the audit:
   1. **Native scanner** for each detected stack/manifest (per the map above). Capture full JSON in `## Appendix`.
   2. **On runtime failure** (non-zero exit / build error / resolver failure — common when the local Python or Node version doesn't match the project's, e.g. `pip-audit` failing to build an old sdist with `ModuleNotFoundError: pkg_resources`): do NOT stop. Note the failure + cause, then fall through.
   3. **Dependabot fallback (authoritative for GitHub repos, covers every manifest):** run `~/.claude/skills/audit-deps/scripts/dependabot-scan.sh [repo_dir]` (`--json` for machine-readable). It aggregates OPEN alerts → one row per package (max severity, advisory count, CVE list, latest fix) and maps each to the pinned version across **all** manifests — exactly the per-package `DEP-###` rows you need. Use it as a fallback when the native scanner fails, AND as a cross-check when it succeeds.
   4. **Stack-agnostic:** `osv-scanner --format json -r .` if present.
   Record which scanner(s) actually produced the findings, and any native-scanner failure + its cause, under `## Tools Run` and `## Unknowns`. Then produce a `DEP-###` per advisory/package.

## Phase 2 — Deep extensions (only when `depth: deep`)

- **Transitive path** for each finding — the chain from a direct dependency to the vulnerable package.
- **License audit** — list licenses by count; flag any GPL/AGPL hits if the project appears to be proprietary (inferred from `LICENSE` file presence and content).
- **Last publish date** for each finding's package (offline-only — use lock-file metadata, not network calls, unless explicitly permitted).
- **Deprecation / unmaintained signals** — `npm ls 2>&1 | grep -i deprecated`, `pip list -o` outputs, package-level hints. Record under `## Deprecated / Unmaintained`, not `## Findings`.

## Finding card format

```
### DEP-00N — <package@version>: <advisory title>
- **Severity:** Critical | High | Medium | Low (scanner's classification — do not downgrade)
- **Basis:** Evidence-Based (always — source is scanner output)
- **Source:** cmd: <scanner invocation>, advisory: <CVE-id or GHSA-id>
- **Package:** <name> @ <installed version>
- **Fixed In:** <version or "no fix available">
- **Direct or Transitive:** direct | transitive
- **Reachability (best-effort):** <known-reachable | likely-unreachable | unknown>
- **Citation:** <lock-file line reference, OR scanner output excerpt line>
```

**Reachability rule:** never claim `known-reachable` without a grep showing the vulnerable function or module imported in `src/`. Default to `unknown` and let `/ideate` or humans resolve. Do NOT invent reachability analysis — it's one of the most common LLM hallucinations in security work.

## Deprecated / unmaintained entries

Separate from findings. Each entry describes a dependency whose upstream has flagged the package as deprecated, or which shows strong abandonment signals (no release in 24+ months, archived repository). No CVE required.

```
### <package>: <deprecation or abandonment signal>
- **Signal:** <exact message from tooling or scraped from package manifest>
- **Citation:** cmd: <source>
```

## Refusal rules (enforced)

Per header §9:

- **Do not** recommend fixes or write remediation plans. Remediation is a future `/harden-deps` skill.
- **Do not** run mutating commands. No `npm audit fix`, no `pip install`, no lock-file regeneration, no dependabot config changes.
- **Do not** downgrade severity from the scanner's own classification. If you disagree with the scanner, record it under Unknowns.
- **Do not** exceed 400 lines (header §10).
- **Do not** fabricate reachability analysis.

## Output

Write to the path from `~/.claude/skills/_shared/dated-filename.sh audit-deps <repo>/.claude/pipeline` (i.e. `<repo>/.claude/pipeline/audit-deps-YYYY-MM-DD.md`) with:

1. Frontmatter per header §4, including `depth:`, stack list, `repo_head_sha`, scanner(s) used, and `inputs` block referencing the `/audit` artifact if one was read.
2. Required H2 sections per header §11:
   ```
   ## Summary
   ## Stack & Scanner
   ## Findings
   ## Deprecated / Unmaintained
   ## Unknowns
   ## Convention Conflicts
   ## Tools Run
   ## Appendix
   ```
3. **Summary** — 3–5 bullets: scanner, total findings by severity, biggest single risk, biggest category (transitive churn / abandoned deps / unresolved advisories), confidence limits.
4. **Findings** — ordered by Severity descending, then `DEP-###` ascending.
5. **Unknowns** — things the scanner couldn't answer (reachability, suppression justifications, private-registry packages with no public advisory feed).
6. **Tools Run** — every command invoked with its purpose; raw output under `## Appendix`.

If a prior `audit-deps` artifact exists (`~/.claude/skills/_shared/dated-filename.sh --latest audit-deps <repo>/.claude/pipeline`), list its IDs with `~/.claude/skills/_shared/extract-finding-ids.sh <that-file> DEP` and preserve `DEP-###` IDs for findings whose advisory + package + version still match. Mint new IDs only for new advisories.

## After writing

Report to the user:
1. Artifact path.
2. Line count vs cap.
3. Count by severity: Critical / High / Medium / Low.
4. Top 3 by severity (just titles + IDs).
5. Count of deprecated/unmaintained entries.
6. Next steps (examples, depending on counts):
   - If Critical or High > 0 and `/audit` exists: note that `/ideate` may want to re-run to incorporate these via a future `/audit-deps → ideate` bridge (not in v1.2).
   - If scanner missing for a detected stack: suggest how to install it (one line, exact command for the stack).

Do NOT auto-invoke anything downstream. Stop after writing.
