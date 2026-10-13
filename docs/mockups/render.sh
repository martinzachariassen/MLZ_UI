#!/usr/bin/env bash
# Renders the HTML mockups in docs/mockups/ to 2x PNGs in docs/screenshots/.
# Usage (from the repo root): ./docs/mockups/render.sh
# Needs Google Chrome (or set CHROME=/path/to/chrome).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/docs/mockups"
OUT="$ROOT/docs/screenshots"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
mkdir -p "$OUT"

# name  width  height  (must match the html/body size in each file)
SHOTS=(
    "control-center 1100 720"
    "nameplates     1100 720"
    "wizard         1000 780"
    "minimap-menu   1000 620"
)

for shot in "${SHOTS[@]}"; do
    read -r name w h <<< "$shot"
    "$CHROME" --headless --disable-gpu --hide-scrollbars --allow-file-access-from-files \
        --force-device-scale-factor=2 --window-size="$w,$h" \
        --screenshot="$OUT/$name.png" "file://$SRC/$name.html" > /dev/null 2>&1
    echo "rendered docs/screenshots/$name.png"
done
