#!/usr/bin/env python3
"""cmp sheets: demo | game | abs difference; prints the mean absolute difference (0-255) per state."""
import sys, os
from PIL import Image, ImageChops
out, states = sys.argv[1], sys.argv[2].split(',')
for s in states:
    a, b = os.path.join(out, f'bezel_demo_{s}.png'), os.path.join(out, f'gd_{s}.png')
    if not (os.path.exists(a) and os.path.exists(b)):
        continue
    A, B = Image.open(a).convert('RGB'), Image.open(b).convert('RGB').resize(Image.open(a).size)
    D = ImageChops.difference(A, B)
    hist = D.convert('L').histogram(); n = sum(hist)
    mean = sum(i * c for i, c in enumerate(hist)) / n
    W, H = A.size
    sheet = Image.new('RGB', (W * 3, H)); sheet.paste(A, (0, 0)); sheet.paste(B, (W, 0)); sheet.paste(D, (2 * W, 0))
    sheet.save(os.path.join(out, f'cmp_{s}.png'))
    print(f'{s:10s} mean diff {mean:6.2f}  -> cmp_{s}.png')
