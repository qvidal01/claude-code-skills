---
name: git-status-all
description: "Sweep every repo under ~/projects for uncommitted, unpushed, and untracked changes before backing up or switching machines. TRIGGER WHEN: 'check git status across all my projects', 'which repos have uncommitted changes', 'any unpushed commits anywhere', 'what do I need to commit before switching machines'. DO NOT USE WHEN: auditing a single repo's health (run git directly in that repo)."
---

# Git Status All

Check git status across all repositories in ~/projects to find uncommitted changes, unpushed commits, and untracked files.

Steps:
1. Run the sweep (deterministic — scripted):
   ~/.claude/skills/git-status-all/scripts/sweep.sh            # all repos under ~/projects
   ~/.claude/skills/git-status-all/scripts/sweep.sh --dirty-only   # only repos needing attention
   It prints, per repo: branch, # changed / untracked / unpushed, the `status -s` lines, and the
   unpushed commit list. (Pass a parent dir as arg 1 to sweep somewhere other than ~/projects.)

2. From the script output, summarize:
   - Projects with uncommitted changes (M, A, D files)
   - Projects with untracked files (?? files)
   - Projects that need attention

3. For each project with changes, show:
   - Project name
   - Branch name
   - Number of modified files
   - Number of untracked files

4. Suggest actions (judgment — this is the part to keep in Claude):
   - Projects that should be committed
   - Projects that should be pushed
   - Projects that might need .gitignore updates

This is useful for:
- Finding work in progress
- Ensuring all work is backed up
- Identifying projects that need cleanup
- Before switching machines (use with /claude-sync)
