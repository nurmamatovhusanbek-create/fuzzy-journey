#!/usr/bin/env python3
"""The Develop modal: four investment projects for one province (real figures: Samarkand in 1400, population 165, economy 3, development 1, stability 84, 400 gold, 6 moves).
Reuses the Build tab's look (build_buildings2 classes nb-). Writes ../building_options/new_V1_cards.html and new_V2_detail.html (render with render2.cjs)."""
src = open('build_buildings2.py').read()
exec(src[:src.index("for n,h in [('N1_showcase_library'")])
PRJ = [
 dict(id='workshop', name='Development', fx='Development 1 → 2 · +20 people · +4 stability', why='', cost=56, turns=3, mv=1, need=[(True,'Workers for the next level (100 %)'),(True,'56 gold in the treasury'),(True,'1 move available')]),
 dict(id='market', name='Economy', fx='Economy 3 → 4 · more gold every turn', why='', cost=125, turns=3, mv=1, warn='165 people can work level 3.4: the new level returns about half', need=[(True,'A level below the maximum'),(True,'125 gold in the treasury'),(True,'1 move available')]),
 dict(id='farm', name='Settlement', fx='+20 people (12 %) · new villages and fields', why='', cost=66, turns=2, mv=1, need=[(True,'Room to grow (165 of 2000)'),(True,'66 gold in the treasury'),(True,'1 move available')]),
 dict(id='armory', name='Public order', fx='+12 stability · courts and charity', why='Stability is already high', cost=46, turns=2, mv=1, need=[(False,'Stability below 80 % (now 84 %)'),(True,'46 gold in the treasury'),(True,'1 move available')]),
]
CSSV = """
.vh{display:flex;align-items:center;gap:14px;margin-top:6px}
.vgrid{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:6px}
.vcard{display:flex;flex-direction:column;gap:12px;padding:16px;background:#17120c;box-shadow:inset 0 0 0 1px #3a2f1d;min-width:0}
.vcard .nb-btn{flex:none;height:42px}
.vcard.sel{box-shadow:inset 0 0 0 2px var(--hi);background:#1d160c}
.vcard.off{opacity:.62}
.vtop{display:flex;align-items:center;gap:14px}
.vfx{font:italic 400 15.5px/1.3 Alegreya;color:var(--dim);min-height:40px}
.vwarn{font:400 13.5px/1.3 Alegreya;color:#e5c77a;min-height:36px}
.vbad{font:400 13.5px/1.3 Alegreya;color:#ee8a68;min-height:36px}
.vchips{display:flex;gap:8px}
.vchip{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:7px;height:64px;background:#100d09;box-shadow:inset 0 0 0 1px #2e2517}
.vchip b{font:700 17px/1 Alegreya;color:var(--ivory)} .vchip small{font:600 9.5px/1 Cinzel;letter-spacing:.16em;color:var(--dim);text-transform:uppercase}
.vlist{display:flex;flex-direction:column;gap:7px}
.vrow{display:flex;align-items:center;gap:16px;height:82px;padding:0 18px;background:#100d09;box-shadow:inset 0 0 0 1px #2e2517}
.vrow.sel{background:rgba(201,162,75,.15);box-shadow:inset 3px 0 0 var(--hi)}
.vrow.off{opacity:.62}
.vstate{display:flex;align-items:center;gap:12px;height:30px;margin-bottom:20px;font:400 14.5px Alegreya;color:var(--dim)}
.vbars{display:flex;gap:18px;margin-top:6px}
.vbar{flex:1;display:flex;flex-direction:column;gap:6px;font:400 13.5px Alegreya;color:var(--dim)}
.vbar i{display:block;height:6px;background:#0c0a07;box-shadow:inset 0 0 0 1px #4a3f28} .vbar i b{display:block;height:100%;background:linear-gradient(#E5C77A,#A8842f)}
"""
def page11(t, inner): return page9(t, inner).replace('</style>', CSSV + '</style>', 1)
def vhead():
    return ('<div class="nb-hd"><h2>Develop · Samarkand</h2><div class="r"><div class="nb-slots"><span>Project: none</span></div><div class="nb-gold"><small>Gold</small>400</div></div></div><div class="nb-rule"></div>')
def state():
    return ('<div class="vstate"><span>Samarkand · 165 people · economy 3 · development 1 · stability 84 %</span></div>')
def chips(p): return '<div class="vchips"><div class="vchip"><b>%d</b><small>Gold</small></div><div class="vchip"><b>%d</b><small>Turns</small></div><div class="vchip"><b>%d</b><small>Move</small></div></div>' % (p['cost'], p['turns'], p['mv'])
def emb(p, sz=52): return emblem(dict(id=p['id'], cur=0, busy=False, ok=not p['why']), sz, int(sz*0.46))
def card(p, sel):
    msg = '<div class="vbad">%s</div>' % p['why'] if p['why'] else ('<div class="vwarn">%s</div>' % p['warn'] if p.get('warn') else '<div class="vfx" style="min-height:36px;font-style:normal;color:#69B3A2">%s</div>' % 'All requirements met')
    btn = '<div class="nb-btn %s">%s</div>' % ('off' if p['why'] else 'pri', 'Start · %d gold' % p['cost'] if not p['why'] else 'Not possible')
    return '<div class="vcard%s%s"><div class="vtop">%s<div><div class="nm" style="font:700 17px Cinzel;letter-spacing:.07em;text-transform:uppercase">%s</div></div></div><div class="vfx">%s</div>%s%s%s</div>' % (' sel' if sel else '', ' off' if p['why'] else '', emb(p), p['name'], p['fx'], chips(p), msg, btn)
def v1():
    return '<div class="nb-card" style="width:900px">' + plate(vhead() + state() + '<div class="vgrid">%s</div>' % ''.join(card(p, i == 0) for i, p in enumerate(PRJ)), 880, 12) + '</div>'
def v2():
    sel = PRJ[0]
    rows = ''.join('<div class="vrow%s%s">%s<div style="flex:1;min-width:0"><div class="nm" style="font:700 15px Cinzel;letter-spacing:.07em;text-transform:uppercase">%s</div><div class="sm" style="margin-top:7px;font-size:13.5px;white-space:normal;line-height:1.25">%s</div></div><div style="text-align:right;font:700 15px Alegreya">%d<small style="display:block;font:400 12px Alegreya;color:#A89C80;margin-top:4px">%d turns</small></div></div>' % (' sel' if i == 0 else '', ' off' if p['why'] else '', emb(p, 44), p['name'], (p['why'] or p['fx'].split(' · ')[0]), p['cost'], p['turns']) for i, p in enumerate(PRJ))
    chk = ''.join('<div class="nb-chk %s">%s<span>%s</span></div>' % ('y' if ok else 'n', CHECK if ok else CROSS, t) for ok, t in sel['need'])
    right = ('<div class="nb-big">%s<div><h3>%s</h3></div></div><div class="nb-eff" style="margin-top:18px;height:56px">%s</div><div style="margin-top:8px">%s</div><div class="nb-sec" style="margin-top:20px">Needs</div>%s<div class="nb-act" style="margin-top:22px">%s</div>') % (emb(sel, 72), sel['name'], sel['fx'], chips(sel), chk, '<div class="nb-btn pri">Start · %d gold</div>' % sel['cost'])
    return '<div class="nb-card" style="width:1000px">' + plate(vhead() + state() + '<div class="nb-two" style="grid-template-columns:1fr 1.05fr;gap:34px"><div class="vlist">%s</div><div>%s</div></div>' % (rows, right), 1000, 12) + '</div>'
for n, h in [('V1_cards', v1()), ('V2_detail', v2())]:
    open(OUT + 'new_%s_desk.html' % n, 'w').write(page11(n, h))
print('ok')
