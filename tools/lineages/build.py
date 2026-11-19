#!/usr/bin/env python3
"""spec.json + the era files -> godot/data/lineages.json (one entry per stage with the stage's core provinces, from the era where the tag stands). Usage: python3 tools/lineages/build.py"""
import json, os, sys
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
eras = ['ancient', 'roman', 'medieval', 'mongol', 'timurid', 'discovery', 'gunpowder', 'napoleonic', 'victorian', 'ww1', 'ww2', 'coldwar']
E = {e: json.load(open(os.path.join(root, 'godot/data/eras', e + '.json'), encoding='utf-8')) for e in eras}
spec = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'spec.json'), encoding='utf-8'))
def core_of(tag):
    best = None
    for e in eras:                                              # the era where the tag held most land
        d = E[e]
        ids = [n['id'] for n in d['nations']]
        if tag not in ids: continue
        k = ids.index(tag) + 1
        prov = [p for p, o in enumerate(d['owner']) if int(o) == k]
        if best is None or len(prov) > len(best[1]): best = (e, prov, d['nations'][k - 1]['name'], d['year'])
    return best
out = []; bad = 0
for line, stages in spec['lines'].items():
    for i, s in enumerate(stages):
        src = s.get('core_from', s['tag'])
        c = core_of(src)
        if c is None: print('NO CORE for', s['tag']); bad += 1; continue
        era, prov, nm, yr = c
        out.append({'id': s['tag'], 'line': line, 'order': i, 'name': s.get('name', nm), 'era': era if s.get('core_from') is None else core_of(s['tag'])[0] if core_of(s['tag']) else era,
                    'year': int(s['year']), 'regimes': s['regimes'], 'from': s.get('from', []), 'any': bool(s.get('any', False)), 'share': float(s.get('share', 0.5)), 'min': int(s.get('min', 4)),
                    'w': int(s.get('w', 1)), 'core': prov})
json.dump({'version': 1, 'stages': out}, open(os.path.join(root, 'godot/data/lineages.json'), 'w', encoding='utf-8'), separators=(',', ':'))
print(len(out), 'stages;', bad, 'problems;', sum(len(s['core']) for s in out), 'core entries')
for s in out: print(f"{s['id']:24s} {s['line']:10s} core {len(s['core']):4d} need {max(s['min'], int(s['share']*len(s['core']))):4d} year {s['year']} regimes {s['regimes']}")
