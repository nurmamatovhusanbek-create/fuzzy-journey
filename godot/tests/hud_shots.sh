#!/bin/bash
# HUD screenshot matrix: 1280x720, 1920x1080, 800x360, 540x960 (portrait cutout), 2340x1080 (phone density + cutout). Usage: tests/hud_shots.sh <outdir> [lang]
GODOT=${GODOT:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")/.."
OUT=${1:-/tmp/hud_shots}; LANGX=${2:-en}
mkdir -p "$OUT"
run() { TB_NOANIM=1 xvfb-run -a -s "-screen 0 2400x1200x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/hud_shots.gd -- "$OUT" "$@" 2>&1 | grep -E "SCRIPT|ERROR|Parse" | grep -v "status < 0"; }
run 1280 720 $LANGX
run 1920 1080 $LANGX
run 800 360 $LANGX
TB_SAFE="0,28,0,24" run 540 960 $LANGX
TB_UI_SCALE=2.6 TB_SAFE="44,0,44,21" run 2340 1080 $LANGX
