#!/usr/bin/env python3
"""Broken-link audit (static, no engine): res:// targets, translation keys (used in code vs present, parity en / ru / uz, placeholder sets), era data cross references.
Usage: tools/audit_links.py   -> prints findings, exit 1 when there are any (run by tools/test_all.sh)."""
import re, glob, os, json, sys
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot')
bad = []

def rd(f): return open(f, encoding='utf-8', errors='ignore').read()

# 1. res:// targets
for f in glob.glob(R + '/src/**/*.gd', recursive=True) + glob.glob(R + '/src/**/*.tscn', recursive=True) + glob.glob(R + '/*.tscn') + [R + '/project.godot']:
    for m in re.finditer(r'"(res://[^"]*)"', rd(f)):
        p = m.group(1)
        if '%' in p or '{' in p or p.endswith('/'): continue
        if not os.path.exists(R + '/' + p[6:]): bad.append('missing resource %s (in %s)' % (p, os.path.relpath(f, R)))

# 2. translation keys
L = {l: json.load(open(R + '/data/i18n/%s.json' % l, encoding='utf-8')) for l in ('en', 'ru', 'uz')}
en = L['en']
for l in ('ru', 'uz'):
    for k in en:
        if k not in L[l]: bad.append('%s lacks key %s' % (l, k))
    for k in L[l]:
        if k not in en: bad.append('%s has a key en lacks: %s' % (l, k))
    for k in en:
        if k in L[l]:
            pe = set(re.findall(r'\{(\w+)\}', en[k])); pl = set(re.findall(r'\{(\w+)\}', L[l][k]))
            if pe != pl: bad.append('%s placeholders differ for %s: %s vs %s' % (l, k, sorted(pe), sorted(pl)))
    for k, v in L[l].items():
        if isinstance(v, str) and v.strip() == '': bad.append('%s empty text for %s' % (l, k))
used = {}
pat = re.compile(r'(?:\bT\.call|\bTBI18n\.T|\bT|\btr)\(\s*"([a-z0-9_]+)"')
for f in glob.glob(R + '/src/**/*.gd', recursive=True):
    s = rd(f)
    for m in pat.finditer(s): used.setdefault(m.group(1), os.path.relpath(f, R))
# every string that looks like a key and exists is fine; a used key that does not exist is a bug
dyn = [k for k in used if k.endswith('_') or k == 'key']
for k, f in sorted(used.items()):
    if k in dyn: continue
    if k not in en: bad.append('code uses missing key "%s" (%s)' % (k, f))

# 3. era data
eras = [os.path.basename(p)[:-5] for p in glob.glob(R + '/data/eras/*.json')]
world = json.load(open(R + '/data/world.json', encoding='utf-8'))
for e in eras:
    try: d = json.load(open(R + '/data/eras/%s.json' % e, encoding='utf-8'))
    except Exception as ex: bad.append('era %s does not parse: %s' % (e, ex)); continue
    for k in ('era_%s' % e, 'blurb_%s' % e):
        if k not in en: bad.append('era %s lacks the text %s' % (e, k))
print('checked: %d eras, %d keys in code, %d keys in en' % (len(eras), len(used), len(en)))
for b in bad: print('BROKEN:', b)
print('AUDIT_LINKS OK' if not bad else 'AUDIT_LINKS %d findings' % len(bad))
sys.exit(1 if bad else 0)
