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
# performance gates: a selected province leaves the screen still (low-processor mode draws no frame); a hover / selection redrawn partially is the picture a full redraw gives
out=$(TB_NOANIM=0 timeout 280 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/perf_idle.gd -- 1280 720 0 globe 2>&1); echo "$out" | grep -q "IDLE OK" && echo "ok: tests/perf_idle.gd" || { echo "FAIL: tests/perf_idle.gd"; echo "$out" | grep -E "IDLE|SCRIPT" | head -3; fail=1; }
out=$(TB_NOANIM=1 timeout 500 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/map_partial.gd -- 1280 720 10 2>&1); echo "$out" | grep -q "PARTIAL OK" && echo "ok: tests/map_partial.gd" || { echo "FAIL: tests/map_partial.gd"; echo "$out" | grep -E "PARTIAL|differing pixels|SCRIPT" | head -5; fail=1; }
out=$(TB_NOANIM= timeout 500 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/bake.gd -- 1280 720 2>&1); echo "$out" | grep -q "^BAKE OK" && echo "ok: tests/bake.gd" || { echo "FAIL: tests/bake.gd"; echo "$out" | grep -E "baked|hover|SCRIPT" | head -6; fail=1; }
out=$(TB_NOANIM= timeout 250 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/fx_still.gd 2>&1); echo "$out" | grep -q "FX_STILL OK" && echo "ok: tests/fx_still.gd" || { echo "FAIL: tests/fx_still.gd"; echo "$out" | grep -E "FAIL|SCRIPT" | head -5; fail=1; }
out=$(timeout 280 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 -s tests/music.gd 2>&1); echo "$out" | grep -q "MUSIC OK" && echo "ok: tests/music.gd" || { echo "FAIL: tests/music.gd"; echo "$out" | grep -E "FAIL|SCRIPT" | head -5; fail=1; }
# B1 / B3 / B2 / B7: dialog staging (veil, rise, click completes, fade on close, Off instant) and the war declaration (seal, the War moment, skip, Off = none); run with a fixed frame rate
for t in staging:STAGING war_moment:WAR_MOMENT event_shots:EVENT_SHOTS finale:FINALE battle_ui:BATTLE_UI conquest_fade:CONQUEST_FADE map_fx:MAP_FX era_ring:ERA_RING toast_fx:TOAST_FX sel_pulse:SEL_PULSE begin_dive:BEGIN_DIVE pick_hover:PICK_HOVER mm_flat:MM_FLAT; do
  out=$(TB_NOANIM= timeout 250 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 -s tests/${t%%:*}.gd -- /tmp 2>&1); mark=${t##*:}
  echo "$out" | grep -q "$mark OK" && echo "ok: tests/${t%%:*}.gd" || { echo "FAIL: tests/${t%%:*}.gd"; echo "$out" | grep -E "FAIL|SCRIPT" | head -5; fail=1; }
done
mkdir -p /tmp/tb_cc; run tests/mm_globe.gd -- /tmp/tb_cc
# the minimap on a phone held sideways: shown, on screen, clear of the rail / tuner / End Turn / zoom / inspector, a tap turns the view
for cfg in "844 390 1.0" "844 390 2.0" "800 360 1.0" "932 430 1.0"; do
  out=$(TB_NOANIM=1 timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 -s tests/mm_phone.gd -- $cfg 2>&1)
  echo "$out" | grep -q "MM_PHONE OK" && echo "ok: mm_phone $cfg" || { echo "FAIL: mm_phone $cfg"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
done
# a phone held sideways gets the desktop interface (density emulated with TB_DPR / TB_DPI), the army numbers follow the province borders
out=$(TB_DPR=1.67 TB_DPI=420 TB_NOANIM=1 timeout 250 xvfb-run -a -s "-screen 0 1700x800x24" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 -s tests/phone_desktop.gd 2>&1)
echo "$out" | grep -q "PHONE_DESKTOP OK" && echo "ok: phone_desktop" || { echo "FAIL: phone_desktop"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
out=$(TB_NOANIM=1 timeout 280 xvfb-run -a -s "-screen 0 1700x1000x24" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 -s tests/army_rule.gd -- 1280 720 2>&1)
echo "$out" | grep -q "ARMY_RULE OK" && echo "ok: army_rule" || { echo "FAIL: army_rule"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
# alert cues: one cue per new alert, a game starts silent
out=$(TB_NOANIM= timeout 120 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 -s tests/alert_cues.gd 2>&1)
echo "$out" | grep -q "ALERT_CUES OK" && echo "ok: alert_cues" || { echo "FAIL: alert_cues"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
# multiplayer is "coming soon" in a release: the tag, the note, no network; the Advisor's note never covers the title rows
out=$(TB_NOANIM=1 timeout 150 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/mp_soon.gd -- 1920 1080 2>&1)
echo "$out" | grep -q "MP_SOON OK" && echo "ok: mp_soon" || { echo "FAIL: mp_soon"; echo "$out" | grep -E "FAIL|SCRIPT" | head -5; fail=1; }
# the Samsung S22 case (2340x1080 at 2.66 density): a district's info goes when anything else is called, every HUD button closes what it opened on a second press, windows end on the screen, a finger scrolls lists and resizes windows
for t in toggle_close:TOGGLE_CLOSE win_fit:WIN_FIT touch_scroll:TOUCH_SCROLL info_dismiss:INFO_DISMISS; do
  name=${t%%:*}; tag=${t##*:}
  out=$(TB_DPR=2.66 TB_DPI=425 TB_NOANIM=1 timeout 280 xvfb-run -a -s "-screen 0 2340x1080x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/$name.gd -- 2340 1080 2>&1)
  echo "$out" | grep -q "${tag} OK" && echo "ok: $name (phone)" || { echo "FAIL: $name (phone)"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
done
out=$(TB_NOANIM=1 timeout 280 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/win_fit.gd -- 1920 1080 2>&1)
echo "$out" | grep -q "WIN_FIT OK" && echo "ok: win_fit (desktop)" || { echo "FAIL: win_fit (desktop)"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
# the nation name beside the gauges: a long name (English and Russian) breaks onto two lines and the gauges start where it ends, at the S22's size and on a desktop window
for spec in "2340 1080 modern congo en" "2340 1080 modern emirates ru" "1920 1080 modern congo en" "2340 1080 timurid timurid en"; do
  set -- $spec
  out=$(TB_DPR=$([ "$1" = 2340 ] && echo 2.66 || echo 1) TB_DPI=$([ "$1" = 2340 ] && echo 425 || echo 96) TB_NOANIM=1 timeout 200 xvfb-run -a -s "-screen 0 $1x$2x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/hud_name_shot.gd -- $1 $2 /tmp/hud_name.png $3 $4 $5 expect 2>&1)
  echo "$out" | grep -q "HUD_NAME OK" && echo "ok: hud name $4 $5 at $1" || { echo "FAIL: hud name $4 $5 at $1"; echo "$out" | grep -E "OVERLAP|SCRIPT|name '" | head -4; fail=1; }
done
# map names while the globe turns: a name follows the map, does not hop between places or sizes, and fades instead of blinking (nations at country scale, districts zoomed in)
for cfgs in "1.6 0.5" "4.2 0.12"; do
  set -- $cfgs
  out=$(TB_STEP=$2 TB_DPR=2.66 TB_DPI=425 timeout 280 xvfb-run -a -s "-screen 0 2340x1080x24" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 60 -s tests/label_stability.gd -- 2340 1080 $1 expect 2>&1)
  echo "$out" | grep -q "LABEL_STABILITY OK" && echo "ok: label_stability zoom $1" || { echo "FAIL: label_stability zoom $1"; echo "$out" | grep -E "^FAIL|SCRIPT|LABELS" | head -6; fail=1; }
done
# F2 the Advisor's note (title + a long turn; Effects Off and Light; the same at a phone's density)
out=$(TB_NOANIM= timeout 290 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 -s tests/advisor_note.gd -- 1920 1080 2>&1)
echo "$out" | grep -q "ADVISOR_NOTE OK" && echo "ok: advisor_note 1920x1080" || { echo "FAIL: advisor_note 1920x1080"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
out=$(TB_DPR=1.67 TB_DPI=420 TB_NOANIM= timeout 290 xvfb-run -a -s "-screen 0 1700x800x24" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 -s tests/advisor_note.gd -- 1600 720 2>&1)
echo "$out" | grep -q "ADVISOR_NOTE OK" && echo "ok: advisor_note phone density" || { echo "FAIL: advisor_note phone density"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
run tests/ui_cmdcard.gd -- /tmp/tb_cc 1280 720
run tests/ui_cmdcard.gd -- /tmp/tb_cc 540 960
# HUD / command-card layout: no overlap with End Turn, nothing off screen, 48 u hit areas (stage sizes in design units: desktop 2098x1180, phone 844x390 / 800x360, portrait 540x960; x text scales)
for cfg in "2098 1180 1.0" "2098 1180 1.5" "844 390 1.0" "844 390 2.0" "800 360 1.0" "1280 720 1.5" "540 960 1.0" "540 960 2.0"; do
  out=$(TB_NOANIM=1 timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/ui_hud_layout.gd -- /tmp/tb_cc $cfg 2>&1)
  echo "$out" | grep -q "UI_HUD_LAYOUT OK" && echo "ok: ui_hud_layout $cfg" || { echo "FAIL: ui_hud_layout $cfg"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
done
# negotiation dial flow (animation on) and the overflow audit (labels / buttons wider than their room) over sizes, text scales and languages
out=$(timeout 200 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/ui_nego.gd 2>&1); echo "$out" | grep -q "UI_NEGO OK" && echo "ok: tests/ui_nego.gd" || { echo "FAIL: tests/ui_nego.gd"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
out=$(TB_NOANIM=1 timeout 200 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/ui_windows.gd 2>&1); echo "$out" | grep -q "UI_WINDOWS OK" && echo "ok: tests/ui_windows.gd" || { echo "FAIL: tests/ui_windows.gd"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
out=$(timeout 200 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/ui_resize.gd 2>&1); echo "$out" | grep -q "UI_RESIZE OK" && echo "ok: tests/ui_resize.gd" || { echo "FAIL: tests/ui_resize.gd"; echo "$out" | grep -E "^FAIL|SCRIPT" | head -5; fail=1; }
for cfg in "1280 720 1.0 en" "800 360 1.0 uz" "1920 1080 1.5 en" "1920 1080 1.5 ru"; do
  out=$(TB_NOANIM=1 timeout 200 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/ui_overflow.gd -- $cfg 2>&1)
  echo "$out" | grep -q "OVERFLOW_AUDIT 0 findings" && echo "ok: ui_overflow $cfg" || { echo "FAIL: ui_overflow $cfg"; echo "$out" | grep -E "OVERFLOW |SCRIPT" | head -5; fail=1; }
done
# portrait is not shipped (Android and the project are landscape-locked): reported, never fatal
out=$(TB_NOANIM=1 timeout 200 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/ui_overflow.gd -- 540 960 2.0 ru 2>&1)
echo "$out" | grep -q "OVERFLOW_AUDIT 0 findings" && echo "ok: ui_overflow 540 960 2.0 ru (portrait, informational)" || echo "info: portrait 540x960 at 200% ru has overflow items (not shipped, not counted)"
[ $fail -eq 0 ] && echo "UI PASS" || echo "UI FAIL"
exit $fail
