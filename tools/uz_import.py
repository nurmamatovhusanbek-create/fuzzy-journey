#!/usr/bin/env python3
"""Applies a reviewed sheet (tools/uz_review.py) to godot/data/i18n/uz.json: every row whose 'Corrected (native)' cell is filled replaces the string. Placeholders ({k}, {n}...) must be the same set as in
the English text, or the row is refused. Apostrophes are normalised (oʻ gʻ = U+02BB, tutuq = U+02BC). Usage: python3 tools/uz_import.py <reviewed.csv> [--dry]"""
import csv, json, os, re, sys
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
P = os.path.join(root, 'godot', 'data', 'i18n')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
def fix(v):
    out = []
    for i, ch in enumerate(v):
        if ch in "'‘’`´ʻʼ":
            pre = v[i - 1] if i > 0 else ''
            out.append('ʻ' if (pre.lower() in ('o', 'g') and pre.isalpha()) else 'ʼ')
        else: out.append(ch)
    return ''.join(out)
uz = json.load(open(os.path.join(P, 'uz.json'), encoding='utf-8')); en = json.load(open(os.path.join(P, 'en.json'), encoding='utf-8'))
ph = lambda s: sorted(re.findall(r'\{[a-z_0-9]+\}', s))
n = 0; bad = 0
for r in csv.DictReader(open(sys.argv[1], encoding='utf-8-sig')):
    c = (r.get('Corrected (native)') or '').strip()
    if not c: continue
    k = r['Key']
    if k not in uz: print('unknown key', k); bad += 1; continue
    c = fix(c)
    if ph(c) != ph(en[k]): print('PLACEHOLDERS differ in', k, ph(en[k]), ph(c)); bad += 1; continue
    if c != uz[k]: uz[k] = c; n += 1
print(n, 'strings changed,', bad, 'refused')
if '--dry' not in sys.argv and n: json.dump(uz, open(os.path.join(P, 'uz.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
