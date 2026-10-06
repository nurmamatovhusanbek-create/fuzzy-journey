#!/bin/bash
# UI smoke tests under a virtual display (needs xvfb): a random-input "monkey" on several seeds + the hot-seat flow.
# Fails on any SCRIPT ERROR or engine ERROR other than the missing audio device.
GODOT=${1:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")/../godot"
fail=0
run() {
  local out; out=$(timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s "$@" 2>&1)
  local bad; bad=$(echo "$out" | grep -E "SCRIPT ERROR|^ERROR:" | grep -vE "audio|ALSA|alsa|leaked|still in use|status < 0")
  if [ -n "$bad" ]; then echo "FAIL: $*"; echo "$bad" | sort | uniq -c | head -8; fail=1; else echo "ok: $*"; fi
}
# token gates: contrast (normal + both high-contrast variants) and the raw-colour lint
for t in ui_contrast:UI.CONTRAST ui_lint_tokens:UI.LINT; do
  out=$(timeout 120 "$GODOT" --headless --path . -s tests/${t%%:*}.gd 2>&1); mark=${t##*:}; mark=${mark/./ }
  echo "$out" | grep -q "$mark PASS" && echo "ok: tests/${t%%:*}.gd" || { echo "FAIL: tests/${t%%:*}.gd"; echo "$out" | grep FAIL | head -8; fail=1; }
done
for sd in 1 2 3 4; do run tests/ui_monkey.gd -- 160 $sd; done
run tests/ui_hotseat.gd
out=$(TB_NOANIM=1 timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/ui_back.gd 2>&1); echo "$out" | grep -q "UIBACK OK" && echo "ok: tests/ui_back.gd" || { echo "FAIL: tests/ui_back.gd"; echo "$out" | grep -E "FAIL|SCRIPT"; fail=1; }
mkdir -p /tmp/tb_cc; run tests/ui_cmdcard.gd -- /tmp/tb_cc 1280 720
run tests/ui_cmdcard.gd -- /tmp/tb_cc 540 960
[ $fail -eq 0 ] && echo "UI PASS" || echo "UI FAIL"
exit $fail
