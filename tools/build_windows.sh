#!/bin/bash
# Exports the Windows build and zips it as UrbanFishing-v<version>-windows.zip.
# The version comes from application/config/version in godot/project.godot.
# usage: tools/build_windows.sh <path to the Godot 4.4.1 binary> <output folder>
set -euo pipefail
GODOT=$1; OUT=$2
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VER=$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$ROOT/godot/project.godot")
cd "$ROOT/godot"
rm -rf export && mkdir export
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" "export/Urban Fishing.exe" >/dev/null 2>&1
mkdir -p "$OUT"
ZIP="$OUT/UrbanFishing-v$VER-windows.zip"
rm -f "$ZIP"
(cd export && zip -q -9 "$ZIP" "Urban Fishing.exe")
echo "$ZIP"
