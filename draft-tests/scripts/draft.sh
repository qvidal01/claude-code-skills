#!/usr/bin/env bash
# draft-tests: deterministic Ollama call (preflight + generate + save raw draft).
# Replaces the hand-typed curl/jq block in SKILL.md step 3 so the result is the
# same every time and costs no Claude tokens. Claude still does steps 1-2 (read
# module + neighbor test) and steps 4-7 (review, fix, run, report) — the judgment.
#
# Usage: draft.sh <module-path> [focus...]
#   MODEL env overrides the default model.
# Exit codes: 0 ok (draft path on stdout, last line) | 3 server unreachable | 2 usage
set -uo pipefail

SERVER=${OLLAMA_HOST:-http://localhost:11434}
MODEL=${MODEL:-qwen2.5-coder:32b-instruct}

[ $# -ge 1 ] || { echo "usage: $0 <module-path> [focus...]" >&2; exit 2; }
MODULE=$1; shift; FOCUS="${*:-}"
[ -f "$MODULE" ] || { echo "no such file: $MODULE" >&2; exit 2; }

# Preflight (don't retry > a few seconds; SKILL.md fallback = Claude writes by hand)
if ! curl -sS --max-time 5 "$SERVER/api/tags" >/dev/null 2>&1; then
  echo "AI server $SERVER unreachable — write the tests by hand (SKILL.md fallback)." >&2
  exit 3
fi

OUT="/tmp/draft-tests-$(basename "${MODULE%.*}").py"
MODULE_SOURCE=$(cat "$MODULE")
PROMPT="You are a senior Python engineer. Write pytest tests (sync unless the module is async-only) that exercise the public surface of this module.

Rules:
  - Output ONLY valid Python code. No markdown fences. No prose.
  - Use pytest assertions, no unittest.
  - No fixtures unless absolutely necessary.
  - No mocks unless the module clearly talks to an external service — in which case use unittest.mock.MagicMock.
  - Include 3-5 test functions, named test_<function_under_test>_<scenario>.
  - Include at least one edge case (empty input, missing key, None, etc).
  - Match the project's existing test style as much as possible.${FOCUS:+

Focus area: $FOCUS}

Module source:
$MODULE_SOURCE"

curl -sS --max-time 240 "$SERVER/api/generate" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg p "$PROMPT" --arg m "$MODEL" \
        '{model:$m, prompt:$p, stream:false, options:{temperature:0.2, num_predict:800}}')" \
  | jq -r '.response // .error' > "$OUT"

if [ ! -s "$OUT" ]; then echo "empty response from model" >&2; exit 1; fi
echo "raw draft saved -> $OUT  (now REVIEW: imports, field names, async, tautologies)" >&2
echo "$OUT"
