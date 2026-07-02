#!/usr/bin/env bash
# find-prompt/scripts/search.sh — deterministic library resolution + ranked
# search. Encodes the "Locate the library" + "FIND" mechanics from SKILL.md so
# they run identically every time. Claude still does ADAPT (fill placeholders)
# and CAPTURE (save new prompts) — the judgment parts.
#
# Usage:
#   search.sh            # just resolve & print MY_PROMPTS_DIR
#   search.sh <term>     # resolve, then search personal/ (ranked first) + community/
# Honors $MY_PROMPTS_DIR override.
# Exit: 0 ok | 5 library not found on this machine
set -uo pipefail

# --- Locate the library (override -> common locations -> search) ---
MP="${MY_PROMPTS_DIR:-}"
if [ -z "$MP" ] || [ ! -d "$MP/prompts" ]; then
  for d in "$HOME/projects/my-prompts" "/aidata/projects/my-prompts" \
           "$HOME/my-prompts" "$HOME/Projects/my-prompts"; do
    [ -d "$d/prompts" ] && { MP="$d"; break; }
  done
fi
if [ -z "$MP" ] || [ ! -d "$MP/prompts" ]; then
  MP="$(find "$HOME" /aidata -maxdepth 4 -type d -name my-prompts \
        -exec test -d '{}/prompts/community' \; -print 2>/dev/null | head -1)"
fi
if [ -z "$MP" ] || [ ! -d "$MP/prompts" ]; then
  echo "my-prompts not found on this machine." >&2
  echo "  -> clone your prompts repo, then export MY_PROMPTS_DIR=<path>" >&2
  exit 5
fi
echo "MY_PROMPTS_DIR=$MP"

[ $# -ge 1 ] || exit 0
TERM_Q="$*"

# ripgrep if present, else grep -rin
if command -v rg >/dev/null 2>&1; then SEARCH(){ rg -il "$TERM_Q" "$1" 2>/dev/null; }
else SEARCH(){ grep -riln "$TERM_Q" "$1" 2>/dev/null | sed 's/:[0-9]*:.*$//' | sort -u; }; fi

echo; echo "### personal/ (rank highest)"
SEARCH "$MP/prompts/personal/" | sed "s#^$MP/##" || true
echo; echo "### community/"
SEARCH "$MP/prompts/community/" | sed "s#^$MP/##" || true
echo; echo "(present top 3-5 to the user with a one-line gist; show full body only for the pick)"
