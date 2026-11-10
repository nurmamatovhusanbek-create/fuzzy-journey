"""Raw render (white fill, black cuts, transparent background) -> alpha mask: white RGB, alpha = coverage x (1 - darkness of the cut)."""
import sys, glob, os
from PIL import Image
d = sys.argv[1]
for f in sorted(glob.glob(os.path.join(d, '*.raw.png'))):
    im = Image.open(f).convert('RGBA'); px = im.load(); w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (255, 255, 255, int(round(a * r / 255.0)))
    im.save(f.replace('.raw.png', '.png'), optimize=True); os.remove(f)
print('ok')
