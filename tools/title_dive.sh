#!/bin/bash
# Records the title's motion (tests/title_dive.gd: bracket glide, Continue, dive into the game) with Godot's movie writer, then encodes an mp4 and a gif.
# Usage: tools/title_dive.sh [outdir=/tmp/title_dive] [flat|globe] [off|light|full]
OUT=${1:-/tmp/title_dive}; VIEW=${2:-flat}; FX=${3:-full}; GODOT=${GODOT:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")/../godot"; mkdir -p "$OUT"
XDG_DATA_HOME=/tmp/xdg_m TB_NOANIM= xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --write-movie "$OUT/raw.avi" --fixed-fps 30 -s tests/title_dive.gd -- "$OUT" "$VIEW" "$FX" 2>&1 | grep -E "SCRIPT|ERROR: [^C]" | head
[ -f "$OUT/raw.avi" ] || { echo "no movie written"; exit 1; }
ffmpeg -y -loglevel error -i "$OUT/raw.avi" -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p -movflags +faststart "$OUT/title_dive_${VIEW}_${FX}.mp4"
ffmpeg -y -loglevel error -i "$OUT/raw.avi" -vf "fps=12,scale=560:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=96[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4" "$OUT/title_dive_${VIEW}_${FX}.gif"
ls -la "$OUT"
