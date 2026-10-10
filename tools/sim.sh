#!/bin/bash
# AI-only balance matrix: every era x seeds, headless, in parallel -> $OUT/sim.jsonl.   usage: tools/sim.sh [turns=300] [seeds="1 2 3 4 5 6"] [out=/tmp/sim]
GODOT=${GODOT:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
TURNS=${1:-300}; SEEDS=${2:-"1 2 3 4 5 6"}; OUT=${3:-/tmp/sim}
cd "$(dirname "$0")/../godot"; mkdir -p "$OUT"; : > "$OUT/sim.jsonl"
for e in ancient roman medieval mongol timurid discovery gunpowder napoleonic victorian ww1 ww2 coldwar modern; do for s in $SEEDS; do echo "$e $s"; done; done |
  xargs -P ${JOBS:-4} -L 1 bash -c 'timeout 600 '"$GODOT"' --headless --path . -s tests/sim_balance.gd -- $0 $1 '"$TURNS"' 2>&1 | grep -E "^SIM " | sed "s/^SIM //" >> '"$OUT"'/sim.jsonl'
wc -l "$OUT/sim.jsonl"
