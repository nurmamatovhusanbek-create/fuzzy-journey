#!/usr/bin/env python3
"""Bakes data/geo.bin: one byte per province of facts about where it lies, which the building rules read (rules >= 3).
   bit 0  coastal  the province touches the sea (a pixel of it has an ocean pixel next to it in the id raster; the Caspian counts as sea)
   bit 1  arid     its centre lies in one of the great deserts (ellipses below, lon / lat in degrees): no farms
   bit 2  polar    its centre lies beyond 66 degrees of latitude: no farms
Usage: tools/bake_geo.py   (reads godot/data/world.json and godot/data/ids.bin.gz, writes godot/data/geo.bin)"""
import gzip, json, os
import numpy as np
root = os.path.join(os.path.dirname(__file__), "..", "godot", "data")
w = json.load(open(os.path.join(root, "world.json")))
W, H, P = w["W"], w["H"], w["P"]
ids = np.frombuffer(gzip.open(os.path.join(root, "ids.bin.gz")).read(), dtype="<u2").reshape(H, W)
sea = ids == 0
adj = np.zeros_like(sea)
adj[1:] |= sea[:-1]; adj[:-1] |= sea[1:]
adj |= np.roll(sea, 1, axis=1); adj |= np.roll(sea, -1, axis=1)
coastal = np.zeros(P + 1, dtype=bool)
coastal[np.unique(ids[(ids > 0) & adj])] = True
# the great deserts: (name, centre lon, centre lat, half-width in lon, half-height in lat). The Nile valley, the Tigris-Euphrates plain and the Australian east coast lie outside them on purpose: they farm.
DESERTS = [
    ("Sahara", 8, 23, 21, 7), ("Arabian", 46, 23, 11, 7), ("Lut-Kavir", 57, 32, 5, 3.5), ("Karakum-Kyzylkum", 62, 41, 8, 3.5),
    ("Thar", 71, 27, 4, 3), ("Taklamakan", 83, 39.5, 5, 2.5), ("Gobi", 104, 42.5, 12, 3.5), ("Australian outback", 131, -26, 13, 6),
    ("Kalahari-Namib", 20, -24, 7, 5), ("Atacama", -69, -24, 2, 6), ("Sonoran-Chihuahuan", -108, 31, 6, 4),
]
out = bytearray(P)
n_arid = n_polar = 0
for p in range(P):
    lon, lat = w["lon"][p], w["lat"][p]
    f = 0
    if coastal[p + 1]: f |= 1
    if any(((lon - cx) / hx) ** 2 + ((lat - cy) / hy) ** 2 <= 1.0 for _, cx, cy, hx, hy in DESERTS): f |= 2; n_arid += 1
    if abs(lat) >= 66.0: f |= 4; n_polar += 1
    out[p] = f
open(os.path.join(root, "geo.bin"), "wb").write(bytes(out))
print("geo.bin: %d provinces, %d coastal, %d arid, %d polar" % (P, int(coastal.sum()), n_arid, n_polar))
