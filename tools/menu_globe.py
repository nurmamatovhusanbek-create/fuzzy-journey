#!/usr/bin/env python3
"""A high-quality picture of the title globe from the world data (for the main-menu mocks and, built once, for the real first stage).
The game draws the globe live from a 4096 x 2048 id map, which is only about 1.6 pixels per texel when the globe fills a screen corner, so edges show stairs. Here the nation map is smoothed
as soft masks (Gaussian per nation, three times upsampled, strongest wins), borders are drawn on the smooth map, the sphere is rendered at twice the size and averaged down.
Usage: python3 tools/menu_globe.py OUT.png [size=1578] [lon0=35] [lat0=12] [era_cols.json]   (era_cols.json: tests/dump_era_cols via the game, see docs)"""
import gzip, json, math, sys, os
import numpy as np, cv2
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "godot", "data")
out = sys.argv[1]
S = int(sys.argv[2]) if len(sys.argv) > 2 else 1578
LON0 = float(sys.argv[3]) if len(sys.argv) > 3 else 35.0
LAT0 = float(sys.argv[4]) if len(sys.argv) > 4 else 12.0
cols_path = sys.argv[5] if len(sys.argv) > 5 else "/tmp/ti/era_cols.json"
UP = 3                                              # soft-mask upsampling
SS = 2                                              # render scale
DISC = 0.875                                        # the disc's share of the picture (the rest is glow)
W0, H0 = 4096, 2048
ids = np.frombuffer(gzip.open(os.path.join(ROOT, "ids.bin.gz")).read(), dtype="<u2").reshape(H0, W0)
world = json.load(open(os.path.join(ROOT, "world.json")))
era = json.load(open(cols_path))
owner = np.array(era["owner"], dtype=np.int32); color = era["color"]
NN = len(color)
prov_label = np.concatenate([[0], np.where(owner > 0, owner, NN)])           # province id (1-based) -> nation label; 0 ocean; NN = unclaimed land
label = prov_label[ids].astype(np.int32)
# the part of the map in view: lon0 +- 100 degrees, lat -45 .. 90
x0 = int(((LON0 - 100.0 + 180.0) / 360.0) * W0); x1 = int(((LON0 + 100.0 + 180.0) / 360.0) * W0)
assert x0 >= 0 and x1 <= W0, "keep lon0 between -80 and 80 for this crop"
y0 = 0; y1 = int((90.0 + 45.0) / 180.0 * H0)
crop = label[y0:y1, x0:x1]
H, W = crop.shape
best = np.full((H * UP, W * UP), -1.0, dtype=np.float32); arg = np.zeros((H * UP, W * UP), dtype=np.int32)
for k in np.unique(crop):
    ys, xs = np.where(crop == k)
    pad = 6
    ya, yb = max(0, ys.min() - pad), min(H, ys.max() + pad + 1); xa, xb = max(0, xs.min() - pad), min(W, xs.max() + pad + 1)
    m = (crop[ya:yb, xa:xb] == k).astype(np.float32)
    m = cv2.GaussianBlur(m, (0, 0), 1.25)
    m = cv2.resize(m, ((xb - xa) * UP, (yb - ya) * UP), interpolation=cv2.INTER_CUBIC)
    sl = (slice(ya * UP, yb * UP), slice(xa * UP, xb * UP))
    upd = m > best[sl]
    best[sl] = np.where(upd, m, best[sl]); arg[sl] = np.where(upd, k, arg[sl])
# colours of the smooth map
pal = np.zeros((NN + 1, 3), dtype=np.float32)
for n in range(1, NN):
    c = color[n]; pal[n] = ((c >> 16) & 255, (c >> 8) & 255, c & 255)
pal[NN] = (74, 80, 84)                                                                   # unclaimed land
hsv = cv2.cvtColor(pal.reshape(1, -1, 3).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
hsv[..., 1] = np.clip(hsv[..., 1] * 0.82, 0, 255); hsv[..., 2] = np.clip(hsv[..., 2] * 0.80 + 14, 0, 255)       # calm the nation colours a little: the globe is a backdrop
pal = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB).reshape(-1, 3).astype(np.float32)
pal[0] = (10, 18, 30)                                                                    # ocean
tex = pal[arg]
# border lines on the smooth map: nation-nation, nation-ocean (coast)
a = arg
d = np.zeros(a.shape, dtype=np.uint8)
d[:, 1:] |= (a[:, 1:] != a[:, :-1]); d[1:, :] |= (a[1:, :] != a[:-1, :]); d[1:, 1:] |= (a[1:, 1:] != a[:-1, :-1])
d = cv2.dilate(d, np.ones((2, 2), np.uint8))
coast = ((a == 0) & (cv2.dilate((a > 0).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0)) | ((a > 0) & (cv2.erode((a > 0).astype(np.uint8), np.ones((3, 3), np.uint8)) == 0))
line = cv2.GaussianBlur(d.astype(np.float32), (0, 0), 0.7)
tex = tex * (1.0 - 0.62 * line[..., None]) + np.array([8, 12, 20], np.float32) * 0.62 * line[..., None]
tex = tex.astype(np.float32)
# the sphere
N = S * SS
R = N * DISC * 0.5
cx = cy = N / 2.0
xs, ys = np.meshgrid(np.arange(N, dtype=np.float32) + 0.5, np.arange(N, dtype=np.float32) + 0.5)
u = (xs - cx) / R; v = (cy - ys) / R
r2 = u * u + v * v
inside = r2 <= 1.0
z = np.sqrt(np.clip(1.0 - r2, 0.0, 1.0))
lat0 = math.radians(LAT0)
phi = np.arcsin(np.clip(z * math.sin(lat0) + v * math.cos(lat0), -1, 1))
lam = math.radians(LON0) + np.arctan2(u, z * math.cos(lat0) - v * math.sin(lat0))
lon_deg = np.degrees(lam); lat_deg = np.degrees(phi)
mx = ((lon_deg + 180.0) / 360.0 * W0 - x0) * UP
my = ((90.0 - lat_deg) / 180.0 * H0 - y0) * UP
mx = np.clip(mx, 0, W * UP - 1).astype(np.float32); my = np.clip(my, 0, H * UP - 1).astype(np.float32)
img = cv2.remap(tex, mx, my, cv2.INTER_LINEAR)
land = cv2.remap((a > 0).astype(np.float32), mx, my, cv2.INTER_LINEAR)
# light: from the upper left and the front; the ocean gets a soft sheen
nx, ny, nz = u, v, z
L = np.array([-0.45, 0.55, 0.70]); L /= np.linalg.norm(L)
lam_ = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
shade = 0.50 + 0.62 * lam_
shade = shade * (0.78 + 0.22 * z)                                                         # darker toward the limb
img = img * shade[..., None]
sheen = (np.clip(lam_ - 0.72, 0, 1) / 0.28) ** 2 * (1.0 - land)
img = img + sheen[..., None] * np.array([10, 20, 34], np.float32)
# graticule: thin gold lines every 15 degrees, one pixel wide whatever the slope
def grid(deg, step):
    f = (deg / step)
    dist = np.abs(f - np.round(f))
    gy, gx = np.gradient(f)
    w = np.sqrt(gx * gx + gy * gy) + 1e-6
    return np.clip(1.0 - dist / (w * 1.1), 0, 1)
lon_w = (lon_deg + 180.0) % 360.0 - 180.0
gl = np.maximum(grid(lon_w, 15.0) * (np.abs(lon_w - np.round(lon_w / 15.0) * 15.0) < 3.0), grid(lat_deg, 15.0))
gl = np.clip(gl, 0, 1) * 0.30 * (0.35 + 0.65 * z)
img = img * (1 - gl[..., None]) + np.array([201, 162, 75], np.float32) * gl[..., None]
# the disc with its atmosphere: a blue rim inside, a glow outside
rr = np.sqrt(r2)
rim = np.clip((rr - 0.80) / 0.20, 0, 1) ** 2.2
img = img + rim[..., None] * np.array([10, 26, 58], np.float32) * inside[..., None]
alpha = inside.astype(np.float32)
edge = np.clip((1.0 - rr) * R / 1.5, 0, 1)                                                # one pixel of anti-aliasing at the limb
alpha = np.where(inside, edge, 0.0)
glow = np.exp(-np.clip(rr - 1.0, 0, 5) / 0.045) * (rr > 1.0)
glow = glow * np.clip((1.0 - (rr - 1.0) / (0.30)), 0, 1)
col = np.where(inside[..., None], img, np.array([26, 62, 130], np.float32)[None, None, :])
a_out = np.clip(alpha + glow * 0.55 * (1 - alpha), 0, 1)
rgba = np.dstack([np.clip(col, 0, 255), a_out * 255]).astype(np.float32)
rgba = cv2.resize(rgba, (S, S), interpolation=cv2.INTER_AREA)
cv2.imwrite(out, cv2.cvtColor(np.clip(rgba, 0, 255).astype(np.uint8), cv2.COLOR_RGBA2BGRA))
print("written", out, rgba.shape)
