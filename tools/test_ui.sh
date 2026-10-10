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
mkdir -p /tmp/tb_map
for t in map_arrows map_a11y; do
  out=$(TB_NOANIM=1 timeout 500 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/$t.gd -- /tmp/tb_map 2>&1)
  if echo "$out" | grep -qE "^(ARROWS|MAPA11Y) OK" && ! echo "$out" | grep -qE "SCRIPT ERROR|^FAIL"; then echo "ok: tests/$t.gd"; else echo "FAIL: tests/$t.gd"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; fi
done
mkdir -p /tmp/tb_cc; run tests/mm_globe.gd -- /tmp/tb_cc
run tests/ui_cmdcard.gd -- /tmp/tb_cc 1280 720
run tests/ui_cmdcard.gd -- /tmp/tb_cc 540 960
# HUD / command-card layout: no overlap with End Turn, nothing off screen, 48 u hit areas (stage sizes in design units: desktop 2098x1180, phone 844x390 / 800x360, portrait 540x960; x text scales)
for cfg in "2098 1180 1.0" "2098 1180 1.5" "844 390 1.0" "844 390 2.0" "800 360 1.0" "1280 720 1.5" "540 960 1.0" "540 960 2.0"; do
  out=$(TB_NOANIM=1 timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/ui_hud_layout.gd -- /tmp/tb_cc $cfg 2>&1)
  echo "$out" | grep -q "UI_HUD_LAYOUT OK" && echo "ok: ui_hud_layout $cfg" || { echo "FAIL: ui_hud_layout $cfg"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
done
# negotiation dial flow (animation on) and the overflow audit (labels / buttons wider than their room) over sizes, text scales and languages
out=$(timeout 200 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/ui_nego.gd 2>&1); echo "$out" | grep -q "UI_NEGO OK" && echo "ok: tests/ui_nego.gd" || { echo "FAIL: tests/ui_nego.gd"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
out=$(timeout 200 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/ui_resize.gd 2>&1); echo "$out" | grep -q "UI_RESIZE OK" && echo "ok: tests/ui_resize.gd" || { echo "FAIL: tests/ui_resize.gd"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
for cfg in "1280 720 1.0 en" "540 960 2.0 ru" "800 360 1.0 uz" "1920 1080 1.5 en"; do
  out=$(TB_NOANIM=1 timeout 200 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/ui_overflow.gd -- $cfg 2>&1)
  echo "$out" | grep -q "OVERFLOW_AUDIT 0 findings" && echo "ok: ui_overflow $cfg" || { echo "FAIL: ui_overflow $cfg"; echo "$out" | grep -E "OVERFLOW |SCRIPT" | head -5; fail=1; }
done
[ $fail -eq 0 ] && echo "UI PASS" || echo "UI FAIL"
exit $fail
