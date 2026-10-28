#!/bin/bash
# The 20 s trailer-teaser: records the real game (godot/tests/trailer.gd) with Godot's movie writer as a lossless PNG sequence at 1920x1080, 30 fps (xvfb),
# builds the score (tools/trailer_score.py), grades and encodes: tools/trailer.sh [outdir=/tmp/trailer]
# Output: terra_bellum_trailer.mp4 (1080p, h264 crf 19, capped at 18 Mbit/s, AAC), poster.png, contact.png
OUT=${1:-/tmp/trailer}; GODOT=${GODOT:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf "$OUT"; mkdir -p "$OUT/frames"
python3 "$ROOT/tools/trailer_score.py" "$OUT/score.wav" || exit 1
cd "$ROOT/godot"
XDG_DATA_HOME=/tmp/xdg_m TB_NOANIM= xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --write-movie "$OUT/frames/f.png" --fixed-fps 30 -s tests/trailer.gd > "$OUT/godot.log" 2>&1
grep -E "SCRIPT ERROR|Parse Error" "$OUT/godot.log" | head -5
F0=$(grep -a "TRAILER_F0" "$OUT/godot.log" | awk '{print $2}'); [ -n "$F0" ] || { echo "no TRAILER_F0 (the script did not get going)"; exit 1; }
FIRST=$(ls "$OUT/frames" | grep -E '^f[0-9]+\.png$' | head -1); N=${#FIRST}
echo "frames: $(ls $OUT/frames | grep -cE '^f[0-9]+\.png$'), first $FIRST, trailer starts at frame $F0"
GRADE="eq=contrast=1.07:saturation=1.08:gamma=0.97,vignette=angle=PI/6,noise=alls=3:allf=t,fade=t=out:st=19.65:d=0.35,format=yuv420p"
ffmpeg -y -loglevel error -framerate 30 -start_number "$F0" -i "$OUT/frames/f%08d.png" -i "$OUT/score.wav" -frames:v 600 -vf "$GRADE" \
  -af "loudnorm=I=-14:TP=-1.5:LRA=9,afade=t=out:st=19.3:d=0.7" -c:v libx264 -preset slow -crf 19 -maxrate 18M -bufsize 36M -c:a aac -b:a 256k -t 20 -movflags +faststart "$OUT/terra_bellum_trailer.mp4"
ffmpeg -y -loglevel error -i "$OUT/terra_bellum_trailer.mp4" -vf "select=eq(n\,590)" -frames:v 1 "$OUT/poster.png"
ffmpeg -y -loglevel error -i "$OUT/terra_bellum_trailer.mp4" -vf "fps=0.9,scale=640:-1,tile=4x5" -frames:v 1 "$OUT/contact.png"
ls -la "$OUT" | grep -v frames
