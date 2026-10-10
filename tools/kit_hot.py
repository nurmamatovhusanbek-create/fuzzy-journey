#!/usr/bin/env python3
"""hot spots: mean abs difference per tile of two same-size images, worst first. usage: kit_hot.py <ref.png> <game.png> [tile=48] [n=14]"""
import sys
from PIL import Image, ImageChops
a = Image.open(sys.argv[1]).convert('RGB'); b = Image.open(sys.argv[2]).convert('RGB')
t = int(sys.argv[3]) if len(sys.argv) > 3 else 48
n = int(sys.argv[4]) if len(sys.argv) > 4 else 14
d = ImageChops.difference(a, b).convert('L')
res = []
for y in range(0, a.height, t):
    for x in range(0, a.width, t):
        h = d.crop((x, y, x + t, y + t)).histogram(); c = sum(h)
        res.append((sum(i * v for i, v in enumerate(h)) / c, x, y))
res.sort(reverse=True)
for m, x, y in res[:n]:
    print('%6.2f  tile at (%d, %d)' % (m, x, y))
