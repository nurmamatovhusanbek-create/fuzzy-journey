#!/usr/bin/env python3
"""ink extents: for a region, the bounding box of pixels that differ from the region's background (mode colour) by more than a threshold, in both images.
usage: kit_ext.py <ref.png> <game.png> <x> <y> <w> <h> [thr=40]"""
import sys
from collections import Counter
from PIL import Image
ref, gd = sys.argv[1:3]
x, y, w, h = [int(v) for v in sys.argv[3:7]]
thr = int(sys.argv[7]) if len(sys.argv) > 7 else 40
for name, path in (('ref', ref), ('gd ', gd)):
    im = Image.open(path).convert('RGB').crop((x, y, x + w, y + h))
    px = im.load()
    bg = Counter(im.getdata()).most_common(1)[0][0]
    xs, ys = [], []
    for j in range(h):
        for i in range(w):
            p = px[i, j]
            if sum(abs(p[k] - bg[k]) for k in range(3)) > thr:
                xs.append(i); ys.append(j)
    if xs:
        print(name, 'bg', bg, 'x %d..%d  y %d..%d  (abs x %d..%d y %d..%d)' % (min(xs), max(xs), min(ys), max(ys), x + min(xs), x + max(xs), y + min(ys), y + max(ys)))
    else:
        print(name, 'no ink')
