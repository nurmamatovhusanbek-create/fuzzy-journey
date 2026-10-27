#!/bin/bash
# Records the teaser (tests/teaser.gd) with Godot's movie writer under xvfb, then encodes an mp4 (with a quiet generated pad) and a gif.
# Usage: tools/teaser.sh [outdir=/tmp/teaser]
OUT=${1:-/tmp/teaser}; GODOT=${GODOT:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")/../godot"; mkdir -p "$OUT"
XDG_DATA_HOME=/tmp/xdg_m TB_NOANIM= xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --write-movie "$OUT/raw.avi" --fixed-fps 30 -s tests/teaser.gd 2>&1 | grep -E "SCRIPT|ERROR: [^C]" | head
[ -f "$OUT/raw.avi" ] || { echo "no movie written"; exit 1; }
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/raw.avi")
# a slow pad: A minor chord with a fifth, a little tremolo, faded in and out
ffmpeg -y -loglevel error -f lavfi -i "sine=f=110:d=$DUR" -f lavfi -i "sine=f=164.8:d=$DUR" -f lavfi -i "sine=f=220:d=$DUR" -f lavfi -i "sine=f=261.6:d=$DUR" \
  -filter_complex "[0][1][2][3]amix=inputs=4:normalize=0,volume=0.22,tremolo=f=0.35:d=0.4,lowpass=f=900,afade=t=in:d=2,afade=t=out:st=$(python3 -c "print(max(0,$DUR-2.5))"):d=2.5[a]" -map "[a]" "$OUT/pad.wav"
ffmpeg -y -loglevel error -i "$OUT/raw.avi" -i "$OUT/pad.wav" -map 0:v -map 1:a -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p -c:a aac -b:a 160k -shortest -movflags +faststart "$OUT/terra_bellum_teaser.mp4"
ffmpeg -y -loglevel error -i "$OUT/raw.avi" -vf "fps=12,scale=560:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=96[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4" "$OUT/terra_bellum_teaser.gif"
ls -la "$OUT"
