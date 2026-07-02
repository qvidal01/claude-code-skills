#!/usr/bin/env bash
# ship.sh — push the current branch, ensure a PR exists, watch CI, and merge when green.
#
# Deterministic half of the `ship` skill. Designed to be safe-by-default:
#   - never merges until ALL non-skipped, non-ignored checks have concluded successfully
#   - ignores checks named in IGNORE_CHECKS (advisory bots / known-red gates)
#   - prints machine-readable status the model can fold into its summary
#
# Usage:
#   ship.sh [PR]                       # PR number or branch; default = current branch's PR
#   ship.sh --status [PR]              # report check state only, do not merge
#   ship.sh --push                     # push current branch (set upstream) only
#   ship.sh --merge [PR]               # watch checks then merge (default action)
#
# Env knobs:
#   MERGE_METHOD=merge|squash|rebase   (default: merge)
#   IGNORE_CHECKS="e2e,Cypress"        comma list of check-name substrings to treat as advisory
#   DELETE_BRANCH=1                    delete the head branch after merge (default: 1)
#   ADMIN=1                            pass --admin to gh pr merge (bypass branch protection)
#   POLL=20                            seconds between check polls (default: 20)
#   MAX_WAIT=2400                      max seconds to wait for checks (default: 40m)
set -euo pipefail

MERGE_METHOD="${MERGE_METHOD:-merge}"
DELETE_BRANCH="${DELETE_BRANCH:-1}"
POLL="${POLL:-20}"
MAX_WAIT="${MAX_WAIT:-2400}"
# Default advisory checks: this repo's E2E gate is non-required and never green (see CLAUDE.md).
IGNORE_CHECKS="${IGNORE_CHECKS:-e2e,E2E,Cypress,playwright}"

ACTION="merge"
ARG=""
for a in "$@"; do
  case "$a" in
    --status) ACTION="status" ;;
    --push)   ACTION="push" ;;
    --merge)  ACTION="merge" ;;
    -*)       echo "unknown flag: $a" >&2; exit 2 ;;
    *)        ARG="$a" ;;
  esac
done

command -v gh >/dev/null || { echo "FATAL: gh CLI not found" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "FATAL: gh not authenticated (run: gh auth login)" >&2; exit 1; }

CUR_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo main)"

# Refresh remote refs up front so every check below (ahead/behind, base freshness, the push) is
# against the real origin, never a stale tracking ref. Cheap, read-only, safe to always run.
git fetch -q origin 2>/dev/null || echo "WARN: git fetch failed — proceeding with possibly-stale refs" >&2

push_branch() {
  [ -n "$CUR_BRANCH" ] || { echo "FATAL: not on a branch" >&2; exit 1; }
  if [ "$CUR_BRANCH" = "$DEFAULT_BRANCH" ]; then
    echo "REFUSE: on default branch '$DEFAULT_BRANCH' — branch first, don't ship from main." >&2
    exit 1
  fi
  echo ">> pushing $CUR_BRANCH"
  git push -u origin "$CUR_BRANCH"
}

# Resolve a PR ref: explicit arg, else current branch's PR.
pr_ref() {
  if [ -n "$ARG" ]; then echo "$ARG"; return; fi
  echo "$CUR_BRANCH"
}

# Build a regex of ignored check substrings, e.g. (e2e|E2E|Cypress)
ignore_regex() {
  echo "$IGNORE_CHECKS" | tr ',' '\n' | sed '/^$/d' | paste -sd'|' -
}

# Print check rollup; set global PASSING/PENDING/FAILING counts.
report_checks() {
  local ref="$1"
  local ig; ig="$(ignore_regex)"
  # gh pr checks: name \t state \t ... — state in: pass/fail/pending/skipping/cancel/neutral
  local rows
  rows="$(gh pr checks "$ref" 2>/dev/null || true)"
  if [ -z "$rows" ]; then
    echo "checks: (none reported yet)"
    PENDING=1; PASSING=0; FAILING=0; return
  fi
  PASSING=0; PENDING=0; FAILING=0
  echo "checks for PR '$ref' (ignoring: ${IGNORE_CHECKS}):"
  while IFS=$'\t' read -r name state rest; do
    [ -n "$name" ] || continue
    local tag="$state"
    if [ -n "$ig" ] && echo "$name" | grep -qiE "$ig"; then
      printf "  - %-40s %-10s [ignored]\n" "$name" "$state"
      continue
    fi
    case "$state" in
      pass|success|neutral|skipping|skipped) PASSING=$((PASSING+1)); tag="✓ $state" ;;
      fail|failure|cancelled|cancel|timed_out|action_required|error) FAILING=$((FAILING+1)); tag="✗ $state" ;;
      *) PENDING=$((PENDING+1)); tag="… $state" ;;
    esac
    printf "  - %-40s %s\n" "$name" "$tag"
  done <<< "$rows"
  echo "summary: $PASSING passing / $PENDING pending / $FAILING failing (ignored checks excluded)"
}

watch_and_merge() {
  local ref; ref="$(pr_ref)"
  # Ensure a PR exists.
  if ! gh pr view "$ref" >/dev/null 2>&1; then
    echo ">> no PR for '$ref' — creating one"
    gh pr create --fill --base "$DEFAULT_BRANCH"
    ref="$(pr_ref)"
  fi

  local waited=0
  while :; do
    report_checks "$ref"
    if [ "${FAILING:-0}" -gt 0 ]; then
      echo "RESULT: FAILING — $FAILING required check(s) failed. Not merging."
      echo "        Inspect: gh pr checks $ref ; gh run view --log-failed"
      exit 3
    fi
    if [ "${PENDING:-0}" -eq 0 ] && [ "${PASSING:-0}" -gt 0 ]; then
      break
    fi
    if [ "$waited" -ge "$MAX_WAIT" ]; then
      echo "RESULT: TIMEOUT after ${MAX_WAIT}s with $PENDING check(s) still pending. Not merging."
      exit 4
    fi
    echo "   …waiting ${POLL}s (elapsed ${waited}s)"; sleep "$POLL"
    waited=$((waited+POLL))
  done

  echo ">> all required checks green — merging ($MERGE_METHOD)"
  local merge_args=(--"$MERGE_METHOD")
  [ "$DELETE_BRANCH" = "1" ] && merge_args+=(--delete-branch)
  [ "${ADMIN:-0}" = "1" ] && merge_args+=(--admin)
  gh pr merge "$ref" "${merge_args[@]}"
  echo "RESULT: MERGED $ref"
}

case "$ACTION" in
  push)   push_branch ;;
  status) report_checks "$(pr_ref)" ;;
  merge)
    # If there are unpushed commits on a feature branch, push first.
    if [ -n "$CUR_BRANCH" ] && [ "$CUR_BRANCH" != "$DEFAULT_BRANCH" ]; then
      if ! git diff --quiet origin/"$CUR_BRANCH"..HEAD 2>/dev/null; then
        push_branch || true
      fi
    fi
    watch_and_merge
    ;;
esac
