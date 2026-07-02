---
name: draft-tests
description: Offload rote pytest generation to a local Ollama server. Ask a local coding model for a pytest draft for a specific module, then Claude reviews, polishes, and commits.
---

# /draft-tests — offload pytest drafting to a local model

**What this is:** a structured handoff so Claude uses a local Ollama server (`$OLLAMA_HOST`, default model `qwen2.5-coder:32b-instruct`) for the mechanical "write boilerplate pytest" work, and keeps Claude's own tokens for review, scoping, and fixing the invariably-wrong parts of the first draft.

**What this is not:** a replacement for Claude writing tests from scratch. Use for *additive* test coverage on a specific module where you already have an invariant in mind. For security-critical or tricky async tests, write them yourself.

## TRIGGER WHEN (use this checklist before invoking)

Use this skill only if ALL of the following are true:
- [ ] You have a concrete invariant or behaviour to test (not just "write tests for X")
- [ ] The module under test is NOT security-critical (auth, crypto, payments, RLS)
- [ ] The module calls ≤2 external services
- [ ] The Ollama server at `$OLLAMA_HOST` is reachable
- [ ] You are OK with Claude reviewing and possibly rewriting the draft

## When NOT To Use

- Security-sensitive code (auth, crypto, payments) — write tests manually
- Modules with complex integration dependencies — mock setup is non-trivial
- When you need 100% coverage specification (the draft is a starting point, not a spec)

## Invocation

```
/draft-tests <module-path> [focus]
```

Examples:
```
/draft-tests sentinel-core/app/services/compliance/scoring.py
/draft-tests sentinel-core/app/utils/pagination.py has_next and has_previous edge cases
/draft-tests sentinel-core/app/setup/state.py is_complete returning False after unlock
```

## Procedure

Follow these steps in order. Do not skip the review pass.

1. **Read the target module.** Confirm the file exists and is importable from pytest's current `testpaths = tests` root. If the module relies on external services (DB, Redis, ES), note that drafted tests may need mocking you have to add; include a one-line reminder when reporting back.

2. **Read one neighboring existing test** if one exists (grep for `test_<modulename>.py` under `tests/`) — use it to detect the project's test style (class-based vs function-based, fixture conventions, assertion style). Pass this stylistic context to the AI server in the prompt.

3. **Call the AI server.** The preflight check, the exact prompt/JSON payload, and
   saving the raw draft are deterministic — run the script (don't hand-type curl):

```bash
~/.claude/skills/draft-tests/scripts/draft.sh <module-path> [focus...]
```

   It preflights `:11434`, posts the fixed prompt to `qwen2.5-coder:32b-instruct`
   (override with `MODEL=...`), writes the raw draft to
   `/tmp/draft-tests-<module-basename>.py`, and prints that path on stdout. Exit
   code `3` = server unreachable → use the fallback below. The first call may take
   90–120s cold (GPU load); subsequent calls ~20–40s. Pass the style context you
   gathered in step 2 as the `[focus...]` argument.

4. **Review the draft.** Do NOT blindly commit. Check for:
   - **Wrong imports** — the 32B often hallucinates class/function names. Verify every `from X import Y` matches the actual module.
   - **Wrong field names** — e.g. `status="applicable"` when the real enum is `{"implemented", "partial", ...}`.
   - **Over-constrained assertions** — floating-point equality, mutation of shared module-level globals (`FRAMEWORKS[name] = ...` pattern is a red flag — rarely what you want).
   - **Missing async** — if the module is async, `asyncio_mode = auto` from pytest.ini makes the test function definitions need `async def`.
   - **Dead-end coverage** — tests that assert what the test itself set up (tautology); replace with tests of real invariants.

5. **Fix the draft.** Edit in place; this is now Claude's work. Keep the useful parts (method names, scenario framing), discard the wrong assertions.

6. **Run the tests locally.** `pytest tests/<new-file> -v`. If anything fails, decide: is the test wrong (fix) or the code wrong (open a separate MS-### task — don't bundle a code fix into a test-drafting commit).

7. **Report back to the user** with: what was drafted, what Claude rewrote, test count, passing count, and any real bugs surfaced during drafting. Do NOT commit the tests — leave them staged so the user reviews before commit.

## Model routing

| Task | Model | Why |
|---|---|---|
| pytest drafts (default) | `qwen2.5-coder:32b-instruct` | best code quality at reasonable latency |
| heavier reasoning (integration test flows, complex mocks) | `qwen3:32b` | better multi-step reasoning; 2x latency |
| prose-heavy tests (docstring-heavy describe/it style) | `llama3.3:70b` | better natural language but much slower |

Default is qwen2.5-coder; override only if the module's test shape is unusual.

## Cost / quality expectations

- **First draft: typically 60% usable.** Imports often wrong. Assertions often over-constrained. Coverage shape usually decent.
- **Time budget: ~3 minutes** (2min model + 1min your review & fix) vs ~15 minutes writing from scratch.
- **When NOT to use:** the module talks to 3+ external services (too much mocking to hand off), the logic is subtle (auth, crypto, race conditions — Claude must write these), the test pattern in the repo is unusual (the model won't match the local style).

## Fallback if the Ollama server is unavailable

```
curl -sS --max-time 5 "${OLLAMA_HOST:-http://localhost:11434}/api/tags" >/dev/null
```

If that fails: report to the user and write the tests yourself. Don't retry for more than 2 minutes.

## What this does NOT do

- It does NOT commit. Tests are staged for user review.
- It does NOT run the backend stack. If tests need Redis/ES/Postgres, operator runs them manually.
- It does NOT replace `/audit`, `/ideate`, `/roadmap`. Those stay on Claude because they need synthesis across the full repo context.
