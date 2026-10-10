#!/usr/bin/env python3
"""per-specimen mean abs difference of the kit parity sheet (demo vs game). usage: kit_regions.py <ref.png> <game.png>"""
import sys
from PIL import Image, ImageChops
R = [('panel (budget drawer)', 14, 14, 580, 690), ('buttons row 1', 636, 18, 640, 46), ('buttons row 2', 636, 70, 640, 46), ('buttons icon/kbd', 636, 122, 400, 46),
     ('round things', 636, 176, 420, 64), ('marks', 636, 246, 270, 160), ('leader rows', 926, 246, 340, 150), ('rows', 636, 400, 310, 175), ('tabs', 956, 400, 310, 46),
     ('table', 956, 456, 310, 80), ('tooltip', 632, 566, 280, 100), ('notices', 930, 566, 350, 200), ('menu list', 632, 722, 270, 150), ('gauges', 930, 792, 220, 100),
     ('modal', 14, 690, 600, 440)]
a = Image.open(sys.argv[1]).convert('RGB'); b = Image.open(sys.argv[2]).convert('RGB')
for n, x, y, w, h in R:
    d = ImageChops.difference(a.crop((x, y, x + w, y + h)), b.crop((x, y, x + w, y + h))).convert('L').histogram()
    print('%-24s %6.2f' % (n, sum(i * c for i, c in enumerate(d)) / sum(d)))
