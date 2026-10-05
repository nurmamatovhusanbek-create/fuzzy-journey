#!/usr/bin/env python3
"""Source of truth for the hand-written scheduled historical events (EN + RU).
Run: python3 tools/events_src.py  -> merges into godot/data/events/sched_<era>.json (ids starting with h_ are regenerated).
Effect shorthand (space separated): g gold, m manpower, s stability(all provinces), d diplomacy pts, mp move pts,
inf infamy, res research, a armies %, p population %, h happiness, dev (+1 development), tr gold next turn, cb+N/T combat bonus N% for T turns."""
import json, re, os, sys

ROOT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'data')
OPS = {'g': 'nation.gold', 'm': 'nation.manpower', 's': 'nation.stability', 'd': 'nation.dp', 'mp': 'nation.mp', 'inf': 'nation.infamy',
       'res': 'nation.research', 'a': 'nation.army_pct', 'p': 'nation.pop_pct', 'h': 'nation.happy', 'tr': 'nation.trade', 'i': 'nation.intel'}

def fx(s):
    out = []
    for tok in s.split():
        if tok == 'dev': out.append({'op': 'nation.dev', 'target': 'self', 'delta': 1}); continue
        m = re.match(r'^cb([+-]\d+)/(\d+)$', tok)
        if m: out.append({'op': 'nation.combat', 'target': 'self', 'delta': int(m.group(1)), 'turns': int(m.group(2))}); continue
        m = re.match(r'^([a-z]+)([+-]\d+)$', tok)
        assert m and m.group(1) in OPS, tok
        out.append({'op': OPS[m.group(1)], 'target': 'self', 'delta': int(m.group(2))})
    return out

EVENTS = {}
def E(era, id, icon, year, month, nation, t_en, t_ru, f_en, f_ru, choices=None, auto=''):
    ev = {'id': 'h_' + id, 'icon': icon, 'scope': 'country' if nation else 'world',
          'trigger': {'year': year, 'monthIdx': month}, 'title': {'en': t_en, 'ru': t_ru}, 'flavor': {'en': f_en, 'ru': f_ru},
          'autoEffects': fx(auto)}
    if nation: ev['trigger']['nation'] = nation
    if choices:
        ev['choices'] = [{'label': {'en': a, 'ru': b}, 'effects': fx(c)} for (a, b, c) in choices]
    EVENTS.setdefault(era, []).append(ev)

exec(open(os.path.join(os.path.dirname(__file__), 'events_content.py'), encoding='utf-8').read())

def main():
    bad = 0
    for era, evs in EVENTS.items():
        path = os.path.join(ROOT, 'events', 'sched_%s.json' % era)
        old = json.load(open(path, encoding='utf-8')) if os.path.exists(path) else []
        keep = [e for e in old if not e['id'].startswith('h_')]
        eras = {}
        ep = os.path.join(ROOT, 'eras', era + '.json')
        ids = None
        if os.path.exists(ep):
            d = json.load(open(ep, encoding='utf-8'))
            ids = {n['id'] for n in d['nations']} | {n['name'] for n in d['nations']}
            start = d['year']
        for e in evs:
            n = e['trigger'].get('nation')
            if ids is not None and n and n not in ids: print('  !! %s: nation %s not in era %s' % (e['id'], n, era)); bad += 1
            if ids is not None and e['trigger']['year'] < start: print('  !! %s dated %d before era start %d' % (e['id'], e['trigger']['year'], start)); bad += 1
        keep.extend(evs)
        keep.sort(key=lambda e: (e['trigger']['year'], e['trigger'].get('monthIdx', 0)))
        json.dump(keep, open(path, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
        print('%-11s %d events (%d new)' % (era, len(keep), len(evs)))
    print('problems:', bad)
    return bad

if __name__ == '__main__': sys.exit(1 if main() else 0)
