#!/bin/bash
# Plays the game with the playtest bot (tools/playtest.gd) and prints what happens, headless.
# It runs in a copy of the project with the bot added as an autoload, its own save folder and
# low graphics, at a fixed 20 frames a second, so it plays a good deal faster than real time.
#
# usage: tools/playtest.sh <path to the Godot 4.4.1 binary> <scenario> [args]
#   journey   a new game from the title screen: fish Port Mullet until the coach to Ironwater runs,
#             sell at the restaurants, markets and Lou's, buy gear, ride on to Ironwater and Gannet
#             Harbor the same way, then take the coach home
#   spots     every fishing spot in all three towns (--town=N for one), by day and at night, with
#             all the gear: fish shadows there, and a catch in a few casts
#   boats     fishing from the skiff offshore, in the Outer Harbor, Mullet Bay and the Calder River
#   reach     every door, bus stop, buyer and price board can be walked to from the coach stop
#   cars      where busted players get walked out to, and standing in busy streets
#   probe     --lv=N --from=x,y --to=x,y: walk from one place to another and log each step
# Each line it prints starts with "PT [town, day, time, cash, cooler]". Problems start with "!!! ISSUE",
# and the last lines list them all. The full log, engine output too, is in playtest-<scenario>.log
# in the copy's folder (printed at the start).
set -euo pipefail
GODOT=$1; SC=$2; shift 2
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=${PLAYTEST_DIR:-/tmp/urban-fishing-playtest}
NAME="Urban Fishing Playtest"
mkdir -p "$WORK"
# a fresh copy of the project, keeping the import cache from last time
find "$WORK" -mindepth 1 -maxdepth 1 ! -name .godot -exec rm -rf {} +
(cd "$ROOT/godot" && tar cf - --exclude=./export --exclude=./.godot .) | (cd "$WORK" && tar xf -)
mkdir -p "$WORK/pt" && cp "$ROOT/tools/playtest.gd" "$WORK/pt/playtest.gd"
sed -i "s|^config/name=.*|config/name=\"$NAME\"|" "$WORK/project.godot"
sed -i 's|^Sound="\*res://scripts/sound.gd"|&\nPT="*res://pt/playtest.gd"|' "$WORK/project.godot"
# its own saves, started fresh, with graphics on Low
U="$HOME/.local/share/godot/app_userdata/$NAME"
rm -rf "$U"; mkdir -p "$U"
printf '[settings]\n\ngfx=0\n' > "$U/settings.cfg"
LOG="$WORK/playtest-$SC.log"
echo "log: $LOG"
"$GODOT" --headless --path "$WORK" --import >/dev/null 2>&1 || true
set +e
"$GODOT" --headless --fixed-fps 20 --path "$WORK" -- --pt="$SC" "$@" > "$LOG" 2>&1
code=$?
set -e
grep -E "^PT |SCRIPT ERROR" "$LOG" || true
exit $code
