#!/usr/bin/env python3
"""pv.py <outdir> <state> [x0 y0 x1 y1] [diff] : demo | game crop side by side -> <outdir>/v_<state>.png ; with 'diff' a third pane (|difference| x2)."""
import sys
from PIL import Image, ImageChops
a_ = [x for x in sys.argv[1:] if x != 'diff']
out, s = a_[0], a_[1]
box = tuple(int(x) for x in a_[2:6]) if len(a_) >= 6 else (330, 180, 1250, 900)
a = Image.open(f'{out}/bezel_demo_{s}.png').convert('RGB'); b = Image.open(f'{out}/gd_{s}.png').convert('RGB').resize(a.size)
A = a.crop(box); B = b.crop(box)
w, h = A.size
n = 3 if 'diff' in sys.argv else 2
c = Image.new('RGB', (w*n+8*(n-1), h), (60, 0, 60)); c.paste(A, (0, 0)); c.paste(B, (w+8, 0))
if n == 3:
    D = ImageChops.difference(A, B).point(lambda v: min(255, v*3)); c.paste(D, (2*w+16, 0))
c.save(f'{out}/v_{s}.png')
