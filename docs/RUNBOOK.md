---
runbook: true
repo: claude-code-skills
status: active
type: tool
updated: 2026-07-16
health: unknown
deploy: not deployed
next: review runbook
---

# claude-code-skills — Runbook

## Purpose

`claude-code-skills` is a curated public collection of production Claude Code skills. The README describes the repo as extracted from a private daily-use collection and scrubbed for public release.

The repository provides skill directories containing `SKILL.md` files, with optional `scripts/` and `references/` directories. Skills cover product planning, verification, shipping, dependency hygiene, local-LLM offload, Cloudflare knowledge packs, architecture patterns, project-scoped examples, and utilities.

## Stack

- Markdown-based Claude Code skills.
- Each skill is centered on a `SKILL.md` file.
- Some skills include `references/` documentation.
- Some skills may include deterministic `scripts/`, per README convention.
- License: MIT.

## Where it runs

Unknown as a deployed service. The README documents local installation into a Claude Code skills folder.

Installed skills run where Claude Code loads user skills from:

```bash
~/.claude/skills/
```

## Run / deploy

No deployment target is documented.

Install one skill from a clone:

```bash
git clone https://github.com/qvidal01/claude-code-skills.git
cp -R claude-code-skills/<skill-name> ~/.claude/skills/<skill-name>
```

The README also says the whole repository can be cloned and selected skills symlinked into the skills folder.

## Health & recovery

Health is unknown. No health check, CI status, runtime host, or recovery process is documented in the inspected repo files.

Recovery for local installation is limited to reinstalling a skill from the repository:

```bash
cp -R claude-code-skills/<skill-name> ~/.claude/skills/<skill-name>
```

## Current status

The most recent commit in `git log --oneline -30` is `7bbffa0 Initial public release: 29 curated Claude Code skills`, dated 2026-07-02. Because that is within 30 days of 2026-07-16, this runbook marks the repo as active. No TODO, NEXT_SESSION, existing docs, shipped/live note, deploy target, or newer status note was found.

## Links

- README: `README.md`
- License: `LICENSE`
- Public repo from README install command: `https://github.com/qvidal01/claude-code-skills.git`
