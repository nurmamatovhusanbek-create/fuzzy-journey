#!/usr/bin/env python3
"""integrated ink: sum of |pixel - background| over a region in both images and their ratio (game / demo): a text-weight check.
usage: kit_ink.py <ref.png> <game.png> <x> <y> <w> <h>  (several regions: repeat x y w h quadruples)"""
import sys
from collections import Counter
from PIL import Image
ref, gd = sys.argv[1:3]
v = [int(a) for a in sys.argv[3:]]
A = Image.open(ref).convert('RGB'); B = Image.open(gd).convert('RGB')
for i in range(0, len(v), 4):
    x, y, w, h = v[i:i + 4]
    out = []
    for im in (A, B):
        c = im.crop((x, y, x + w, y + h))
        bg = Counter(c.get_flattened_data() if hasattr(c, 'get_flattened_data') else c.getdata()).most_common(1)[0][0]
        px = c.load()
        out.append(sum(sum(abs(px[a, b][k] - bg[k]) for k in range(3)) for a in range(w) for b in range(h)))
    print('region %d,%d %dx%d  ref %d  game %d  ratio %.2f' % (x, y, w, h, out[0], out[1], out[1] / max(out[0], 1)))
