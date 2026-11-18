#!/bin/bash
# Records a short video of the game's sound (v0.9.42): each scene is run with Godot's movie writer
# (--write-movie, which captures the picture and the mixed audio at a fixed frame rate), captioned,
# and joined into one MP4. Uses the --sounddemo test hooks in scripts/soundscape.gd.
# usage: tools/make_sound_preview.sh <path to the Godot 4.4.1 binary> <output .mp4>
# Needs ffmpeg, and xvfb-run on a machine with no display.
set -euo pipefail
GODOT=$1; OUT=$2
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
FONT="$ROOT/godot/fonts/AtkinsonHyperlegible-Bold.ttf"
i=0
scene() {   # seconds, caption, game args...
	local secs=$1 cap=$2; shift 2
	i=$((i + 1)); local f="$TMP/$(printf %02d $i)"
	xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path "$ROOT/godot" --rendering-driver opengl3 --resolution 1280x720 \
		--write-movie "$f.avi" --fixed-fps 30 --quit-after $((secs * 30 + 20)) -- --shot="$TMP/x.png" --shot-frame=999999 "$@" >/dev/null 2>&1 || true
	printf '%s' "$cap" > "$f.txt"
	ffmpeg -v error -y -ss 0.6 -i "$f.avi" -t "$secs" -vf "scale=1280:720,drawbox=y=ih-64:w=iw:h=64:color=black@0.55:t=fill,drawtext=fontfile='$FONT':textfile='$f.txt':x=24:y=h-46:fontsize=28:fontcolor=white" \
		-af "aresample=44100,afade=t=in:d=0.3,afade=t=out:st=$((secs - 1)).5:d=0.5" -ac 2 -c:v libx264 -preset veryfast -crf 26 -pix_fmt yuv420p -c:a aac -b:a 160k "$f.mp4"
	echo "file '$f.mp4'" >> "$TMP/list.txt"
}
scene 7 "Mullet Beach: footsteps in the sand, surf and gulls" --at=4,158.5,10 --walk=1,0
scene 13 "Casting a worm, live shrimp, a spoon and a popper (twitched), then a sloppy cast" --at=12,15.5,10 --sounddemo=cast --sounddir=90
scene 10 "A big fish on: the hookset, splashes, the drag and the line straining, then landing it" --at=12,15.5,10 --bob=0,2.5 --sounddemo=fight
scene 7 "Spotted on the golf course: a shout and a whistle" --at=72,20,10 --sounddemo=guard
scene 8 "Downtown in a thunderstorm: traffic, horns, wind, rain and thunder" --at=41.5,116.5,15 --day=5 --walk=1,0
scene 7 "Paddling a kayak past the marina as a boat heads out" --at=90,166,10 --boat=kayak --walk=1,0 --harbor=go
scene 5 "Your skiff's motor" --at=60,170,10 --boat=skiff --walk=1,0
scene 7 "Ironwater: the roar of the spillway" --level=1 --at=46,44,10 --walk=0,1
scene 6 "Ironwater: the old woolen mill" --level=1 --at=30,56.5,10 --walk=1,0
scene 8 "Ironwater: a game on at Riverhawks Field" --level=1 --at=84,92,19 --sounddemo=bat
ffmpeg -v error -y -f concat -safe 0 -i "$TMP/list.txt" -c copy "$OUT"
rm -rf "$TMP"
echo "$OUT"
