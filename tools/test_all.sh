#!/bin/bash
# Runs every headless test. Usage: tools/test_all.sh [GODOT_BIN]
GODOT=${1:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")/.."
fail=0
run() { echo "== $1"; local out; out=$(cd godot && "$GODOT" --headless --path . -s "$2" 2>&1); local rc=$?; echo "$out" | grep -vE "ALSA|audio|^$|Godot Engine"; [ $rc -eq 0 ] || { echo "!! FAILED: $1"; fail=1; }; }
(cd godot && "$GODOT" --headless --path . --import >/dev/null 2>&1)
run "engine: determinism + basics" tests/run_all.gd
run "save/load round trip (3 scenarios)" tests/saveload.gd
run "rulers: historical seeds, succession, determinism" tests/rulers.gd
run "diplomacy: casus belli, infamy, coalitions" tests/diplo.gd
run "decisions" tests/decisions.gd
run "trade deals" tests/trade.gd
run "royal marriages" tests/marriage.gd
run "generals" tests/generals.gd
run "ultimatums" tests/ultimatum.gd
run "honours" tests/honours.gd
run "supply / attrition" tests/supply.gd
run "doctrine" tests/doctrine.gd
run "plaque animation state" tests/labels_anim.gd
run "can(): read-only and in step with apply()" tests/can.gd
run "regional unification" tests/realms.gd
run "AI offers to humans" tests/offers.gd
run "chronicle/advisor texts have no missing keys" tests/chron_keys.gd
run "Russian nation names" tests/names_ru.gd
run "Russian place names" tests/places_ru.gd
run "synth audio" tests/audio.gd
run "soak: random human, 7 eras, invariants" tests/soak.gd
run "historical events: integrity + firing" tests/hist_events.gd
echo "== oracle: GDScript engine vs JS reference (rules 0)"; tools/oracle.sh "$GODOT" || fail=1
echo "== multiplayer: server + 2 clients (lockstep of mirrored state)"; tools/test_mp.sh "$GODOT" 2>&1 | tail -3; [ "${PIPESTATUS[0]}" -eq 0 ] || fail=1
[ $fail -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit $fail
