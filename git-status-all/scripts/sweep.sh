#!/usr/bin/env bash
# git-status-all/scripts/sweep.sh — the deterministic sweep of ~/projects for repos
# that are dirty, have unpushed commits, or have untracked files. Replaces the two
# inline for-loops in the skill. Claude reads the output and suggests commit/push/
# gitignore actions (the judgment step).
#
# Usage:
#   sweep.sh                 # sweep ~/projects
#   sweep.sh <dir>           # sweep another parent dir
#   sweep.sh --dirty-only    # only print repos that need attention
# Exit: 0 always (it's a report)
set -uo pipefail

root="$HOME/projects"
dirty_only=0
for a in "$@"; do
  case "$a" in
    --dirty-only) dirty_only=1 ;;
    *) root="$a" ;;
  esac
done

for dir in "$root"/*/; do
  [ -d "$dir/.git" ] || continue
  name=$(basename "$dir")
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  status=$(git -C "$dir" status -s 2>/dev/null)
  unpushed=$(git -C "$dir" log --branches --not --remotes --oneline 2>/dev/null)

  mod=$(printf '%s\n' "$status" | grep -cE '^ ?[MADRC]' || true)
  untracked=$(printf '%s\n' "$status" | grep -c '^??' || true)
  nunpushed=$(printf '%s\n' "$unpushed" | grep -c . || true)

  if [ "$dirty_only" = 1 ] && [ -z "$status" ] && [ "$nunpushed" -eq 0 ]; then
    continue
  fi

  printf '=== %s [%s] — %s changed, %s untracked, %s unpushed ===\n' \
    "$name" "${branch:-?}" "$mod" "$untracked" "$nunpushed"
  [ -n "$status" ] && printf '%s\n' "$status"
  [ "$nunpushed" -gt 0 ] && { echo "  unpushed:"; printf '%s\n' "$unpushed" | sed 's/^/    /'; }
done
