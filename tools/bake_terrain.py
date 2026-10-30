#!/usr/bin/env python3
"""Bakes data/terrain.bin: one byte per province, the terrain a new game (rules >= 3) gives it: 0 plains, 1 hills, 2 mountain, 3 forest, 4 marsh, 5 steppe (data.gd TERRAIN_ID).
   Rules 0 to 2 keep the old terrain drawn from a hash of the province id (the reference engine and its oracle depend on it); rules 3 reads the geography instead, so the Alps are mountains and Holland is not.
   The rules are ellipses (centre lon, centre lat, half width in lon, half height in lat, in degrees) tried in this order: marsh, mountain, forest, steppe (and the great deserts of geo.bin, open
   ground, and everything beyond 66 degrees, tundra), then the foothills of every mountain range (the same ellipse 1.5 times as wide: hills), then lowland, where a deterministic fifth of the
   provinces are rolling hills. Provinces are placed by the centre of the province (data/world.json lon / lat).
Usage: tools/bake_terrain.py   (reads godot/data/world.json and godot/data/geo.bin, writes godot/data/terrain.bin)"""
import json, os, zlib
root = os.path.join(os.path.dirname(__file__), "..", "godot", "data")
w = json.load(open(os.path.join(root, "world.json")))
P = w["P"]
geo = open(os.path.join(root, "geo.bin"), "rb").read()
assert len(geo) == P

PLAINS, HILLS, MOUNTAIN, FOREST, MARSH, STEPPE = range(6)

MARSH_E = [
    ("Nile delta", 31, 31, 1.4, 0.8), ("Ganges-Brahmaputra delta", 90, 23.2, 3, 1.5), ("Mekong delta", 105.5, 10, 1.5, 1.3), ("Irrawaddy delta", 95.5, 16.5, 1.2, 1.2),
    ("Mesopotamian marshes", 47, 31.5, 2, 1.2), ("Pripet marshes", 28, 52, 5, 1.3), ("Sudd", 30.5, 8, 3, 2.5), ("Okavango", 23, -19, 2, 1.5), ("Niger inland delta", -4, 15, 2, 1),
    ("Mississippi delta", -91, 30, 2.5, 1.5), ("Everglades", -81, 26, 2, 1.5), ("Pantanal", -57, -18, 3, 2.5), ("Camargue", 4.5, 43.5, 1, 0.5), ("Low Countries", 5, 52.5, 2.5, 1.3),
    ("Po delta", 12, 45, 1.5, 0.7), ("Danube delta", 29.5, 45, 1, 0.8), ("Volga delta", 48, 46, 1.5, 1), ("West Siberian lowland", 75, 62, 12, 4), ("Hudson Bay lowland", -84, 53, 5, 3),
    ("Rhine-Elbe fens", 9, 53.5, 2.5, 0.8), ("Yangtze delta", 120.5, 31, 1.5, 1.2),
]
MOUNTAIN_E = [
    ("Alps", 10.5, 46.5, 6.5, 1.6), ("Pyrenees", 0.5, 42.7, 3.5, 0.9), ("Cantabrian", -5, 43, 3, 0.6), ("Apennines", 13.5, 42.5, 1.6, 3.5), ("Carpathians", 24, 47.5, 6, 1.6),
    ("Balkans", 21, 42.5, 5, 2), ("Caucasus", 44, 42.5, 5.5, 1.3), ("Taurus", 33, 37.5, 7, 1.2), ("Pontic", 36, 41, 5, 0.8), ("Zagros", 49.5, 32.5, 3.5, 3.8), ("Alborz", 52, 36.2, 4, 0.8),
    ("Hindu Kush and Pamir", 70, 36, 5, 3), ("Karakoram and western Himalaya", 76, 34.5, 8, 2), ("Himalaya", 88, 28, 7, 1.5), ("Tibetan plateau", 90, 33, 9, 3.5), ("Kunlun", 85, 36, 10, 1.5),
    ("Tian Shan", 80, 42, 8, 1.8), ("Altai and Sayan", 90, 50, 6, 2.5), ("Verkhoyansk", 130, 62, 12, 4), ("Urals", 59.5, 59, 1.7, 9), ("Scandes", 13, 63, 3.5, 6), ("Scottish Highlands", -4.5, 57, 1.6, 1),
    ("Atlas", -3, 32, 8, 2.5), ("Ahaggar", 8, 23, 4, 2.5), ("Tibesti", 17, 21, 3, 2), ("Ethiopian highlands", 38, 9, 4.5, 4.5), ("East African rift", 35, -3, 3, 6), ("Drakensberg", 29, -29, 3.5, 3),
    ("Cameroon", 10, 5.5, 2, 2), ("Rockies", -110, 46, 5, 15), ("Canadian Rockies", -122, 58, 5, 5), ("Sierra Nevada and Cascades", -121, 42, 2.5, 9), ("Sierra Madre", -104, 24, 4, 7),
    ("Sierra Madre del Sur", -99, 18, 5, 2), ("Central America", -85, 13, 5, 3), ("Andes north", -75, -3, 4, 9), ("Andes Colombia", -72, 5, 3, 4), ("Andes centre", -69, -20, 3, 15),
    ("Andes south", -71, -40, 2, 15), ("Guiana highlands", -62, 5, 4, 2.5), ("Japan", 138, 36, 3, 4), ("Taiwan", 121, 23.5, 0.8, 1.5), ("Yunnan and Sichuan", 102, 28, 5, 5), ("Qinling", 108, 34, 5, 1.2),
    ("Annamite", 106, 17, 2, 6), ("New Guinea", 143, -5.5, 8, 2), ("Southern Alps", 170, -44, 3, 3),
]
FOREST_E = [
    ("Amazon", -62, -4, 16, 7.5), ("Guianas", -58, 4, 5, 2.5), ("Atlantic forest", -45, -22, 4, 6), ("Congo basin", 22, 0, 11, 6.5), ("Guinea coast", -5, 6.5, 10, 2.2), ("Madagascar east", 49, -17, 1, 6),
    ("mainland Southeast Asia", 101, 16, 8, 9), ("Malay archipelago", 108, 0, 20, 6), ("Philippines", 122, 12, 3, 7), ("southern China", 112, 26, 8, 4), ("Japan woods", 138, 37, 4, 5),
    ("Korea", 128, 38, 2, 4), ("Siberian taiga", 70, 60, 55, 6.5), ("eastern taiga", 130, 58, 15, 6), ("Fennoscandia", 25, 62, 10, 4), ("Canadian boreal", -95, 56, 30, 7), ("Alaska", -150, 64, 12, 4),
    ("eastern America", -85, 38, 8, 8), ("Pacific Northwest", -123, 47, 3, 5), ("Black Forest and Bavaria", 10, 49, 5, 2), ("Ardennes", 5, 50, 2, 1), ("Poland-Lithuania woods", 23, 54, 7, 2),
]
STEPPE_E = [
    ("Eurasian steppe", 60, 50, 35, 3.5), ("Mongolia", 105, 47, 15, 3), ("Pontic steppe", 35, 48, 8, 2.5), ("Anatolian plateau", 33, 39, 5, 1.5), ("Iranian plateau", 57, 33, 8, 5),
    ("Great Plains", -100, 41, 8, 10), ("Patagonia", -68, -45, 5, 8), ("Pampas", -62, -34, 7, 6), ("Sahel", 10, 13, 28, 3.5), ("East African savanna", 35, -6, 6, 8),
    ("southern African veldt", 26, -26, 8, 6), ("northern Australia", 135, -17, 12, 3),
]
FOOT = 1.5      # the foothills of a range: the same ellipse this much wider (hills)

def inside(e, lon, lat, k=1.0):
    _, cx, cy, hx, hy = e
    return ((lon - cx) / (hx * k)) ** 2 + ((lat - cy) / (hy * k)) ** 2 <= 1.0

out = bytearray(P)
count = [0] * 6
for p in range(P):
    lon, lat = w["lon"][p], w["lat"][p]
    if any(inside(e, lon, lat) for e in MARSH_E): t = MARSH
    elif any(inside(e, lon, lat) for e in MOUNTAIN_E): t = MOUNTAIN
    elif any(inside(e, lon, lat) for e in FOREST_E): t = FOREST
    elif (geo[p] & 2) or (geo[p] & 4) or any(inside(e, lon, lat) for e in STEPPE_E): t = STEPPE
    elif any(inside(e, lon, lat, FOOT) for e in MOUNTAIN_E): t = HILLS
    else: t = HILLS if zlib.crc32(w["id"][p].encode()) % 100 < 20 else PLAINS
    out[p] = t; count[t] += 1
open(os.path.join(root, "terrain.bin"), "wb").write(bytes(out))
names = ["plains", "hills", "mountain", "forest", "marsh", "steppe"]
print("terrain.bin: %d provinces: " % P + ", ".join("%s %d (%d%%)" % (names[i], count[i], round(100 * count[i] / P)) for i in range(6)))
