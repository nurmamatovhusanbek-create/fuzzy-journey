#!/bin/bash
# rebuild every era: spec -> map -> local flag-icons copies -> PNGs -> credits.  usage: tools/flags/rebuild_all.sh
cd "$(dirname "$0")/../.."
for e in coldwar ww2 ww1 victorian napoleonic gunpowder discovery timurid mongol medieval roman ancient; do
  [ -f tools/flags/specs/$e.py ] && python3 tools/flags/specs/$e.py
  [ -f tools/flags/specs/$e.json ] && python3 tools/flags/build_map.py $e | tail -n 1 | cut -c1-110
  python3 tools/flags/local_copy.py $e /home/user/lipis/flag-icons | head -1
  node tools/flags/rasterize.mjs $e | tail -n 1 | cut -c1-110
  python3 tools/flags/attribution.py $e > /dev/null
done
