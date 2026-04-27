#!/usr/bin/env bash
# ui-critic-smoke.sh — M05 T10 / AC-UC-01.
#
# Build + run the `capture-all` executable into the documented output
# directory, then assert that all 10 PNG + 10 JSON sidecar pairs appear
# and are non-empty. Exit 0 on success, 1 on any failure.
#
# Usage:
#   scripts/ui-critic-smoke.sh [out_dir]
#
# Default out_dir = .workflow/m05/screenshots/critique/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/.workflow/m05/screenshots/critique}"
PKG_DIR="$REPO_ROOT/macapp/AgentJobsMac"

mkdir -p "$OUT_DIR"

echo "[ui-critic-smoke] running capture-all → $OUT_DIR"
if [ -n "${AGENTJOBS_CAPTURE_ALL_BIN:-}" ]; then
  # Pre-built binary path (used by tests that share an SPM build lock
  # with the parent `swift test` invocation).
  "$AGENTJOBS_CAPTURE_ALL_BIN" --out "$OUT_DIR"
else
  ( cd "$PKG_DIR" && swift run capture-all --out "$OUT_DIR" )
fi

# Expect exactly 10 PNG + 10 JSON files (AC-F-02 / AC-UC-01).
PNG_COUNT=$(find "$OUT_DIR" -maxdepth 1 -name '*.png' -type f | wc -l | tr -d ' ')
JSON_COUNT=$(find "$OUT_DIR" -maxdepth 1 -name '*.json' -type f | wc -l | tr -d ' ')

echo "[ui-critic-smoke] found $PNG_COUNT png(s), $JSON_COUNT json sidecar(s)"

if [ "$PNG_COUNT" -ne 10 ] || [ "$JSON_COUNT" -ne 10 ]; then
  echo "[ui-critic-smoke] FAIL: expected 10 PNG + 10 JSON, got $PNG_COUNT + $JSON_COUNT" >&2
  exit 1
fi

# Each PNG must be non-empty + start with the PNG magic bytes.
fail=0
while IFS= read -r f; do
  if [ ! -s "$f" ]; then
    echo "[ui-critic-smoke] FAIL: $f is empty" >&2
    fail=1
    continue
  fi
  magic=$(head -c 8 "$f" | xxd -p)
  if [ "$magic" != "89504e470d0a1a0a" ]; then
    echo "[ui-critic-smoke] FAIL: $f missing PNG magic (got $magic)" >&2
    fail=1
  fi
done < <(find "$OUT_DIR" -maxdepth 1 -name '*.png' -type f)

# Each JSON must be non-empty + parse.
while IFS= read -r f; do
  if [ ! -s "$f" ]; then
    echo "[ui-critic-smoke] FAIL: $f is empty" >&2
    fail=1
    continue
  fi
  if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" >/dev/null 2>&1; then
    echo "[ui-critic-smoke] FAIL: $f is not valid JSON" >&2
    fail=1
  fi
done < <(find "$OUT_DIR" -maxdepth 1 -name '*.json' -type f)

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "[ui-critic-smoke] OK"
exit 0
