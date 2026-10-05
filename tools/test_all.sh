#!/bin/bash
# Runs every headless test. Usage: tools/test_all.sh [GODOT_BIN]
GODOT=${1:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")/.."
fail=0
run() { echo "== $1"; (cd godot && "$GODOT" --headless --path . -s "$2" 2>&1 | grep -vE "ALSA|audio|^$|Godot Engine"); [ "${PIPESTATUS[0]}" -eq 0 ] || fail=1; }
(cd godot && "$GODOT" --headless --path . --import >/dev/null 2>&1)
run "engine: determinism + basics" tests/run_all.gd
run "save/load round trip (3 scenarios)" tests/saveload.gd
run "rulers: historical seeds, succession, determinism" tests/rulers.gd
echo "== oracle: GDScript engine vs JS reference (rules 0)"; tools/oracle.sh "$GODOT" || fail=1
echo "== multiplayer: server + 2 clients (lockstep of mirrored state)"; tools/test_mp.sh "$GODOT" 2>&1 | tail -3; [ "${PIPESTATUS[0]}" -eq 0 ] || fail=1
[ $fail -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit $fail
