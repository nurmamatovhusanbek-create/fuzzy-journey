#!/usr/bin/env python3
"""kit specimen compare: crops the same region of the demo reference and the Godot render, magnifies both and writes ref | game | diff.
usage: kit_cmp.py <ref.png> <game.png> <out.png> <x> <y> <w> <h> [zoom=3]"""
import sys
from PIL import Image, ImageChops
ref, gd, out = sys.argv[1:4]
x, y, w, h = [int(v) for v in sys.argv[4:8]]
z = int(sys.argv[8]) if len(sys.argv) > 8 else 3
A = Image.open(ref).convert('RGB'); B = Image.open(gd).convert('RGB')
box = (x, y, x + w, y + h)
a, b = A.crop(box), B.crop(box)
d = ImageChops.difference(a, b)
hist = d.convert('L').histogram(); n = sum(hist)
mean = sum(i * c for i, c in enumerate(hist)) / n
d = d.point(lambda v: min(255, v * 3))
sheet = Image.new('RGB', (w * z * 3 + 8, h * z), (40, 0, 40))
for i, im in enumerate((a, b, d)):
    sheet.paste(im.resize((w * z, h * z), Image.NEAREST), (i * (w * z + 4), 0))
sheet.save(out)
print('mean abs diff %.2f' % mean)
