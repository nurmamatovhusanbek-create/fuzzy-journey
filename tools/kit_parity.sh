#!/bin/bash
# Kit parity: renders the demo's kit specimen sheet (docs/ui_variants/src/b_kitparity.html) and the Godot twin (godot/tests/kit_parity.gd) at 1 unit = 1 px
# and writes <out>/kit_side.png (demo | game) + prints the mean difference. Region compare: tools/kit_cmp.py <out>/kit_ref.png <out>/kit_gd.png <crop.png> x y w h [zoom]
OUT=${1:-/tmp/kit_parity}
GODOT=${GODOT:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
(cd docs/ui_variants && node build.mjs >/dev/null && node shoot_kit.mjs "$OUT/kit_ref.png")
(cd godot && TB_NOANIM=1 timeout 200 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -s tests/kit_parity.gd -- "$OUT/kit_gd.png" 2>&1 | grep -E "SCRIPT|^ERROR" | grep -vE "status < 0|leaked|still in use")
python3 - "$OUT" <<'PY'
import sys
from PIL import Image, ImageChops
o = sys.argv[1]
a = Image.open(o + '/kit_ref.png').convert('RGB'); b = Image.open(o + '/kit_gd.png').convert('RGB')
s = Image.new('RGB', (a.width * 2, a.height)); s.paste(a, (0, 0)); s.paste(b, (a.width, 0)); s.save(o + '/kit_side.png')
h = ImageChops.difference(a, b).convert('L').histogram(); n = sum(h)
print('kit sheet mean abs diff %.2f -> %s/kit_side.png' % (sum(i * c for i, c in enumerate(h)) / n, o))
PY
