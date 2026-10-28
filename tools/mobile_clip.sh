#!/bin/bash
# Records a ~10 s portrait-phone playthrough (title -> New game -> pick -> Play -> briefing -> province -> End turn) with Godot's movie writer and encodes an mp4.
# Usage: tools/mobile_clip.sh [outdir=/tmp/mobile_clip] [off|light|full]
OUT=${1:-/tmp/mobile_clip}; FX=${2:-full}; GODOT=${GODOT:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")/../godot"; mkdir -p "$OUT"
XDG_DATA_HOME=/tmp/xdg_m TB_NOANIM= xvfb-run -a -s "-screen 0 720x1280x24" "$GODOT" --path . --rendering-driver opengl3 --write-movie "$OUT/raw.avi" --fixed-fps 30 -s tests/mobile_clip.gd -- "$OUT" "$FX" 2>&1 | grep -aE "CLIP|SCRIPT|Parse" 
[ -f "$OUT/raw.avi" ] || { echo "no movie written"; exit 1; }
ffmpeg -y -loglevel error -i "$OUT/raw.avi" -t 10 -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart "$OUT/mobile_gameplay.mp4"
ls -la "$OUT"
