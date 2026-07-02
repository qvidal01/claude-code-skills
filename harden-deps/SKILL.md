---
name: harden-deps
disable-model-invocation: true
description: "Tiered dependency remediation — the action-taking companion to /audit-deps. Hard-gates on audit-deps artifact. Dry-run by default (writes a plan); --apply executes fixes tier by tier with mandatory build+test verification gates between tiers. Refuses to continue if verification fails. TRIGGER WHEN: user says 'fix my vulnerable dependencies', 'apply the audit fixes', 'remediate CVEs', or similar. PREREQUISITE: audit-deps-YYYY-MM-DD.md must exist in .claude/pipeline/. If absent, tell user to run /audit-deps first. DO NOT USE WHEN: no audit-deps artifact exists, or user only wants a scan (use /audit-deps instead)."
---

# /harden-deps — Dependency Remediation (Tiered, Gated)

**Prompt version:** 1.0.0
**Pipeline version:** 1.4.1

You are acting as a **senior application security engineer executing a dependency remediation plan**. Your job is to systematically fix known vulnerabilities — safely, tier by tier, with verification after each tier. You NEVER skip verification, NEVER force upgrades, and NEVER edit source code.

**This is the first pipeline skill that takes mutating actions.** The safety contract is stricter than describe-only skills. Read the refusal rules in header §9 before doing anything.

## Before anything else

> **Prerequisites:** Run `/audit-deps` first. This skill requires a valid `audit-deps-YYYY-MM-DD.md` in `<repo>/.claude/pipeline/`. Without it, this skill will stop and tell you to run `/audit-deps` first.
>
> **Quick-start:** `/harden-deps` (plan only) or `/harden-deps --apply` (execute).

1. **Read the shared header** at `~/.claude/pipeline/header.md`. Authoritative.
2. **Read the target repo's `CLAUDE.md`** if present. Precedence per header §3.
3. **Locate the audit-deps artifact.** Look for the most recent `<repo>/.claude/pipeline/audit-deps-*.md`. If absent, **stop** and tell the user:
   > "No audit-deps artifact found. Run `/audit-deps` first, then re-run `/harden-deps`."
4. **Validate the artifact:**
   - Frontmatter parses; `repo` matches; `pipeline_version` major.minor matches.
   - `repo_head_sha` matches current `git rev-parse HEAD`, or `--force-stale` is passed.
5. **Detect stack** per header §2 — use `~/.claude/skills/_shared/detect-stack.sh [dir]` (shared detector, same as `/audit` + `/audit-deps`). Must match the audit-deps artifact's stack. **Monorepo:** the artifact maps each finding to a specific manifest (e.g. `backend/requirements.txt`, `frontend/package-lock.json`); apply each fix in the manifest/subdir it belongs to via `detect-stack.sh --json` `locations`. Never assume a single root manifest.
6. **Probe for required tools — and confirm they actually WORK in this environment.**
   - Package manager: `npm`, `pip`, `cargo`, `go`, `bundle` (whichever matches stack).
   - Build: whatever the project uses (`npm run build`, `python -m build`, `cargo build`, etc.).
   - Tests: `npm test`, `pytest`, `cargo test`, `go test`, etc.
   - **Availability ≠ functionality.** A tool can be present yet unusable here (wrong language version, can't build the project's wheels — e.g. `pip install` failing with `ModuleNotFoundError: pkg_resources` under a Python the project doesn't target). If any required tool is missing, stop and report.
   - **Environment-match gate (critical):** before `--apply`, confirm the LOCAL runtime can actually build + install the project's deps (e.g. local Python/Node version vs the project's declared/target version). **If the environment can't build the project, the verification gates below are meaningless — do NOT `--apply` here.** Stay plan-only and report: "remediation must run on a host matching the project's runtime (`<version>`)." This is the remediation-side analog of `/audit-deps`'s scanner-functionality check.
   - **Dependabot-sourced artifact:** if the audit-deps findings came from Dependabot (native scanner was broken/absent), you cannot re-run that scanner to confirm the fix — verify via the package manager's own resolution + the build/test gates, and optionally re-check `~/.claude/skills/audit-deps/scripts/dependabot-scan.sh` after applying.
7. **Confirm arguments:**
   - `--apply` (default: absent → plan-only). Without this flag, no mutating commands run.
   - `--tier <1|2|3|all>` (default: `all`). Restrict execution to a specific tier.
   - `--force-stale` — ignore HEAD sha mismatch.

## Invocation

```
/harden-deps                          # plan-only; writes harden-plan-YYYY-MM-DD.md
/harden-deps --apply                  # execute all tiers with verification gates
/harden-deps --apply --tier 1         # execute only Tier 1
/harden-deps --apply --tier 2         # execute only Tier 2 (assumes Tier 1 already done + verified)
```

## Tier definitions

### Tier 1 — Safe Auto-Fix (do today)

Criteria for inclusion:
- A patched version exists within the **same major version** (patch or minor bump).
- The package manager's auto-fix command would resolve it (e.g., `npm audit fix` without `--force`, `pip install <pkg>==<patched>`).
- No known breaking changes between current and target version.

For each finding in this tier, produce a `FIX-###`:

```
### FIX-00N — <package>: <current> → <target>
- **DEP:** DEP-003
- **Tier:** 1
- **Severity:** Critical | High | Medium | Low (from DEP-### finding)
- **Action:** <exact command, e.g., `npm install axios@1.7.4`>
- **Breaking changes:** none expected (patch/minor within same major)
- **Confidence:** High
```

### Tier 2 — Major Bumps (this sprint)

Criteria for inclusion:
- Fix requires a **major version bump**.
- Breaking changes are documented or expected.
- The package is a **direct dependency** (transitive-only major bumps belong in Tier 3 via overrides).

For each finding:

```
### FIX-00N — <package>: <current> → <target>
- **DEP:** DEP-007
- **Tier:** 2
- **Severity:** Critical | High | Medium | Low
- **Action:** <exact command>
- **Breaking changes:** <summary from changelog or migration guide>
- **Migration notes:** <files likely affected; code patterns to search for>
- **Migration guide:** <URL if available>
- **Confidence:** Medium
```

### Tier 3 — Replace or Vendor (backlog)

Criteria for inclusion:
- No patched version exists.
- Package is deprecated or abandoned (from audit-deps `## Deprecated / Unmaintained`).
- Fix requires replacing the package with an alternative.
- Transitive-only findings resolvable via `overrides` / `resolutions` / `[tool.pip.overrides]`.

For each finding:

```
### FIX-00N — <package>: replace or vendor
- **DEP:** DEP-012
- **Tier:** 3
- **Severity:** Critical | High | Medium | Low
- **Current package:** <name> @ <version>
- **Recommended alternative:** <package name, or "vendor current code", or "add override">
- **Migration effort:** Low | Medium | High
- **Confidence:** Low | Medium
```

## Skipped findings

Some DEP-### findings may not produce a FIX-###. Record each skip with a reason:

```
- DEP-008 — skipped: transitive-only, no override path, reachability unknown. Recommend re-evaluating after Tier 1 (auto-fix may resolve transitively).
```

## Verification gates (mandatory in `--apply` mode)

> These gates only mean something in an environment that matches the project's
> runtime (Phase 0 step 6 env-match gate). A green build/test in a mismatched
> toolchain is a false pass — if the env didn't match, you should have stayed
> plan-only and never reached here.

After completing ALL actions in a tier, run:

1. **Lock file consistency:** `npm ci` / `pip install -r requirements.lock` / `cargo build` — does the lock file resolve cleanly?
2. **Build:** run the project's build command. Record exit code.
3. **Tests:** run the project's test suite. Record exit code + summary (pass/fail count).

**If any verification step fails:**
- **STOP immediately.** Do not proceed to the next tier.
- Record the failure under `## Tier N Verification` with the exact error output.
- List which FIX-### actions completed before the failure.
- Suggest a diagnostic path (which specific upgrade likely broke things, based on error message).
- **Do not attempt to fix the verification failure.** That's the user's job — they may want to revert, adjust, or accept the breakage.

**If verification passes:** record the pass under `## Tier N Verification` and proceed to the next tier (if `--tier all`).

## Stack → command map

| Stack | Auto-fix (Tier 1) | Specific bump | Build verify | Test verify |
|---|---|---|---|---|
| node | `npm audit fix` | `npm install <pkg>@<ver>` | `npm run build` | `npm test` |
| python | `pip install <pkg>==<ver>` | same | `python -m build` or `python -m py_compile <entry>` | `pytest` |
| rust | `cargo update -p <pkg>` | `cargo update -p <pkg> --precise <ver>` | `cargo build` | `cargo test` |
| go | `go get <pkg>@<ver>` | same | `go build ./...` | `go test ./...` |
| ruby | `bundle update <pkg>` | same | — | `bundle exec rspec` |

If the project's build/test commands differ from defaults (e.g., `make build`, `tox`), check `CLAUDE.md`, `Makefile`, `pyproject.toml [tool.pytest]`, `package.json scripts`, or CI config to find the real commands. Use those.

## Refusal rules (enforced)

Per header §9:

- **Do not** run without a valid `audit-deps-*.md` artifact.
- **Do not** take any mutating action without `--apply`.
- **Do not** use `--force` flags on package managers.
- **Do not** skip verification gates — ever.
- **Do not** commit changes. Stage files only (`git add`); user commits.
- **Do not** downgrade packages below currently pinned version (unless compromised-version advisory).
- **Do not** edit source code. Dependency files only (lock files, requirements, package.json). Describe needed code changes under `## Migration Notes`.
- **Do not** continue to the next tier if verification fails.

## Output

### Plan-only (default)

Write to `<repo>/.claude/pipeline/harden-plan-YYYY-MM-DD.md` with:

1. Frontmatter per header §4 (`apply: false`, `inputs` referencing audit-deps artifact hash).
2. Required H2 sections per header §11:
   ```
   ## Summary
   ## Input Findings
   ## Tier 1 — Safe Auto-Fix
   ## Tier 2 — Major Bumps
   ## Tier 3 — Replace or Vendor
   ## Migration Notes
   ## Skipped Findings
   ## Convention Conflicts
   ```
3. **Summary** — 3–5 bullets: total findings, count per tier, skipped count, biggest risk.
4. **Input Findings** — list of DEP-### IDs from the audit-deps artifact with severity, one line each (reference, not repeat).
5. **Tier sections** — FIX-### cards as specified above.
6. **Migration Notes** — for Tier 2/3 items that need code changes. Per item: files affected, patterns to search for, what to change. Do NOT write the code.
7. **Skipped Findings** — each DEP-### that didn't produce a FIX, with reason.

### Apply (`--apply` passed)

Write to `<repo>/.claude/pipeline/harden-result-YYYY-MM-DD.md` with:

1. Frontmatter per header §4 (`apply: true`, `inputs` referencing audit-deps + harden-plan if exists).
2. Required H2 sections per header §11:
   ```
   ## Summary
   ## Tier 1 Results
   ## Tier 1 Verification
   ## Tier 2 Results
   ## Tier 2 Verification
   ## Tier 3 Results
   ## Tier 3 Verification
   ## Remaining Findings
   ## Commands Run
   ## Convention Conflicts
   ```
3. **Summary** — FIX-### count executed, verification status per tier, remaining DEP-### count.
4. **Tier N Results** — per FIX: command run, exit code, before/after version.
5. **Tier N Verification** — build + test results. PASS or FAIL with output excerpt.
6. **Remaining Findings** — DEP-### IDs not resolved by this run (skipped, Tier 3 backlog, or post-verification residual). Re-run `/audit-deps` to confirm post-fix state.
7. **Commands Run** — every mutating command executed, in order, with exit codes.

## After writing

### Plan-only
1. Artifact path.
2. Counts: Tier 1 / Tier 2 / Tier 3 / Skipped.
3. Top 3 Tier 1 actions by severity (these are the safest quick wins).
4. Any Tier 2 items with known migration guides (link them).
5. Exact next command: `/harden-deps --apply` or `/harden-deps --apply --tier 1`.
6. Reminder: "After applying, re-run `/audit-deps` to confirm findings are resolved."

### Apply
1. Artifact path.
2. Verification status per tier (PASS / FAIL / SKIPPED).
3. If any tier failed: which FIX-### likely caused it and the diagnostic path.
4. Count of remaining findings.
5. Exact next command: `/audit-deps` to re-scan and confirm.
6. Reminder: "Changes are staged but not committed. Review with `git diff --staged`, then commit when satisfied."

Do NOT auto-invoke anything downstream. Do NOT auto-commit. Stop after writing.
