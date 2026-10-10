"""Summarise a tools/sim.sh run by era.  usage: python3 tools/sim_report.py /tmp/sim/sim.jsonl"""
import json,sys,collections
rows={}
for l in open(sys.argv[1]):
    try: d=json.loads(l)
    except Exception: continue
    rows[(d['era'],d['seed'])]=d
by=collections.defaultdict(list)
for d in rows.values(): by[d['era']].append(d)
order=['ancient','roman','medieval','mongol','timurid','discovery','gunpowder','napoleonic','victorian','ww1','ww2','coldwar','modern']
print(f"{len(rows)} runs\nera        alive0->end  top0->end   hhi   atWar rebels  maxGold  runs where any AI would have won (path:count@earliest turn)           invariant breaks")
for e in order:
    L=by.get(e,[])
    if not L: continue
    n=len(L); last=lambda d,k:d['series'][-1][k]
    fw={}
    for d in L:
        for k,v in d['first_win'].items(): fw.setdefault(k,[]).append(v[0])
    fws=' '.join(f"{k[:4]}:{len(v)}@{min(v)}" for k,v in sorted(fw.items())) or '-'
    print(f"{e:10} {sum(d['alive0'] for d in L)/n:5.0f}->{sum(last(d,'alive') for d in L)/n:4.0f} {sum(d['series'][0]['top'][0] for d in L)/n:5.0f}->{sum(last(d,'top')[0] for d in L)/n:4.0f} {sum(last(d,'hhi') for d in L)/n:6.3f} {sum(last(d,'war') for d in L)/n:5.0f} {sum(last(d,'rebel') for d in L)/n:6.0f} {max(last(d,'gold_max') for d in L):8d}  {fws:60} {sum(1 for d in L if d['bad'])}")
