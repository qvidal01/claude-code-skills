#!/usr/bin/env bash
# audit-deps/scripts/dependabot-scan.sh — read-only GitHub Dependabot fallback /
# corroboration for /audit-deps. Use when the native scanner is missing OR fails
# at runtime (toolchain/Python mismatch, wheel-build / pkg_resources errors), or
# to cross-check a native scan. Dependabot is authoritative for CVE triage on
# GitHub-hosted repos and covers ALL manifests in the repo (incl. monorepo
# subdirs the local scanner's cwd would miss).
#
# Pulls OPEN Dependabot alerts, aggregates one row per vulnerable package
# (max severity, advisory count, CVE/GHSA ids, latest fix), and maps each to the
# version pinned in the repo's manifests (requirements*.txt / package-lock.json).
#
# Usage:
#   dependabot-scan.sh [repo_dir]              # infer owner/name from git remote
#   dependabot-scan.sh --repo owner/name [dir] # explicit repo
#   dependabot-scan.sh --json [dir]            # machine-readable JSON
# Requires: gh (authenticated), python3. Read-only. Exit: 0 ok | 1 access | 2 usage
set -uo pipefail

MODE=text REPO="" DIR="."
while [ $# -gt 0 ]; do
  case "$1" in
    --json) MODE=json; shift ;;
    --repo) REPO=$2; shift 2 ;;
    *) DIR=$1; shift ;;
  esac
done
DIR=${DIR%/}; [ -n "$DIR" ] || DIR="."

command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI not found / not authenticated" >&2; exit 1; }

# infer owner/name from the git remote if not given
if [ -z "$REPO" ]; then
  url=$(git -C "$DIR" remote get-url origin 2>/dev/null || true)
  REPO=$(printf '%s' "$url" | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')
fi
[ -n "$REPO" ] || { echo "ERROR: could not determine owner/name (pass --repo owner/name)" >&2; exit 2; }

ALERTS_FILE=$(mktemp); trap 'rm -f "$ALERTS_FILE"' EXIT
gh api "repos/$REPO/dependabot/alerts" --paginate > "$ALERTS_FILE" 2>/dev/null || {
  echo "ERROR: cannot read Dependabot alerts for $REPO (not GitHub-hosted, Dependabot off, or no scope)" >&2; exit 1; }

DIR="$DIR" REPO="$REPO" MODE="$MODE" python3 - "$ALERTS_FILE" <<'PY'
import json, os, re, sys, glob, collections
_f = sys.argv[1]
alerts = json.load(open(_f)) if os.path.getsize(_f) else []
DIR, REPO, MODE = os.environ["DIR"], os.environ["REPO"], os.environ["MODE"]
op = [a for a in alerts if a.get("state") == "open"]

# pinned versions across all manifests (best-effort)
pins = {}  # name(lower) -> version
for p in glob.glob(f"{DIR}/**/requirements*.txt", recursive=True):
    if "/node_modules/" in p or "/.venv/" in p:
        continue
    try:
        for ln in open(p):
            m = re.match(r"^([A-Za-z0-9._-]+)(\[[a-z0-9,]+\])?==([^\s#;]+)", ln.strip())
            if m:
                pins.setdefault(m.group(1).lower().replace("_", "-"), m.group(3))
    except OSError:
        pass
for p in glob.glob(f"{DIR}/**/package-lock.json", recursive=True):
    if "/node_modules/" in p:
        continue
    try:
        lf = json.load(open(p))
        for k, v in lf.get("packages", {}).items():
            if k.startswith("node_modules/") and isinstance(v, dict) and v.get("version"):
                pins.setdefault(k.rsplit("node_modules/", 1)[-1].lower(), v["version"])
    except (OSError, ValueError):
        pass

rank = {"critical": 4, "high": 3, "medium": 2, "moderate": 2, "low": 1}
g = collections.defaultdict(list)
for a in op:
    sv, sa = a["security_vulnerability"], a["security_advisory"]
    eco = sv["package"]["ecosystem"]; pkg = sv["package"]["name"]
    g[(eco, pkg.lower(), pkg)].append((
        sa["severity"], sa.get("cve_id") or sa.get("ghsa_id"),
        (sv.get("first_patched_version") or {}).get("identifier"),
        a["dependency"].get("manifest_path", "?"),
    ))

rows = []
for (eco, pl, pkg), v in g.items():
    maxsev = max(v, key=lambda x: rank.get(x[0], 0))[0]
    fixes = sorted({x[2] for x in v if x[2]})
    rows.append({
        "package": pkg, "ecosystem": eco, "severity": maxsev,
        "pinned": pins.get(pl.replace("_", "-")) or pins.get(pl) or "?",
        "advisories": len(v), "latest_fix": fixes[-1] if fixes else None,
        "cves": sorted({x[1] for x in v if x[1]}),
        "manifests": sorted({x[3] for x in v}),
    })
rows.sort(key=lambda r: (-rank.get(r["severity"], 0), -r["advisories"], r["package"].lower()))

if MODE == "json":
    by = collections.Counter(r["severity"] for r in rows)
    print(json.dumps({"repo": REPO, "open_alerts": len(op), "packages": len(rows),
                      "by_severity": dict(by), "findings": rows}, indent=2))
else:
    by = collections.Counter(r["severity"] for r in rows)
    print(f"# Dependabot: {REPO} — {len(op)} open alerts across {len(rows)} packages")
    print(f"# by max-severity: {dict(by)}\n")
    for i, r in enumerate(rows, 1):
        print(f"{i:2}. [{r['severity']:8}] {r['ecosystem']:4} {r['package']}=={r['pinned']}  "
              f"adv={r['advisories']}  fix->{r['latest_fix'] or '?'}  {r['manifests']}")
        print(f"      CVEs: {', '.join(r['cves'])}")
PY
