#!/bin/bash
# Rebuilds godot/data/coast.bin.gz and godot/data/prov_bbox.bin.gz: for every sea texel of the province-id map (ids.bin.gz), its distance in texels to the nearest land, at half the map's resolution, as float16.
# prov_bbox.bin.gz: each province's bounding box in id texels (the map redraws only the part of the screen a hover or selection changes). The map shader reads coast.bin.gz for the coastal glow (one texture read instead of 8 + up to 40 probes per sea pixel). Only needed when ids.bin.gz changes.
set -e
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
gcc -O2 -o "$tmp/edt" tools/coast_edt.c -lm
gzip -dc godot/data/ids.bin.gz > "$tmp/ids.bin"
"$tmp/edt" "$tmp/ids.bin" "$tmp/coast.raw"
gzip -9 -c "$tmp/coast.raw" > godot/data/coast.bin.gz
gcc -O2 -o "$tmp/bb" tools/prov_bbox.c
"$tmp/bb" "$tmp/ids.bin" "$tmp/bbox.raw" "$(python3 -c "import json;print(json.load(open('godot/data/world.json'))['P'])")"
gzip -9 -c "$tmp/bbox.raw" > godot/data/prov_bbox.bin.gz
rm -rf "$tmp"; echo "wrote godot/data/coast.bin.gz and godot/data/prov_bbox.bin.gz"
