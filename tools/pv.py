#!/usr/bin/env python3
"""pv.py <outdir> <state> [x0 y0 x1 y1] : demo | game crop side by side (no difference pane) -> <outdir>/v_<state>.png"""
import sys
from PIL import Image
out, s = sys.argv[1], sys.argv[2]
box = tuple(int(x) for x in sys.argv[3:7]) if len(sys.argv) >= 7 else (150, 90, 700, 650)
a = Image.open(f'{out}/bezel_demo_{s}.png').convert('RGB'); b = Image.open(f'{out}/gd_{s}.png').convert('RGB').resize(a.size)
w = box[2]-box[0]; h = box[3]-box[1]
c = Image.new('RGB', (w*2+8, h), (60, 0, 60)); c.paste(a.crop(box), (0, 0)); c.paste(b.crop(box), (w+8, 0))
sc = 1.4 if w < 700 else 1.0
c = c.resize((int(c.width*sc), int(c.height*sc)), Image.LANCZOS); c.save(f'{out}/v_{s}.png')
