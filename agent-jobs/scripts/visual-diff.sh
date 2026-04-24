#!/usr/bin/env bash
# visual-diff.sh — pixel-diff two PNGs via ImageMagick `compare`.
#
# Usage: visual-diff.sh BASELINE.png CANDIDATE.png [DIFF_OUT.png]
# Env:   THRESHOLD  (default 0.02 — 2%; AC-V-06 overrides to 0.05)
#        FUZZ       (default 2%   — per-channel tolerance)
#
# Exit codes:
#   0 — diff ratio < THRESHOLD
#   1 — diff ratio ≥ THRESHOLD
#   2 — usage / tooling error
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "usage: $0 BASELINE.png CANDIDATE.png [DIFF_OUT.png]" >&2
    exit 2
fi

BASELINE="$1"
CANDIDATE="$2"
DIFF_OUT="${3:-/tmp/visual-diff-$$.png}"
THRESHOLD="${THRESHOLD:-0.02}"
FUZZ="${FUZZ:-2%}"

for f in "$BASELINE" "$CANDIDATE"; do
    if [[ ! -f "$f" ]]; then
        echo "missing file: $f" >&2
        exit 2
    fi
done

if ! command -v compare >/dev/null 2>&1; then
    echo "ImageMagick 'compare' not found in PATH" >&2
    exit 2
fi
if ! command -v magick >/dev/null 2>&1 && ! command -v identify >/dev/null 2>&1; then
    echo "ImageMagick 'magick' or 'identify' required" >&2
    exit 2
fi

# `compare` exits 1 even on success when there are any differing pixels;
# capture stderr (where the AE count goes) without aborting.
set +e
DIFF_COUNT=$(compare -metric AE -fuzz "$FUZZ" "$BASELINE" "$CANDIDATE" "$DIFF_OUT" 2>&1)
COMPARE_EXIT=$?
set -e

# When the inputs differ in size, compare prints an error string instead of
# a number. Normalize: strip any trailing "@…" coordinates and any non-digit.
DIFF_COUNT="${DIFF_COUNT%% *}"
case "$DIFF_COUNT" in
    ''|*[!0-9]*)
        echo "compare did not return a numeric pixel count (got: '$DIFF_COUNT', exit=$COMPARE_EXIT)" >&2
        exit 1
        ;;
esac

if command -v magick >/dev/null 2>&1; then
    TOTAL=$(magick identify -format "%[fx:w*h]" "$BASELINE")
else
    TOTAL=$(identify -format "%[fx:w*h]" "$BASELINE")
fi

RATIO=$(python3 -c "print($DIFF_COUNT / $TOTAL)")
PASS=$(python3 -c "import sys; sys.exit(0 if $RATIO < $THRESHOLD else 1)" && echo yes || echo no)

echo "baseline=$BASELINE candidate=$CANDIDATE diff=$DIFF_COUNT total=$TOTAL ratio=$RATIO threshold=$THRESHOLD"

if [[ "$PASS" == "yes" ]]; then
    exit 0
else
    echo "FAIL: pixel-diff ratio $RATIO ≥ threshold $THRESHOLD (diff PNG: $DIFF_OUT)" >&2
    exit 1
fi
