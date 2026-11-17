#!/bin/bash
# Builds the game icon from the two SVGs in this folder:
#   icon.svg       the full picture (bobber, sunset skyline, jumping fish), used at 48 px and up
#   icon_small.svg a bold, simple bobber that stays readable at 16 to 32 px
# Writes godot/icon.png (512 px, project and window icon) and godot/icon.ico
# (16 to 256 px, the Windows .exe and taskbar icon).
# Needs Node with Playwright (Chromium) and ImageMagick.
# usage: tools/icon/make_icon.sh
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd "$HERE/../.." && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export NODE_PATH=${NODE_PATH:-$(npm root -g)}
for s in 16 24 32; do node "$HERE/render.js" "$HERE/icon_small.svg" "$TMP/$s.png" $s; done
for s in 48 64 128 256 512; do node "$HERE/render.js" "$HERE/icon.svg" "$TMP/$s.png" $s; done
cp "$TMP/512.png" "$ROOT/godot/icon.png"
convert "$TMP/16.png" "$TMP/24.png" "$TMP/32.png" "$TMP/48.png" "$TMP/64.png" "$TMP/128.png" "$TMP/256.png" "$ROOT/godot/icon.ico"
echo "$ROOT/godot/icon.png"; echo "$ROOT/godot/icon.ico"
