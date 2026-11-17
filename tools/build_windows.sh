#!/bin/bash
# Exports the Windows build and zips it as UrbanFishing-v<version>-windows.zip, and zips the
# Godot project (as committed) as UrbanFishing-v<version>-godot-project.zip.
# The version comes from application/config/version in godot/project.godot.
# Needs Node (for tools/icon/patch_template.js, which stamps the icon into the .exe).
# usage: tools/build_windows.sh <path to the Godot 4.4.1 binary> <output folder>
set -euo pipefail
GODOT=$1; OUT=$2
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VER=$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$ROOT/godot/project.godot")
cd "$ROOT/godot"
rm -rf export && mkdir export
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
# Put the game icon (icon.ico) and version info into a copy of Godot's Windows template and
# export with that copy. Godot 4.4 only does this itself on Windows, with rcedit.
GVER=$("$GODOT" --version | sed 's/^\([0-9.]*\)\.stable.*/\1.stable/')
TEMPLATE=${TEMPLATE:-$HOME/.local/share/godot/export_templates/$GVER/windows_release_x86_64.exe}
(cd "$ROOT/tools/icon" && [ -d node_modules ] || npm install --silent)
node "$ROOT/tools/icon/patch_template.js" "$TEMPLATE" "$ROOT/godot/export/template.exe" "$ROOT/godot/icon.ico" "$VER" >/dev/null
cp export_presets.cfg export/presets.bak
trap 'cp "$ROOT/godot/export/presets.bak" "$ROOT/godot/export_presets.cfg"' EXIT
sed -i "s|^custom_template/release=.*|custom_template/release=\"$ROOT/godot/export/template.exe\"|; s|^application/modify_resources=.*|application/modify_resources=false|" export_presets.cfg
"$GODOT" --headless --path . --export-release "Windows Desktop" "export/Urban Fishing.exe" >/dev/null 2>&1
cp export/presets.bak export_presets.cfg
mkdir -p "$OUT"
ZIP="$OUT/UrbanFishing-v$VER-windows.zip"
rm -f "$ZIP"
(cd export && zip -q -9 "$ZIP" "Urban Fishing.exe")
echo "$ZIP"
# and the Godot project itself, ready to open in Godot 4.4 (Import, pick project.godot)
PZIP="$OUT/UrbanFishing-v$VER-godot-project.zip"
rm -f "$PZIP"
git -C "$ROOT" archive --format=zip -9 --prefix="UrbanFishing-v$VER/" -o "$PZIP" HEAD:godot
echo "$PZIP"
