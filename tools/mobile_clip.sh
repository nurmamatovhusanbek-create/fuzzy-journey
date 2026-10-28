#!/bin/bash
# Records a ~10 s phone playthrough (landscape, the way the game is played; add `portrait` for the fallback layout) (title -> New game -> pick -> Play -> briefing -> province -> End turn) with Godot's movie writer and encodes an mp4.
# Usage: tools/mobile_clip.sh [outdir=/tmp/mobile_clip] [off|light|full] [land|portrait]
OUT=${1:-/tmp/mobile_clip}; FX=${2:-full}; ORI=${3:-land}; GODOT=${GODOT:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")/../godot"; mkdir -p "$OUT"
XDG_DATA_HOME=/tmp/xdg_m TB_DPR=${TB_DPR:-1.67} TB_DPI=${TB_DPI:-420} TB_NOANIM= xvfb-run -a -s "-screen 0 1700x1300x24" "$GODOT" --path . --rendering-driver opengl3 --write-movie "$OUT/raw.avi" --fixed-fps 30 -s tests/mobile_clip.gd -- "$OUT" "$FX" "$ORI" 2>&1 | grep -aE "CLIP|SCRIPT|Parse" 
[ -f "$OUT/raw.avi" ] || { echo "no movie written"; exit 1; }
ffmpeg -y -loglevel error -i "$OUT/raw.avi" -t 10 -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart "$OUT/mobile_gameplay.mp4"
ls -la "$OUT"
