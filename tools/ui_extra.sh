#!/bin/bash
# Extra UI scripts that are not in test_ui.sh: fails on SCRIPT ERROR / engine ERROR only (they write screenshots to /tmp/tb_extra). Usage: tools/ui_extra.sh [GODOT_BIN]
GODOT=${1:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")/../godot"
mkdir -p /tmp/tb_extra
fail=0
for t in ui_modals ui_menu ui_pick ui_look theme_ui events_ui gameover_ui ru_ui nation_ui ruler_ui move_ui chronicle_ui ui_portrait ui_plaque ui_flags ui_atlas ui_anim ui_shots3; do
  out=$(TB_NOANIM=1 timeout 200 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/$t.gd -- /tmp/tb_extra 1280 720 2>&1)
  bad=$(echo "$out" | grep -E "SCRIPT ERROR|^ERROR:" | grep -vE "audio|ALSA|alsa|leaked|still in use|status < 0")
  if [ -n "$bad" ]; then echo "FAIL: $t"; echo "$bad" | sort | uniq -c | head -6; fail=1; else echo "ok: $t"; fi
done
[ $fail -eq 0 ] && echo "EXTRA PASS" || echo "EXTRA FAIL"
exit $fail
