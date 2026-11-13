#!/usr/bin/env python3
"""Builds the Uzbek review sheet for native speakers: godot/data/i18n -> uz_review.csv (UTF-8 with BOM, opens in Excel / Google Sheets).
Tier 1 = the glossary (terms used in hundreds of places: decide these first); Tier 2 = short UI strings (<= 48 characters: buttons, labels, gauges, tips titles); Tier 3 = the rest.
A native writes the better text in the 'Corrected' column (leave empty = fine as it is). `tools/uz_import.py uz_review.csv` applies the corrections (placeholders are checked).
Usage: python3 tools/uz_review.py <out.csv> [--since <git rev>]   (--since: only keys that are new or changed since that commit)"""
import csv, json, os, subprocess, sys
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
I = os.path.join(root, 'godot', 'data', 'i18n')
en = json.load(open(os.path.join(I, 'en.json'), encoding='utf-8')); ru = json.load(open(os.path.join(I, 'ru.json'), encoding='utf-8')); uz = json.load(open(os.path.join(I, 'uz.json'), encoding='utf-8'))
out = sys.argv[1]
only = None
if '--since' in sys.argv:
    rev = sys.argv[sys.argv.index('--since') + 1]
    old = json.loads(subprocess.run(['git', 'show', rev + ':godot/data/i18n/uz.json'], capture_output=True, text=True, cwd=root).stdout)
    only = {k for k, v in uz.items() if old.get(k) != v}
gl = json.load(open(os.path.join(root, 'tools', 'uz_glossary.json'), encoding='utf-8'))
rows = []
for g in gl:
    for k in g['keys']:
        rows.append(['1 glossary', k, en.get(k, g['term']), ru.get(k, ''), uz.get(k, g['now']), g['suggest'], '', g['why']])
done = {r[1] for r in rows}
for k in sorted(uz):
    if k in done or (only is not None and k not in only): continue
    tier = '2 short UI' if len(uz[k]) <= 48 else '3 text'
    rows.append([tier, k, en.get(k, ''), ru.get(k, ''), uz[k], '', '', ''])
rows.sort(key=lambda r: (r[0], r[1]))
with open(out, 'w', newline='', encoding='utf-8-sig') as f:
    w = csv.writer(f); w.writerow(['Tier', 'Key', 'English', 'Russian', 'Uzbek now', 'Suggested (Claude)', 'Corrected (native)', 'Why / note'])
    w.writerows(rows)
print(len(rows), 'rows ->', out)
