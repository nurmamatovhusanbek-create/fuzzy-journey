#!/usr/bin/env python3
"""The Build tab again, roomier and richer (the player found the first one squeezed and boring): three mockups, real buildings, costs, times and effects (data.gd BUILDINGS, game.gd formulas).
Scenario: a province of development 4 (rules 4: 2 + 4/2 = 4 slots), Farm level 1 built, Watchtower being built, 3122 gold, learning 2.7, 6 move points. Classes are prefixed nb-.
Run from recruit_options; writes ../building_options/new_*.html"""
import json
src=open('build_calls.py').read()
exec(src[:src.index("# ---- C1")])
OUT='../building_options/'
IC=json.load(open(OUT+'icons.json'))
def svg(i,sz=22,sw=1.7): return '<svg viewBox="0 0 24 24" width="%d" height="%d" fill="none" stroke="currentColor" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round">%s</svg>'%(sz,sz,sw,IC[i])
CHECK='<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'
CROSS='<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>'
B={'fortress':('Fortress',[(150,3,0.5,1),(220,4,1.5,2)],['+50 % defence here','+80 % defence here']),
 'armory':('Armory',[(100,4,0.4,1)],['Recruits here cost half']),
 'port':('Port',[(120,1,0.0,1)],['Armies may sail from here']),
 'market':('Market',[(100,1,0.0,1)],['+2 gold a turn from this province']),
 'watchtower':('Watchtower',[(60,1,0.0,1)],['Sees armies three provinces out · +3 % defence · +2 % guard against agents']),
 'supplycamp':('Supply camp',[(90,3,0.3,1)],['Armies here do not starve · their upkeep is 20 % lower']),
 'library':('Library',[(90,2,0.0,1),(160,3,0.8,1),(260,4,2.0,2)],['+1 research per 750 people','+2 research per 750 people','+3 research per 750 people']),
 'farm':('Farm',[(50,1,0.0,1),(70,1,0.0,1),(90,2,0.5,1),(110,2,1.0,1),(130,3,1.5,2)],['+5 % people growth','+10 % people growth','+15 % people growth','+20 % people growth','+25 % people growth']),
 'workshop':('Workshop',[(80,4,0.0,1),(140,5,0.6,1),(200,6,1.2,2)],['+5 % goods','+10 % goods','+15 % goods'])}
ORDER=['farm','workshop','market','library','port','fortress','armory','watchtower','supplycamp']
STATE={'farm':('built',1),'watchtower':('busy',1)}
GOLD=3122; TECH=2.7; MOVES=6; SLOTS=4; USED=2
def info(i):
    name,lv,fx=B[i]; st=STATE.get(i); cur=st[1] if st and st[0]=='built' else 0
    nxt=min(cur+1,len(lv)); cost,turns,tech,mv=lv[nxt-1]
    checks=[]
    if cur>0: checks.append((True,'Upgrades the building already here'))
    elif USED<SLOTS: checks.append((True,'A free slot (%d of %d used)'%(USED,SLOTS)))
    else: checks.append((False,'No free slot'))
    checks.append((TECH>=tech,'Learning %.1f reached'%tech if TECH>=tech else 'Learning %.1f needed'%tech))
    checks.append((GOLD>=cost,'%d gold in the treasury'%cost if GOLD>=cost else '%d gold needed'%cost))
    checks.append((MOVES>=mv,'%d move available'%mv if MOVES>=mv else '%d moves needed'%mv))
    busy=bool(st and st[0]=='busy')
    ok=all(c[0] for c in checks) and not busy and cur<len(lv)
    return dict(id=i,name=name,lv=lv,fx=fx,n=len(lv),cur=cur,nxt=nxt,cost=cost,turns=turns,tech=tech,mv=mv,checks=checks,busy=busy,ok=ok)
CSSN="""
.nb-card{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);filter:drop-shadow(0 22px 56px #000e)}
.nb-hd{display:flex;align-items:center;gap:18px;height:44px}
.nb-hd h2{margin:0;font:900 22px/1 Cinzel;letter-spacing:.12em;color:var(--ivory);text-transform:uppercase}
.nb-hd .r{margin-left:auto;display:flex;align-items:center;gap:20px}
.nb-slots{display:flex;align-items:center;gap:7px;font:600 13.5px/1 Alegreya;color:var(--dim)}
.nb-slots i{display:block;width:14px;height:14px;box-sizing:border-box;border-radius:50%;box-shadow:inset 0 0 0 1.5px #4a3f28}
.nb-slots i.f{background:linear-gradient(#E5C77A,#A8842f);box-shadow:none}
.nb-slots i.b{box-shadow:inset 0 0 0 1.5px var(--hi);background:repeating-linear-gradient(135deg,rgba(229,199,122,.5) 0 2px,transparent 2px 4px)}
.nb-gold{display:flex;align-items:center;gap:8px;height:30px;padding:0 14px;box-sizing:border-box;border-radius:15px;background:#100d09;box-shadow:inset 0 0 0 1px #7F6A33;font:700 15px/1 Alegreya;color:var(--ivory)}
.nb-gold small{font:600 10.5px/1 Cinzel;letter-spacing:.16em;color:var(--hi);text-transform:uppercase}
.nb-rule{height:12px;margin:8px 0 18px;background:repeating-linear-gradient(90deg,#7F6A33 0 1px,transparent 1px 8px);opacity:.8}
.nb-em{display:grid;place-items:center;flex:none;box-sizing:border-box;border-radius:50%;color:var(--hi);background:radial-gradient(circle at 50% 38%,#241b10,#0f0c09 72%);box-shadow:inset 0 0 0 1.5px var(--brass)}
.nb-em.dim{color:#6f5f3d;box-shadow:inset 0 0 0 1.5px #4a3f28}
.nb-em.busy{box-shadow:inset 0 0 0 1.5px var(--hi),0 0 0 3px rgba(229,199,122,.18)}
.nb-em.built{box-shadow:inset 0 0 0 2px #E5C77A,0 0 14px rgba(229,199,122,.25)}
.nb-nm{font:700 14px/1.15 Cinzel;letter-spacing:.07em;color:var(--ivory);text-transform:uppercase;white-space:nowrap}
.nb-sm{font:400 13.5px/1.2 Alegreya;color:var(--dim);white-space:nowrap}
.nb-st{font:600 13px/1 Alegreya;white-space:nowrap}
.nb-st.built{color:var(--good)} .nb-st.busy{color:#e5c77a} .nb-st.no{color:#9a7a66}
.nb-pips{display:flex;gap:4px;align-items:center;height:8px}
.nb-pips i{display:block;width:16px;height:6px;box-sizing:border-box;background:#0c0a07;box-shadow:inset 0 0 0 1px #4a3f28}
.nb-pips i.on{background:linear-gradient(#E5C77A,#A8842f);box-shadow:none}
.nb-disc{display:flex;flex-direction:column;align-items:center;gap:10px;width:88px}
.nb-disc .nb-em{width:60px;height:60px}
.nb-disc.sel .nb-em{box-shadow:inset 0 0 0 2.5px #EBCF85,0 0 0 4px rgba(229,199,122,.28)}
.nb-disc .l{font:600 10.5px/1 Cinzel;letter-spacing:.06em;color:var(--dim);text-transform:uppercase;text-align:center;line-height:12px;height:24px;width:84px}
.nb-disc.sel .l{color:var(--ivory)}
.nb-feat{display:grid;grid-template-columns:300px 1fr;gap:28px;margin-top:22px;padding-top:22px;border-top:1px solid #3a2f1d}
.nb-big{display:flex;align-items:center;gap:18px}
.nb-big h3{margin:0;font:900 24px/1.05 Cinzel;letter-spacing:.08em;color:var(--ivory);text-transform:uppercase}
.nb-eff{font:italic 400 17px/1.35 Alegreya;color:var(--dim)}
.nb-lad{display:flex;flex-direction:column;gap:8px}
.nb-lv{display:flex;align-items:center;gap:14px;height:46px;box-sizing:border-box;padding:0 14px;background:#100d09;box-shadow:inset 0 0 0 1px #2e2517}
.nb-lv.cur{box-shadow:inset 0 0 0 1px #7F6A33;background:#17120c}
.nb-lv.nxt{box-shadow:inset 0 0 0 1.5px var(--hi);background:#1d160c}
.nb-lv .n{width:28px;height:28px;border-radius:50%;display:grid;place-items:center;flex:none;font:700 13px/1 Alegreya;color:var(--dim);box-shadow:inset 0 0 0 1.5px #4a3f28}
.nb-lv.cur .n{color:#1b1408;background:linear-gradient(#EBCF85,#B38F3E);box-shadow:none}
.nb-lv.nxt .n{color:var(--hi);box-shadow:inset 0 0 0 1.5px var(--hi)}
.nb-lv .t{flex:1;min-width:0;font:400 15px/1.2 Alegreya;color:var(--ivory);white-space:nowrap}
.nb-lv .np{display:flex;align-items:center;font:700 14px/1 Alegreya;color:var(--ivory);white-space:nowrap}
.nb-lv .np small{display:inline;font:400 12.5px/1 Alegreya;color:var(--dim);margin-left:8px}
.nb-chk{display:flex;align-items:center;gap:10px;height:28px;font:400 15px/1.1 Alegreya;color:var(--dim);white-space:nowrap}
.nb-chk.y svg{color:var(--good)} .nb-chk.n{color:#ee8a68} .nb-chk.n svg{color:#ee8a68}
.nb-act{display:flex;gap:12px;margin-top:18px}
.nb-btn{display:flex;align-items:center;justify-content:center;height:42px;box-sizing:border-box;font:700 13px/1 Cinzel;letter-spacing:.14em;text-transform:uppercase;white-space:nowrap;flex:1}
.nb-btn.pri{color:#1b1408;background:linear-gradient(180deg,#EBCF85,#B38F3E);clip-path:polygon(8px 0,calc(100% - 8px) 0,100% 8px,100% calc(100% - 8px),calc(100% - 8px) 100%,8px 100%,0 calc(100% - 8px),0 8px)}
.nb-btn.off{color:#6f5f3d;background:#17120c;box-shadow:inset 0 0 0 1px #3a2f1d}
.nb-btn.dm{color:var(--hi);background:#100d09;box-shadow:inset 0 0 0 1px #7F6A33;flex:0 0 150px}
.nb-card3{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}
.nb-cd{display:flex;align-items:center;gap:14px;height:104px;box-sizing:border-box;padding:0 12px 0 14px;background:#17120c;box-shadow:inset 0 0 0 1px #3a2f1d;min-width:0}
.nb-cd.sel{box-shadow:inset 0 0 0 2px var(--hi);background:#1d160c}
.nb-cd .tx{flex:1;min-width:0;display:flex;flex-direction:column;gap:6px}
.nb-cd .nb-nm{font-size:13.5px;letter-spacing:.04em}
.nb-cd .pr{font:700 15px/1 Alegreya;color:var(--ivory);text-align:right;white-space:nowrap}
.nb-cd .pr small{display:block;font:400 12px/1 Alegreya;color:var(--dim);margin-top:5px}
.nb-bar{display:flex;align-items:center;gap:18px;height:84px;box-sizing:border-box;margin-top:18px;padding:0 20px;background:#100d09;box-shadow:inset 0 0 0 1px #7F6A33}
.nb-bar .tx{flex:1;min-width:0;display:flex;flex-direction:column;gap:7px}
.nb-ring{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;width:70px;height:60px;box-sizing:border-box}
.nb-ring b{font:700 17px/1 Alegreya;color:var(--ivory)} .nb-ring small{font:600 10px/1 Cinzel;letter-spacing:.14em;color:var(--dim);text-transform:uppercase}
.nb-bar .nb-btn{flex:0 0 190px} .nb-bar .nb-btn.dm{flex:0 0 130px}
.nb-sec{font:600 11px/1 Cinzel;letter-spacing:.2em;color:var(--hi);text-transform:uppercase;display:flex;align-items:center;gap:12px;height:26px;margin:4px 0 8px}
.nb-sec:after{content:"";flex:1;height:1px;background:#3a2f1d}
.nb-ls{display:flex;align-items:center;gap:14px;height:62px;box-sizing:border-box;padding:0 12px;border-bottom:1px solid #2a2216;min-width:0}
.nb-ls.sel{background:rgba(201,162,75,.15);box-shadow:inset 3px 0 0 var(--hi)}
.nb-ls .tx{flex:1;min-width:0;display:flex;flex-direction:column;gap:7px}
.nb-ls .pr{font:700 15px/1 Alegreya;color:var(--ivory);text-align:right;white-space:nowrap}
.nb-ls .pr small{display:block;font:400 12px/1 Alegreya;color:var(--dim);margin-top:5px}
.nb-two{display:grid;grid-template-columns:300px 1fr;gap:30px}
.nb-need{display:grid;grid-template-columns:1fr 1fr;column-gap:20px}
"""
def page9(title,inner):
    return ('<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s%s%s%s%s</style></head><body><div class="veil" style="background:rgba(4,6,10,.55)"></div>%s</body></html>')%(title,CSS2,EXTRA2,EXTRA3,EXTRA4,CSSN,inner)
def pips(n,on): return '<div class="nb-pips">%s</div>'%''.join('<i class="%s"></i>'%('on' if k<on else '') for k in range(n))
def head():
    dots=''.join('<i class="%s"></i>'%('f' if k<sum(1 for v in STATE.values() if v[0]=='built') else ('b' if k<USED else '')) for k in range(SLOTS))
    return ('<div class="nb-hd"><h2>Build</h2><div class="r"><div class="nb-slots">%s<span style="margin-left:5px">%d of %d slots</span></div><div class="nb-gold"><small>Gold</small>%d</div></div></div><div class="nb-rule"></div>')%(dots,USED,SLOTS,GOLD)
def state_of(b):
    if b['busy']: return ('Building · 1 turn','busy')
    if b['cur']>0 and b['cur']<b['n']: return ('Level %d of %d'%(b['cur'],b['n']),'built')
    if b['cur']>0: return ('Complete','built')
    if USED>=SLOTS: return ('No free slot','no')
    return ('Free to build','')
def emblem(b,sz,ic):
    cls='built' if b['cur']>0 else ('busy' if b['busy'] else ('' if b['ok'] else 'dim'))
    return '<div class="nb-em %s" style="width:%dpx;height:%dpx">%s</div>'%(cls,sz,sz,svg(b['id'],ic))
def checks(b): return ''.join('<div class="nb-chk %s">%s<span>%s</span></div>'%('y' if ok else 'n',CHECK if ok else CROSS,t) for ok,t in b['checks'])
def ladder(b):
    out=[]
    for k in range(b['n']):
        cost,turns,tech,mv=b['lv'][k]; cls='cur' if k+1<=b['cur'] else ('nxt' if k+1==b['cur']+1 else '')
        p='built' if k+1<=b['cur'] else '%d gold<small>%d turn%s</small>'%(cost,turns,'' if turns==1 else 's')
        out.append('<div class="nb-lv %s"><span class="n">%d</span><span class="t">%s</span><span class="np">%s</span></div>'%(cls,k+1,b['fx'][k],p))
    return '<div class="nb-lad">%s</div>'%''.join(out)
def buttons(b):
    verb='Upgrade' if b['cur']>0 else 'Build'
    s='<div class="nb-btn %s">%s · %d gold</div>'%('pri' if b['ok'] else 'off',verb,b['cost'])
    if b['cur']>0: s='<div class="nb-btn dm">Demolish</div>'+s
    return s
# ---- N1: a showcase: the nine buildings as a row of large discs, the chosen one opens into a feature panel with its levels
def n1(sel):
    bs=[info(i) for i in ORDER]
    discs=''.join('<div class="nb-disc%s">%s<span class="l">%s</span></div>'%(' sel' if b['id']==sel else '',emblem(b,60,26),b['name']) for b in bs)
    b=info(sel); st=state_of(b)
    left=('<div class="nb-big">%s<div><h3>%s</h3><div style="margin-top:10px;display:flex;align-items:center;gap:12px">%s<span class="nb-st %s">%s</span></div></div></div>'
          '<div class="nb-eff" style="margin-top:18px;height:46px">%s</div><div style="margin-top:6px">%s</div>')%(emblem(b,84,36),b['name'],pips(b['n'],b['cur']),st[1],st[0],b['fx'][b['cur'] if b['cur']<b['n'] else b['n']-1],checks(b))
    right='<div class="nb-sec">Levels</div>%s<div class="nb-act">%s</div>'%(ladder(b),buttons(b))
    return '<div class="nb-card">'+plate(head()+'<div style="display:flex;justify-content:space-between;padding:0 6px">%s</div><div class="nb-feat"><div>%s</div><div>%s</div></div>'%(discs,left,right),860,12)+'</div>'
# ---- N2: large cards in three columns and an action bar under them, in the language of the recruit and move bars
def card(b,sel):
    st=state_of(b)
    return ('<div class="nb-cd%s">%s<div class="tx"><span class="nb-nm">%s</span><span style="display:flex;align-items:center;gap:10px;height:8px">%s</span><span class="nb-st %s">%s</span><span class="nb-sm" style="font-size:12.5px">%d gold · %d turn%s</span></div></div>')%(' sel' if sel else '',emblem(b,52,24),b['name'],pips(b['n'],b['cur']),st[1],st[0],b['cost'],b['turns'],'' if b['turns']==1 else 's')
def n2(sel):
    bs=[info(i) for i in ORDER]; b=info(sel)
    grid='<div class="nb-card3">%s</div>'%''.join(card(x,x['id']==sel) for x in bs)
    nm=b['fx'][b['cur'] if b['cur']<b['n'] else b['n']-1]
    bar=('<div class="nb-bar">%s<div class="tx"><span class="nb-nm" style="font-size:15px">%s · %s</span><span class="nb-sm">%s</span></div>'
         '<div class="nb-ring"><b>%d</b><small>Gold</small></div><div class="nb-ring"><b>%d</b><small>%s</small></div><div class="nb-ring"><b>%d</b><small>%s</small></div>%s</div>')%(emblem(b,52,24),b['name'],('Level %d'%b['nxt']) if b['cur']<b['n'] else 'Complete',nm,b['cost'],b['turns'],'Turn' if b['turns']==1 else 'Turns',b['mv'],'Move' if b['mv']==1 else 'Moves',buttons(b))
    return '<div class="nb-card">'+plate(head()+grid+bar,900,12)+'</div>'
# ---- N3: a sectioned list (Economy / Defence) with roomy rows and, beside it, the levels and the needs
SEC={'Economy':['farm','workshop','market','library','port'],'Defence':['fortress','armory','watchtower','supplycamp']}
def lrow(b,sel):
    st=state_of(b)
    return ('<div class="nb-ls%s">%s<div class="tx"><span class="nb-nm">%s</span><span style="display:flex;align-items:center;gap:10px;height:14px">%s<span class="nb-st %s">%s</span></span></div><div class="pr">%d<small>%d turn%s</small></div></div>')%(' sel' if sel else '',emblem(b,40,19),b['name'],pips(b['n'],b['cur']),st[1],st[0],b['cost'],b['turns'],'' if b['turns']==1 else 's')
def n3(sel):
    left=''.join('<div class="nb-sec">%s</div>%s'%(k,''.join(lrow(info(i),i==sel) for i in v)) for k,v in SEC.items())
    b=info(sel); st=state_of(b)
    right=('<div class="nb-big">%s<div><h3>%s</h3><div style="margin-top:10px;display:flex;align-items:center;gap:12px">%s<span class="nb-st %s">%s</span></div></div></div>'
           '<div class="nb-eff" style="margin-top:16px;height:48px">%s</div><div class="nb-sec" style="margin-top:10px">Levels</div>%s<div class="nb-sec" style="margin-top:14px">Needs</div><div class="nb-need">%s</div><div class="nb-act">%s</div>')%(emblem(b,72,32),b['name'],pips(b['n'],b['cur']),st[1],st[0],b['fx'][b['cur'] if b['cur']<b['n'] else b['n']-1],ladder(b),checks(b),buttons(b))
    return '<div class="nb-card">'+plate(head()+'<div class="nb-two"><div>%s</div><div>%s</div></div>'%(left,right),860,12)+'</div>'
for n,h in [('N1_showcase_library',n1('library')),('N1_showcase_farm',n1('farm')),('N2_cards_library',n2('library')),('N2_cards_farm',n2('farm')),('N3_sections_library',n3('library')),('N3_sections_farm',n3('farm'))]:
    open(OUT+'new_%s_desk.html'%n,'w').write(page9(n,h))
print('ok')
