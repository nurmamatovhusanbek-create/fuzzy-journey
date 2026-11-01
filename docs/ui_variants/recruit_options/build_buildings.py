#!/usr/bin/env python3
"""The Build tab of a province: three mockups on the game's own parts, with the real buildings, costs, times, effects and rules (docs: godot/src/engine/data.gd BUILDINGS, i18n b_* / bd_* / bp_*).
Scenario: a province with 2 slots, a Farm (level 1) built, a Watchtower being built, 3122 gold, learning 2.7, 6 move points. Nothing moves when another building is chosen:
every box has one fixed size. Run from recruit_options; writes ../building_options/bld_*.html. Classes are prefixed bd-."""
import json
src=open('build_calls.py').read()
exec(src[:src.index("# ---- C1")])
OUT='../building_options/'
IC=json.load(open(OUT+'icons.json'))
def svg(i,sz=22,col='currentColor',sw=1.8): return '<svg viewBox="0 0 24 24" width="%d" height="%d" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round">%s</svg>'%(sz,sz,col,sw,IC[i])
CHECK='<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'
CROSS='<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>'
# id: (name, effect, [(cost, turns, tech, moves) per level])
B={'fortress':('Fortress','Defenders fight harder.',[(150,3,0.5,1),(220,4,1.5,2)]),
 'armory':('Armory','Recruits here cost half.',[(100,4,0.4,1)]),
 'port':('Port','Armies may sail from here.',[(120,1,0.0,1)]),
 'market':('Market','More gold from taxes.',[(100,1,0.0,1)]),
 'watchtower':('Watchtower','See armies three provinces out. A watchful eye on foreign agents: +2 % guard each, up to 12 %.',[(60,1,0.0,1)]),
 'supplycamp':('Supply camp','Armies here do not starve.',[(90,3,0.3,1)]),
 'library':('Library','More research every turn.',[(90,2,0.0,1),(160,3,0.8,1),(260,4,2.0,2)]),
 'farm':('Farm','More people every turn.',[(50,1,0.0,1),(70,1,0.0,1),(90,2,0.5,1),(110,2,1.0,1),(130,3,1.5,2)]),
 'workshop':('Workshop','More goods every turn.',[(80,4,0.0,1),(140,5,0.6,1),(200,6,1.2,2)])}
ORDER=['fortress','armory','port','market','watchtower','supplycamp','library','farm','workshop']
STATE={'farm':('built',1),'watchtower':('busy',1)}      # built level / being built
GOLD=3122; TECH=2.7; MOVES=6; SLOTS=2; USED=2
def info(i):
    name,eff,lv=B[i]; st=STATE.get(i)
    cur=st[1] if st and st[0]=='built' else 0
    nxt=min(cur+1,len(lv)); cost,turns,tech,mv=lv[nxt-1]
    if st and st[0]=='busy': tag=('Building · 1 turn','busy')
    elif cur>0 and cur<len(lv): tag=('Level %d of %d'%(cur,len(lv)),'built')
    elif cur>0: tag=('Complete','built')
    elif USED>=SLOTS: tag=('No free slot','no')
    else: tag=('',''); 
    checks=[]
    if cur>0: checks.append((True,'Upgrades the building already here'))
    elif USED<SLOTS: checks.append((True,'A free building slot (%d of %d used)'%(USED,SLOTS)))
    else: checks.append((False,'No free slot'))
    checks.append((TECH>=tech,'Learning %.1f reached'%tech if TECH>=tech else 'Learning %.1f needed'%tech))
    checks.append((GOLD>=cost,'%d gold in the treasury'%cost if GOLD>=cost else '%d gold needed'%cost))
    checks.append((MOVES>=mv,'%d move available'%mv if MOVES>=mv else '%d move needed'%mv))
    ok=all(c[0] for c in checks) and not (st and st[0]=='busy') and not (cur>=len(lv))
    return dict(id=i,name=name,eff=eff,lv=len(lv),cur=cur,nxt=nxt,cost=cost,turns=turns,tech=tech,mv=mv,tag=tag,checks=checks,ok=ok,busy=bool(st and st[0]=='busy'))
CSSB="""
.bd-card{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);filter:drop-shadow(0 20px 50px #000d)}
.bd-hd{display:flex;align-items:center;height:30px;gap:12px;font:600 11px/1 Cinzel;letter-spacing:.2em;color:var(--hi);text-transform:uppercase}
.bd-hd .s{margin-left:auto;color:var(--dim);letter-spacing:.14em}
.bd-hd .g{color:var(--hi);letter-spacing:.14em}
.bd-rule{height:12px;margin:2px 0 10px;background:repeating-linear-gradient(90deg,#7F6A33 0 1px,transparent 1px 8px);opacity:.8}
.bd-ic{width:34px;height:34px;display:grid;place-items:center;flex:none;box-sizing:border-box;border-radius:50%;box-shadow:inset 0 0 0 1.5px var(--brass);color:var(--hi);background:#0f0c09}
.bd-ic.dim{color:#6f5f3d;box-shadow:inset 0 0 0 1.5px #4a3f28}
.bd-pips{display:flex;gap:3px;align-items:center;height:6px}
.bd-pips i{display:block;width:12px;height:5px;box-sizing:border-box;background:#0c0a07;box-shadow:inset 0 0 0 1px #4a3f28}
.bd-pips i.on{background:linear-gradient(#E5C77A,#A8842f);box-shadow:none}
.bd-nm{font:700 12.5px/1.1 Cinzel;letter-spacing:.07em;color:var(--ivory);text-transform:uppercase;white-space:nowrap}
.bd-sub{font:400 12.5px/1.1 Alegreya;color:var(--dim);white-space:nowrap}
.bd-tag{font:600 12.5px/1 Alegreya;white-space:nowrap}
.bd-tag.built{color:var(--good)} .bd-tag.busy{color:#e5c77a} .bd-tag.no{color:#ee8a68}
.bd-price{font:700 13.5px/1 Alegreya;color:var(--ivory);white-space:nowrap;text-align:right}
.bd-price small{display:block;font:400 11.5px/1 Alegreya;color:var(--dim);margin-top:3px}
.bd-chk{display:flex;align-items:center;gap:8px;height:24px;font:400 14px/1.1 Alegreya;color:var(--dim);white-space:nowrap}
.bd-chk svg{flex:none} .bd-chk.y svg{color:var(--good)} .bd-chk.n{color:#ee8a68} .bd-chk.n svg{color:#ee8a68}
.bd-led{display:flex;align-items:center;gap:8px;height:24px;font:400 14.5px/1 Alegreya;color:var(--ivory)}
.bd-led i{flex:1;border-bottom:1px dotted #6b5a30;transform:translateY(-4px)} .bd-led b{font:700 14.5px/1 Alegreya}
.bd-led b.bad{color:#ee8a68}
.bd-eff{font:italic 400 15.5px/1.3 Alegreya;color:var(--dim)}
.bd-btn{display:flex;align-items:center;justify-content:center;height:34px;box-sizing:border-box;font:700 12px/1 Cinzel;letter-spacing:.14em;text-transform:uppercase;white-space:nowrap}
.bd-btn.pri{color:#1b1408;background:linear-gradient(180deg,#EBCF85,#B38F3E);clip-path:polygon(7px 0,calc(100% - 7px) 0,100% 7px,100% calc(100% - 7px),calc(100% - 7px) 100%,7px 100%,0 calc(100% - 7px),0 7px)}
.bd-btn.off{color:#6f5f3d;background:#17120c;box-shadow:inset 0 0 0 1px #3a2f1d}
.bd-btn.sec{color:var(--hi);background:#100d09;box-shadow:inset 0 0 0 1px #7F6A33}
.bd-row{display:flex;align-items:center;gap:10px;height:46px;box-sizing:border-box;padding:0 8px;border-bottom:1px solid #2a2216;min-width:0}
.bd-row.sel{background:rgba(201,162,75,.16);box-shadow:inset 3px 0 0 var(--hi)}
.bd-row .tx{flex:1;min-width:0;display:flex;flex-direction:column;justify-content:center;gap:5px}
.bd-row.dim .bd-nm{color:#8a7d5e}
.bd-tile{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;height:84px;box-sizing:border-box;background:#17120c;box-shadow:inset 0 0 0 1px #3a2f1d;position:relative}
.bd-tile.sel{box-shadow:inset 0 0 0 1.5px var(--hi);background:#1d160c}
.bd-tile .bd-nm{font-size:11.5px}
.bd-tile .st{position:absolute;top:5px;right:7px;font:600 11px/1 Alegreya}
.bd-tabs{display:flex;gap:6px;height:30px;margin:0 0 8px}
.bd-tabs span{display:inline-flex;align-items:center;justify-content:center;height:30px;padding:0 14px;box-sizing:border-box;font:600 10.5px/1 Cinzel;letter-spacing:.14em;text-transform:uppercase;color:var(--dim);background:#100d09;box-shadow:inset 0 0 0 1px #3a2f1d}
.bd-tabs span.on{color:#1b1408;background:linear-gradient(180deg,#EBCF85,#B38F3E);box-shadow:none}
.bd-pg{display:flex;flex-direction:column}
.bd-top{display:flex;align-items:center;gap:12px;height:48px}
.bd-top .bd-ic{width:44px;height:44px}
.bd-top h3{margin:0;font:900 16px/1.1 Cinzel;letter-spacing:.08em;color:var(--ivory);text-transform:uppercase}
"""
def page8(title,inner):
    return ('<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s%s%s%s%s</style></head><body><div class="veil" style="background:rgba(4,6,10,.55)"></div>%s</body></html>')%(title,CSS2,EXTRA2,EXTRA3,EXTRA4,CSSB,inner)
def pips(n,on): return '<div class="bd-pips">%s</div>'%''.join('<i class="%s"></i>'%('on' if k<on else '') for k in range(n))
def head(): return '<div class="bd-hd"><span>Build</span><span class="s">Slots %d of %d</span><span class="g">Gold %d</span></div><div class="bd-rule"></div>'%(USED,SLOTS,GOLD)
def page(b):
    rows=[('Cost','%d gold'%b['cost'],False),('Time','%d turn%s'%(b['turns'],'' if b['turns']==1 else 's'),False),('Moves',str(b['mv']),False),('Treasury after','%d gold'%(GOLD-b['cost']),GOLD-b['cost']<0)]
    led=''.join('<div class="bd-led"><span>%s</span><i></i><b class="%s">%s</b></div>'%(a,'bad' if bad else '',v) for a,v,bad in rows)
    chk=''.join('<div class="bd-chk %s">%s<span>%s</span></div>'%('y' if ok else 'n',CHECK if ok else CROSS,t) for ok,t in b['checks'])
    btn='<div class="bd-btn %s">%s</div>'%('pri' if b['ok'] else 'off','Build · %d gold'%b['cost'] if b['cur']==0 else 'Upgrade · %d gold'%b['cost'])
    dem='<div class="bd-btn sec" style="margin-top:8px">Demolish</div>' if b['cur']>0 else '<div style="height:42px"></div>'
    return b,led,chk,btn,dem
SEL='library'      # the chosen building in the mocks
# ---- BB1: a named rail (icon, name, pips, price) and the page of the chosen one; both boxes keep one size
def rail_row(b,sel):
    ic='<div class="bd-ic %s">%s</div>'%('' if b['ok'] or b['cur']>0 else 'dim',svg(b['id'],20))
    sub=b['tag'][0] or ('%d gold · %d turn%s'%(b['cost'],b['turns'],'' if b['turns']==1 else 's'))
    cls=b['tag'][1] if b['tag'][0] else ''
    return '<div class="bd-row%s%s">%s<div class="tx"><span class="bd-nm">%s</span>%s</div><div class="bd-price">%d<small>gold</small></div></div>'%(' sel' if sel else '',' dim' if not (b['ok'] or b['cur']>0) else '',ic,b['name'],pips(b['lv'],b['cur']),b['cost'])
def bb1():
    bs=[info(i) for i in ORDER]; cur=info(SEL)
    b,led,chk,btn,dem=page(cur)
    rail=''.join(rail_row(x,x['id']==SEL) for x in bs)
    pg=('<div class="bd-pg" style="width:330px"><div class="bd-top"><div class="bd-ic">%s</div><div><h3>%s</h3><div style="margin-top:6px">%s</div></div></div>'
        '<div class="bd-eff" style="height:42px;margin-top:10px">%s</div><div style="margin-top:2px">%s</div><div style="margin-top:8px">%s</div><div style="margin-top:12px">%s</div>%s</div>')%(svg(b['id'],26),b['name'],pips(b['lv'],b['cur']),b['eff'],led,chk,btn,dem)
    return '<div class="bd-card">'+plate(head()+'<div style="display:flex;gap:16px"><div style="width:250px">%s</div>%s</div>'%(rail,pg),640,12)+'</div>'
# ---- BB2: a grid of tiles and a detail strip below, fixed height
def tile(b,sel):
    st='<span class="st bd-tag %s">%s</span>'%(b['tag'][1],('Lv %d'%b['cur']) if b['tag'][1]=='built' else ('Building' if b['busy'] else ('No slot' if b['tag'][1]=='no' else '')))
    return '<div class="bd-tile%s">%s<div class="bd-ic %s">%s</div><span class="bd-nm">%s</span>%s</div>'%(' sel' if sel else '',st,'' if b['ok'] or b['cur']>0 else 'dim',svg(b['id'],20),b['name'],pips(b['lv'],b['cur']))
def bb2():
    bs=[info(i) for i in ORDER]; cur=info(SEL); b,led,chk,btn,dem=page(cur)
    grid='<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:6px">%s</div>'%''.join(tile(x,x['id']==SEL) for x in bs)
    strip=('<div style="display:grid;grid-template-columns:1fr 1fr;gap:20px;margin-top:12px;padding-top:12px;border-top:1px solid #3a2f1d"><div><div class="bd-top" style="height:44px"><div class="bd-ic">%s</div><div><h3>%s</h3><div style="margin-top:6px">%s</div></div></div><div class="bd-eff" style="height:42px;margin-top:8px">%s</div>%s</div>'
           '<div>%s<div style="margin-top:12px">%s</div>%s</div></div>')%(svg(b['id'],26),b['name'],pips(b['lv'],b['cur']),b['eff'],led,chk,btn,dem)
    return '<div class="bd-card">'+plate(head()+grid+strip,640,12)+'</div>'
# ---- BB3: two tabs (Economy / Defence) with a short list each and the page of the chosen one
TABS={'Economy':['farm','workshop','market','library','port'],'Defence':['fortress','armory','watchtower','supplycamp']}
def bb3():
    cur=info(SEL); b,led,chk,btn,dem=page(cur)
    tabs='<div class="bd-tabs"><span class="on">Economy</span><span>Defence</span></div>'
    rail=''.join(rail_row(info(i),i==SEL) for i in TABS['Economy'])
    pad='<div style="height:%dpx"></div>'%(46*(5-len(TABS['Economy'])))
    pg=('<div class="bd-pg" style="width:330px"><div class="bd-top"><div class="bd-ic">%s</div><div><h3>%s</h3><div style="margin-top:6px">%s</div></div></div>'
        '<div class="bd-eff" style="height:42px;margin-top:10px">%s</div><div style="margin-top:2px">%s</div><div style="margin-top:8px">%s</div><div style="margin-top:12px">%s</div>%s</div>')%(svg(b['id'],26),b['name'],pips(b['lv'],b['cur']),b['eff'],led,chk,btn,dem)
    return '<div class="bd-card">'+plate(head()+tabs+'<div style="display:flex;gap:16px"><div style="width:250px">%s%s</div>%s</div>'%(rail,pad,pg),640,12)+'</div>'
for n,h in [('BB1_namedrail',bb1()),('BB2_grid',bb2()),('BB3_tabs',bb3())]:
    open(OUT+'bld_%s_desk.html'%n,'w').write(page8(n,h))
print('ok')
