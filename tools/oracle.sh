#!/bin/bash
# Compare GDScript engine against the JS reference (bit-exact checksums). Usage: tools/oracle.sh [GODOT_BIN]
GODOT=${1:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
fail=0
for args in "3 120 " "11 80 roman" "5 60 ww2" "9 60 mongol"; do
  set -- $args
  A=$(node reference/engine-js/checksum.mjs $1 $2 "${3:-}")
  B=$(cd godot && $GODOT --headless --path . -s tests/oracle.gd -- $1 $2 ${3:-} 2>&1 | tail -1)
  if [ "$A" == "$B" ]; then echo "MATCH seed=$1 turns=$2 era=${3:-modern}"; else echo "DIFF  seed=$1 turns=$2 era=${3:-modern}"; fail=1; fi
done
exit $fail
