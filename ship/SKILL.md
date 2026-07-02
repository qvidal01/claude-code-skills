---
name: ship
description: "Push the current branch, ensure a PR exists, watch CI, and merge the moment all required checks are green — the 'watch the checks and merge if green' tail that /commit doesn't cover. TRIGGER WHEN: 'merge it once green', 'watch CI and merge when green', 'merge the PR once checks pass', 'enable auto-merge once checks pass', 'merge #N when green', 'push and open a PR then merge when green'. DO NOT USE WHEN: just creating a commit (use /commit), reviewing the diff (use /code-review), or the user wants to merge a red/failing PR right now (do that directly with gh, don't pretend it's green)."
---

# Ship

Take a branch from "work is done" to "merged" without babysitting: push → ensure PR → watch CI →
merge when green. This is the repeated tail the user types as *"watch the checks and merge if green"*
across every repo. `/commit` makes the commit; `ship` lands it.

## 1. Run the scripted half

```bash
~/.claude/skills/ship/scripts/ship.sh            # current branch: push if needed, watch checks, merge when green
~/.claude/skills/ship/scripts/ship.sh --status   # report check state only — DON'T merge
~/.claude/skills/ship/scripts/ship.sh 119         # operate on PR #119 (or a branch name)
~/.claude/skills/ship/scripts/ship.sh --push      # push current branch only
```

It `git fetch`es origin first (so the base / ahead-behind checks are never against a stale tracking
ref — the failure mode that absorbed foreign commits into a docs PR once). It refuses to ship from
the default branch, creates a PR with `--fill` if none exists, polls
`gh pr checks` every 20s (up to 40m), and merges (`--squash --delete-branch`) only when **every
non-ignored check has concluded successfully**. Default merge is a **merge commit**
(`--merge --delete-branch`). Exit codes: `0` merged, `3` a required check failed (does NOT merge),
`4` timed out with checks still pending.

Useful env knobs (prefix the command):
- `IGNORE_CHECKS="e2e,Cypress"` — advisory checks to exclude from the green gate (see §3).
- `MERGE_METHOD=merge|squash|rebase` (default `merge`).
- `ADMIN=1` — bypass branch protection (`gh pr merge --admin`); only when the user says so.
- `DELETE_BRANCH=0` — keep the head branch.

## 2. The judgment half — review bots (not scriptable)

CI checks ≠ the whole story. Before merging, glance at the review-bot verdicts the script can't
read: **CodeRabbit, Gemini Code Assist, ChatGPT Codex, Claude** (and Cypress/Vercel/Cloudflare
where present). If a bot has **requested changes** or left an unresolved blocking comment, surface
it and ask before merging — "green CI" but "Codex requested changes" is not ready. The user often
says *"merge it once Codex clears"* — honor that: wait on the named bot, not just CI.

## 3. Per-repo conventions

- Check the repo's CLAUDE.md for known-broken or non-required checks (e.g. an E2E suite that never
  passes in CI) — put those in the `IGNORE_CHECKS` list and treat their red as expected, never
  block on them.
- If the repo has CD wired to the default branch, **merging = deploying**. When the user asks to
  merge *and* verify the deploy, ship is only step one — chain into deploy verification afterward,
  don't stop at MERGED.
- The default branch is detected per-repo (`gh repo view`), so this works in any repo.

## 4. Sequencing & chaining

The user frequently batches: *"merge #109 when green, then take #780"*, *"merge them in that order
once CI passes"*. Run `ship.sh <PR>` per PR **in the stated order**, waiting for each to merge before
starting the next (a later PR may depend on the earlier one landing). After a merge that triggers a
deploy, hand off to the matching verify step rather than reporting "done."

## 5. Report back

State the outcome plainly: which PR, merge method, what was ignored and why, and — if it didn't
merge — exactly which check failed and the command to inspect it (`gh run view --log-failed`). Never
report "merged" unless the script printed `RESULT: MERGED`.
