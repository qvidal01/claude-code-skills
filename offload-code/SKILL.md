---
name: offload-code
description: Offload rote code/text drafting to a local AI gateway (e.g. qwen-coder-32b for code, llama-3.3-70b for prose). Claude frames the task, the local model drafts, Claude reviews and applies. Use for repetitive mechanical work — NOT for security-critical code, architecture decisions, or tasks where the wrong first draft is expensive.
---

# /offload-code — offload rote drafting to a local AI gateway

**What this is:** a structured handoff so Claude stays in the orchestrator role (scoping, reviewing, integrating) and ships the mechanical lift to a self-hosted AI gateway. Sibling to `/draft-tests`, broader scope.

**What this is not:**
- Not a replacement for Claude thinking. Claude MUST read the drafts and revise before applying.
- Not for anything security-critical, architecturally load-bearing, or where one-shot correctness matters. The local model is good, not infallible.
- Not a substitute for `/audit`, `/ideate`, `/roadmap` — those are Claude's judgment work.

## When to use

Good fits:
- Regenerate broken/rotted unit tests after a refactor (~20+ tests in a single file).
- Draft an ADR skeleton from an existing decision's bullet points.
- Split a 1000+ LOC module into submodules (generate the per-submodule skeleton; Claude wires imports).
- Write boilerplate: schema migrations, DTOs, config validators, markdown tables from structured input.
- Rewrite a doc paragraph for tone/clarity (llama-3.3-70b).

Bad fits:
- Middleware logic (auth, CSP, tenant routing).
- Security-sensitive validation.
- One-off production fixes where review latency matters more than volume.
- Tasks where Claude has all the context and the AI gateway would have less.

## Trigger Phrases

Load this skill when the user says:
- "generate [20+] tests for..."
- "draft boilerplate [schema / migration / CRUD]"
- "rewrite this doc / comment for clarity"
- "offload this to the AI server"
- "I need a first draft of [repetitive code]"
- Any task where mechanical repetition outweighs judgment

## When NOT To Use

- Tasks requiring security judgment (auth, crypto, RLS) — do NOT offload
- Code that touches production data migrations — review manually
- Tasks where the local-model server (`$OLLAMA_HOST`) is unreachable

## Invocation

```
/offload-code <model-hint> <target> <task>
```

Where:
- `model-hint` — `code` (→ `qwen-coder-32b`) or `prose` (→ `llama-3.3-70b`). Default `code` if omitted.
- `target` — the file or module the draft will land in (for read-context).
- `task` — one sentence: what the draft should produce.

Examples:
```
/offload-code code components/__tests__/Navigation.test.tsx regenerate failing tests to match current Navigation props
/offload-code prose docs/adr/003-<new>.md draft an ADR skeleton for the Odoo integration split (MS-007)
/offload-code code lib/integrations/odoo/client.ts extract auth+transport from lib/integrations/odoo.ts as a standalone module
```

## Procedure

Follow these steps in order. Do not skip the review pass.

### 1. Precheck

```
mcp__ai-gateway__ai_gateway_health
```

If `status != "healthy"` or `workers_ai: false`, stop and report — do not fall back to anything. The user explicitly chose the gateway as the offload path.

### 2. Gather context (Claude's job, not the model's)

- Read the target file if it exists. If it's a regeneration task, read the current file fully.
- Read 1–2 neighboring files the draft will need to match (e.g., if regenerating `Navigation.test.tsx`, also read the current `components/Navigation.tsx`).
- Identify the invariants: what must be true of the draft regardless of style (names, type signatures, imports, test framework, assertion style).

Do NOT outsource this step. The AI gateway doesn't have repo context — Claude provides it.

### 3. Call the AI gateway

Use `mcp__ai-gateway__ai_gateway_chat`:

```
mcp__ai-gateway__ai_gateway_chat(
  model: "qwen-coder-32b" | "llama-3.3-70b",
  system_prompt: <role + output rules>,
  message: <context + task + acceptance criteria>,
  max_tokens: 4000  # adjust based on draft size
)
```

**System-prompt template (code tasks):**
```
You are a senior TypeScript/React engineer drafting code for a
Next.js 16 + Zod v4 + Tailwind 4 project. Output ONLY valid code —
no markdown fences, no prose preamble, no trailing commentary.
Match the style of the files the user shows you (imports, spacing,
quote style, test framework). If you are uncertain about a name or
API shape, prefer the form shown in the user's context over
anything from training data.
```

**System-prompt template (prose tasks):**
```
You are a technical writer drafting ADRs and runbooks for this
project. Match the tone and structure of the examples shown.
Output ONLY the requested document content — no preamble, no
meta-commentary. Markdown format. Do not invent acronyms or
reference IDs (RISK-###, IDEA-###, MS-###) that the user did not
provide.
```

**Message template:**
```
Task: <one-line task statement from invocation>

Target file: <path>
(<new> | replacing existing content | appending)

Context — the file being changed (full):
```<lang>
<paste file contents>
```

Context — neighboring file(s) the draft must agree with:
```<lang>
<paste>
```

Invariants (these must hold in the draft):
- <invariant 1>
- <invariant 2>
- ...

Acceptance criteria:
- <criterion 1>
- <criterion 2>
- ...
```

Record the raw response at `/tmp/offload-<target-basename>.draft` for diffing against the final version.

### 4. Review the draft (Claude — required, never skipped)

Check systematically:
- **Hallucinated APIs** — does every import/function/method name actually exist in the repo?
- **Wrong type signatures** — if this is TypeScript, do the types match the target module's declarations?
- **Style drift** — quote style, semicolons, import order matching the neighbor files.
- **Tautological assertions** (tests only) — "assert what I set up" patterns.
- **Dead/placeholder code** — `// TODO`, `// implement me`, `throw new Error('not implemented')`.
- **Framework mismatches** — e.g., Jest idioms in a Vitest file, `render` from wrong library.

### 5. Revise in place

Claude edits the draft to fix the review findings. This is Claude's work and Claude owns it. Keep the useful scaffolding; replace the wrong parts.

### 6. Verify locally (when possible)

- For code: `npx tsc --noEmit` to catch type errors.
- For tests: `npm run test:run -- <file>` for the specific suite.
- For docs: read end-to-end; no tool verification.

If verification fails, fix and re-verify. Do not apply failing drafts.

### 7. Report back and stop

Say:
- What the gateway drafted (line count, rough shape).
- What Claude changed during review (the N fixes, categorized).
- Verification result (test count passing, typecheck clean, etc.).
- The diff location or staged state — **do NOT commit**. The user reviews before commit.

## Model routing

| Task kind | Model | Max tokens | Notes |
|---|---|---|---|
| Regenerate tests | `qwen-coder-32b` | 4000–8000 | Default code path. |
| Draft module/class skeleton | `qwen-coder-32b` | 4000 | Keep small; expand in revision. |
| Config/schema boilerplate (JSON, YAML) | `qwen-coder-32b` | 2000 | Cached well by the gateway. |
| ADR / runbook drafts | `llama-3.3-70b` | 3000–6000 | Better prose voice. |
| One-sentence rewrites, title suggestions | `llama-3.2-3b` | 500 | Cheap, fast, cached. |
| Short code explanation | `llama-3.1-8b` | 2000 | When prose AND code-aware needed. |

Prefer **qwen-coder-32b** for anything with code; prefer **llama-3.3-70b** for anything that is mostly prose. Route anything uncertain through the coder — fewer hallucinated identifiers.

## Caching

The gateway has `cache_enabled: true`. Identical prompts return cached responses. This means:
- Iterating on a prompt by tweaking the WHOLE prompt defeats the cache.
- For iterative refinement, use a short tweak at the END of the message (cacheable prefix stays stable).

## Safety contract

- Claude NEVER commits offloaded output directly. The user reviews the diff.
- Claude NEVER applies offloaded output to `middleware.ts`, `lib/auth.ts`, `lib/api-helpers.ts`, Stripe webhook handlers, or anything under `app/api/auth/` — even on an explicit request. Those are Claude's own work.
- Claude NEVER offloads a task where the first draft being wrong would ship silently (e.g., migration SQL, production config). Offload the draft, then Claude manually re-derives and compares.

## Failure modes and handling

| Symptom | Action |
|---|---|
| `workers_ai: false` in health | Stop, report — do not fall back. |
| Model returns markdown fences | Strip them; do not re-ask. |
| Model hallucinates a non-existent import | Replace with the correct one from the context you gave. If the wrong one leaks through review, treat as a learning moment and note it. |
| Model returns prose in a code-task | Re-ask with a stricter system prompt. If it happens twice, abandon the offload and do it yourself. |
| Gateway timeout | Retry once with shorter context. If it fails again, abandon and do it yourself. Do not spend Claude cycles on gateway debugging. |

## Boundary with `/draft-tests`

`/draft-tests` is Python-specific, pytest-specific, and assumes a pytest project layout. `/offload-code` is stack-agnostic. If you're drafting Python tests, prefer `/draft-tests` (purpose-built). For everything else — including TypeScript/React tests in this repo — use `/offload-code`.
