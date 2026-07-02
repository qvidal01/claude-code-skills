---
name: find-prompt
description: "Search the user's personal prompt library (the my-prompts repo) for a ready-made prompt, adapt it to the task at hand, and optionally save new prompts back to it. TRIGGER WHEN: 'find me a prompt for X', 'is there a prompt for ...', 'give me a prompt to ...', 'search my prompts', 'what prompt should I use for ...', 'save this as a prompt', 'add this to my prompts'. DO NOT USE WHEN: the user wants you to directly perform the task yourself (just do it), or is asking about Claude Code's own slash-commands/skills rather than chat-prompt templates."
---

# Find Prompt

Search, adapt, and grow the user's personal prompt library (the **my-prompts**
repo) — a curated collection seeded from [prompts.chat](https://prompts.chat)
plus the user's own prompts. The repo lives at a different absolute path on
different machines, so **always resolve its location first** (see *Locate the
library* below) and use that resolved path everywhere instead of a hardcoded one.

## When To Use
- "find me a prompt for <task>" / "is there a prompt for <X>?"
- "give me a prompt to <do something>"
- "what prompt should I use for <X>?"
- "search my prompts for <keyword>"
- "save this as a prompt" / "add this to my prompts library"

## When NOT To Use
- The user wants the task *done*, not a prompt template → just do the task.
- Questions about Claude Code's own skills/slash-commands → answer directly.

## Locate the library (do this first, every time)
The repo path varies by machine (e.g. `~/projects/my-prompts` on macOS,
`/aidata/projects/my-prompts` or `~/projects/my-prompts` on the WSL/Linux box).
Resolve it with this — it honors a `MY_PROMPTS_DIR` override, then checks the
common locations, then falls back to a search:
```bash
MP="${MY_PROMPTS_DIR:-}"
if [ -z "$MP" ] || [ ! -d "$MP/prompts" ]; then
  for d in "$HOME/projects/my-prompts" "/aidata/projects/my-prompts" \
           "$HOME/my-prompts" "$HOME/Projects/my-prompts"; do
    [ -d "$d/prompts" ] && { MP="$d"; break; }
  done
fi
# Last resort: search a couple of likely roots for the repo marker.
if [ -z "$MP" ] || [ ! -d "$MP/prompts" ]; then
  MP="$(find "$HOME" /aidata -maxdepth 4 -type d -name my-prompts \
        -exec test -d '{}/prompts/community' \; -print 2>/dev/null | head -1)"
fi
echo "MY_PROMPTS_DIR=$MP"
```
Run this **once** at the start, take the printed path, and use that absolute path
in every later command (each Bash call is independent — the variable won't
persist, so substitute the resolved path literally). If it prints nothing, the
repo isn't on this machine: tell the user, offer to clone their prompts
repo, and suggest they `export MY_PROMPTS_DIR=<path>` (or symlink) to
pin it. Then **stop**.

## Repo layout
```
<MY_PROMPTS_DIR>/
  prompts/community/<category>/<slug>.md   # ~1900 prompts from prompts.chat
  prompts/personal/<slug>.md               # the user's own prompts
  prompts/personal/_template.md            # frontmatter template for new prompts
  prompts/prompts.csv                      # community master data
  scripts/index_personal.py                # rebuilds personal/README.md
```
Categories under `community/`: development, data-and-analytics, writing-and-editing,
business-and-marketing, finance, education, language, career, creative-and-design,
health-and-wellness, lifestyle, expert-and-professional, roleplay-and-games,
productivity, general.

Each prompt file has YAML frontmatter (`title`, `source`, `category`/`tags`, …)
then a `# Heading` and the prompt body. Bodies use `${Variable:Default}`
placeholders.

## FIND — searching for a prompt

**Fast path:** the library-resolution + ranked search above is scripted —
`~/.claude/skills/find-prompt/scripts/search.sh <term>` resolves `$MP` (honoring
`MY_PROMPTS_DIR`), then prints `personal/` matches (ranked first) and `community/`
matches as clickable `prompts/...` paths. Exit 5 = library not on this machine
(it prints the clone hint — then stop). Run that, then do steps 3-4 below. The
manual steps remain as the contract:

1. Resolve `$MP` via *Locate the library* above; if nothing was found, stop there.
2. Search with ripgrep (fall back to `grep -rin` if `rg` is absent). Search
   titles, bodies, and tags. **Always search `personal/` first and rank those
   matches highest** — the user's own prompts beat community ones. Use the
   resolved absolute path:
   ```bash
   rg -il '<term>' "$MP/prompts/personal/"    # user's own — prioritize
   rg -il '<term>' "$MP/prompts/community/"   # community pool
   ```
   Broaden intelligently: try synonyms and the likely category folder
   (e.g. a "cold email" request → also skim business-and-marketing / writing).
3. Present the **top 3-5 matches** as a short list: title, which folder
   (personal vs. category), and a one-line gist. Cite each as a
   `prompts/...:line` path so the user can click it. Don't dump full bodies for
   every match — show the full body only for the one the user picks (or the
   single clear best match).
4. If nothing fits, say so plainly and offer to **draft a new one** (→ CAPTURE).

## ADAPT — tailoring the chosen prompt
When the user picks one (or there's an obvious single match):
- Print its full body, then offer an **adapted version** with the
  `${placeholders}` filled in for the user's actual task and the tone/scope
  adjusted. Keep the original intent; don't bolt on unrelated instructions.
- If the user gave enough context to use it immediately, just produce the
  ready-to-paste prompt.

## CAPTURE — saving a new prompt
When the user says to save a prompt (or a freshly drafted/adapted one is clearly
worth keeping), offer to add it to the library (resolve `$MP` first if you
haven't; run `make`/git from `$MP`):
1. Create `$MP/prompts/personal/<kebab-slug>.md` using `_template.md`'s shape:
   ```markdown
   ---
   title: "<Title>"
   source: self
   tags: [<tag>, <tag>]
   ---

   # <Title>

   <prompt body, with ${Variable:Default} placeholders where useful>
   ```
2. Reindex: `make personal` (or `python3 scripts/index_personal.py`).
3. The repo's pre-commit hook keeps indexes in sync, but committing/pushing is
   the user's call — **ask before `git commit`/`git push`**. Mention the file
   was created and offer to commit.

## Notes
- This is a **private** repo of mostly chat-style persona/instruction templates.
  Many community prompts are "act as X" templates aimed at chat assistants; pick
  ones that genuinely fit, and prefer the user's `personal/` prompts when close.
- Never delete or overwrite an existing prompt without explicit confirmation.
