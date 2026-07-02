# claude-code-skills

A curated collection of production [Claude Code](https://claude.com/claude-code) skills — extracted from a private, daily-use collection of 100+ skills and scrubbed for public release. Every skill here is battle-tested in real workflows, not written as a demo.

## What's a skill?

A skill is a `SKILL.md` (plus optional `scripts/` and `references/`) that Claude Code loads on demand — either invoked by the user as `/skill-name` or triggered automatically when a task matches its description. Good skills encode *judgment*: when to trigger, when **not** to, what to verify, and where deterministic scripts beat model improvisation.

## Install

Copy any skill directory into your skills folder:

```bash
git clone https://github.com/qvidal01/claude-code-skills.git
cp -R claude-code-skills/<skill-name> ~/.claude/skills/<skill-name>
```

Or clone the whole thing and symlink the ones you want.

## The skills

### Product pipeline (audit → ideate → roadmap)

A chained, artifact-gated pipeline for turning an unfamiliar repo into a phased plan. Each stage hard-gates on the previous stage's artifact so ideas stay evidence-grounded.

| Skill | Purpose |
|---|---|
| [`audit`](audit/) | Stack-adaptive, describe-only repo snapshot: module map, risks (RISK-###), unknowns (UNK-###) |
| [`ideate`](ideate/) | Feature ideas that must cite audit findings or file/line evidence |
| [`roadmap`](roadmap/) | Sequence ideas into phased milestones with falsifiable exit criteria |
| [`featurate`](featurate/) | Product-level ideation with evidence and exploratory modes |
| [`sync-features`](sync-features/) / [`sync-ideas`](sync-ideas/) / [`sync-roadmap`](sync-roadmap/) | Project pipeline artifacts into a PM tool (dry-run first, never silently applies) |

### Verification & shipping

| Skill | Purpose |
|---|---|
| [`done-check`](done-check/) | Take a "this is finished" claim and verify it with live evidence — separates *code is present* from *it actually works* |
| [`ship`](ship/) | Push → ensure PR → watch CI → merge the moment checks are green (and know when "green" isn't enough) |
| [`git-status-all`](git-status-all/) | Sweep every repo for uncommitted/unpushed work before switching machines |
| [`web-perf`](web-perf/) | Web performance auditing |

### Dependency hygiene

| Skill | Purpose |
|---|---|
| [`audit-deps`](audit-deps/) | Run the native vulnerability scanner for the detected stack, describe-only |
| [`harden-deps`](harden-deps/) | The remediation counterpart — fix what audit-deps found |

### Local-LLM offload

A pattern for hybrid economics: Claude stays in the orchestrator seat (scoping, review, integration) while a local Ollama model does the mechanical drafting.

| Skill | Purpose |
|---|---|
| [`draft-tests`](draft-tests/) | Local model drafts pytest boilerplate; Claude reviews, fixes, and commits |
| [`offload-code`](offload-code/) | The general version: rote code/prose drafting via a self-hosted AI gateway |

### Cloudflare knowledge packs

Retrieval-first skills that bias Claude toward live Cloudflare docs over pre-trained knowledge, with curated reference notes.

| Skill | Purpose |
|---|---|
| [`cloudflare`](cloudflare/) | Platform-wide: Workers, KV, D1, R2, Tunnel, WAF, IaC |
| [`wrangler`](wrangler/) | CLI-specific deploy/dev commands |
| [`workers-best-practices`](workers-best-practices/) | Workers patterns and pitfalls |
| [`durable-objects`](durable-objects/) | Per-entity state, RPC, alarms, WebSockets |
| [`agents-sdk`](agents-sdk/) | Stateful agents, durable workflows, real-time apps |
| [`sandbox-sdk`](sandbox-sdk/) | Cloudflare Sandbox SDK |
| [`cloudflare-email-service`](cloudflare-email-service/) | Transactional email: sending, routing, deliverability |

### Architecture patterns

| Skill | Purpose |
|---|---|
| [`byok-tiered-client`](byok-tiered-client/) | Decision framework for free-tier + BYOK + account-sync client architectures |

### Project skills (real examples)

Dev skills wired to public repos, included as working examples of project-scoped skills:

| Skill | Repo |
|---|---|
| [`qrcode-api`](qrcode-api/) / [`qrcode-test`](qrcode-test/) | [qrcode](https://github.com/qvidal01/qrcode) |
| [`bible-games-dev`](bible-games-dev/) | [bible-games](https://github.com/qvidal01/bible-games) |
| [`watsonx-vision-toolkit-dev`](watsonx-vision-toolkit-dev/) | [watsonx-vision-toolkit](https://github.com/qvidal01/watsonx-vision-toolkit) |
| [`report-api`](report-api/) | [report-generator](https://github.com/qvidal01/report-generator) |

### Utilities

| Skill | Purpose |
|---|---|
| [`find-prompt`](find-prompt/) | Search, adapt, and save prompts from a personal prompt library repo |

## Conventions these skills follow

- **TRIGGER WHEN / DO NOT USE WHEN** blocks in every description — the model needs negative space as much as positive
- **Deterministic steps live in `scripts/`**, not in prose the model re-improvises each run
- **Describe-only vs. apply** is always explicit; nothing mutates state silently
- **Verification over assumption** — skills that check things demand live evidence, not memory

## License

MIT — see [LICENSE](LICENSE).
