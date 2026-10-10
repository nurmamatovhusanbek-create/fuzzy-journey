#!/bin/bash
# Bezel parity: renders the HTML demo (docs/ui_variants/bezel_demo.html) and the game in the same states at the same window size, then
# writes side-by-side sheets  <out>/cmp_<state>.png  (demo | game | difference) and prints a mean-difference score per state.
# Usage: tools/parity.sh <outdir> [w=1280] [h=720] [states=map,nations,...]   (states the demo knows: map nations budget decrees council annals goals event war menu tip2 lens move preview)
OUT=${1:-/tmp/parity}; W=${2:-1280}; H=${3:-720}
STATES=${4:-map,nations,budget,decrees,council,annals,goals,menu}
GODOT=${GODOT:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
(cd docs/ui_variants && node build.mjs >/dev/null && node shoot_bezel.mjs "$OUT" bezel_demo.html $W $H $STATES >/dev/null 2>&1)
GS=$(echo $STATES | tr ',' '\n' | grep -E '^(map|nations|budget|decrees|council|annals|goals|menu|select)$' | paste -sd,)
(cd godot && TB_NOANIM=1 timeout 280 xvfb-run -a -s "-screen 0 ${W}x${H}x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/parity.gd -- "$OUT" $W $H "$GS" 2>&1 | grep -E "SCRIPT|^ERROR" | grep -v "status < 0")
python3 tools/parity_cmp.py "$OUT" "$STATES"
