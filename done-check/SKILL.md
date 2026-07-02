---
name: done-check
description: "Take a CLAIM that work is finished — from a prior Claude session, a PR/commit message, a roadmap done-marker, or your own 'did the last session actually do this?' — and produce a per-claim verdict (✅ COMPLETE / ⚠️ PARTIAL / ❌ BROKEN) backed by LIVE evidence, never by assumption. Always separates 'code is present' from 'it actually works at runtime'. Read-only and non-destructive by default; any controlled test record (Odoo contact/lead, subscriber, calendar event, file) is cleaned up and the cleanup is confirmed. TRIGGER WHEN: 'verify the integrations/wiring from a prior session are actually complete', 'is X actually done / working / deployed', 'did the last session finish what it claimed', 'assess the readiness of this project', 'confirm this PR/feature is really wired up', 'check live state, don't assume'. DO NOT USE WHEN: answering a static infra fact like an IP/port/LXC (use verify-infra), confirming one specific deploy landed (use verify-deploy / sentinel-pilot-verify), running the app to eyeball a change (use verify), or reviewing a code diff for bugs (use code-review)."
---

# Done Check

Closes the **"a previous AI session said it was done, so now I have to go check"** loop.
A session (or a PR body, or a roadmap "✅ MS-007 complete") asserts something is wired up
and working. This skill **earns that verdict with evidence** instead of trusting the claim.

The deliverable is always two things per claim: the **VERDICT** and the **EVIDENCE** that
produced it. Never present a verdict you did not personally observe this run.

## The one rule that matters most

**Code-present ≠ runtime-working.** The most common false "done" is code merged + config
present, but the integration fails live (stale credential, wrong env, unreachable host).
Always push past "the code is there" to "I made it run and observed the result."
> Real example: a contact form's `createLead` was on `main`, deployed, and all `ODOO_*`
> env vars were present — yet every submission silently failed because the deployed API key
> no longer authenticated. Only a live POST + reading the server log surfaced it.

## Step 1 — Restate the claim as atomic, checkable assertions

Break the "it's done" claim into the smallest independently-verifiable pieces. Vague claims
("the integration is wired") become concrete ones:
- (a) the code is on the target branch / merged
- (b) it is actually deployed (the running artifact contains it)
- (c) required config/secrets are present AND valid
- (d) end-to-end, the expected side effect actually occurs

Each assertion gets its own verdict. A claim is only ✅ when **every** assertion is ✅.

## Step 2 — Verify each assertion against live state

Pick the cheapest **authoritative** check for each. Prefer ground truth over inference.

| Assertion type | Verified by |
|---|---|
| On branch / merged | `git log`, `gh pr view <n> --json state,mergedAt` |
| Actually deployed | grep the **running** bundle/binary on the host (`pct exec`, ssh) — not the repo |
| Service up | `systemctl is-active`, `docker ps`, port `ss -ltnp` |
| Config/secret present | `grep -c '^KEY=.'` (presence only — never print secret values) |
| Config/secret **valid** | exercise it (authenticate, call the API) — presence is not validity |
| Route/page healthy | `curl -s -o /dev/null -w '%{http_code}'`, check headers, browser console for JS/asset errors |
| DB / data state | direct SQL (`psql`), or the system's own API/MCP, returning record IDs as proof |
| Business record (Odoo) | query live via the odoo-crm MCP; cite the record id + a clickable web URL |

Distinguish **expected** redirects/404s from failures (a 303→login on a protected route is
correct; a 404 on a route that should exist is not).

## Step 3 — Prefer a controlled end-to-end test, then clean up

When (d) is in doubt, *run the real path* rather than read the code:
- Drive it through the actual entry point (a local POST to the running service, an MCP call,
  the live form) with a clearly-marked test payload (e.g. `ZZVERIFY-…`, `…@example.com`).
- Confirm the side effect on the far end (record created, file written, event appears).
- **Delete every test artifact** you created — across *all* systems it touched (Odoo
  partner+lead, mailing-list subscriber, calendar event, temp files) — and re-query to
  confirm zero remain. State the cleanup in the report.
- For Odoo records, prefer the guarded MCP tool **`crm_delete_test_record(model, record_id,
  confirm_marker)`** (crm.lead / res.partner only; refuses unless the record contains your
  marker AND looks like test data) over raw XML-RPC `unlink` — it makes cleanup first-class
  and refuses to touch real data.

## Guardrails (non-negotiable)

- **Read-only / non-destructive by default.** No deletes of real data, no settings changes.
- **No outward-facing actions** (no emails/messages/posts) unless the user explicitly approves.
- **Never enter or print credentials.** Check presence/validity without exposing values.
- **Any test record you create, you delete** — and you confirm the deletion.
- If something contradicts the claim, **report it plainly** with the evidence; do not soften.

## Step 4 — Report

Finish with a table and a blunt callout of anything NOT actually working:

| # | Claim | Verdict | Evidence | Next step |
|---|---|---|---|---|

Then one line per gap: the exact next action to close it. End with the cleanup confirmation.

## Remote-host specifics

- When claims involve services on remote hosts, verify against the live host (SSH, container
  exec, or health endpoint) — not against memory or docs; facts drift.
