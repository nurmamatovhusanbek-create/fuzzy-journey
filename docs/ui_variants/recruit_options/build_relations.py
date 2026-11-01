#!/usr/bin/env python3
"""The relations part of the country card (allies, royal marriage, pacts, wars, trade): three mockups on the game's own parts, real flags and real figures (contact from TBDiplo, troops at the 1492 start).
Run from recruit_options; writes ../card_options/rel_*.html. All class names are prefixed rl- (the shared sheet already uses .tag / .tg / .more for other things)."""
import json
src=open('build_calls.py').read()
exec(src[:src.index("# ---- C1")])
OUT='../card_options/'
INFO=json.load(open(OUT+'relinfo.json'))
CSSR="""
.rl-card{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);width:640px;filter:drop-shadow(0 20px 50px #000d)}
.rl-head{display:flex;align-items:center;gap:14px;height:52px;margin-bottom:6px}
.rl-ic{width:44px;height:44px;border-radius:50%;border:1.5px solid var(--brass);display:grid;place-items:center;color:var(--hi);flex:none;font-size:18px}
.rl-head h2{margin:0;font:900 20px/1.1 Cinzel;letter-spacing:.1em;color:var(--ivory);white-space:nowrap}
.rl-head small{display:block;font:italic 400 13px/1.2 Alegreya;letter-spacing:0;color:var(--dim);margin-top:3px}
.rl-gh{display:flex;align-items:center;gap:10px;height:28px;margin-top:10px;font:600 10.5px/1 Cinzel;letter-spacing:.2em;color:var(--hi);text-transform:uppercase}
.rl-gh.w{color:#ee8a68}
.rl-gh .n{display:inline-flex;align-items:center;justify-content:center;height:20px;min-width:20px;padding:0 6px;box-sizing:border-box;border-radius:10px;background:#100d09;box-shadow:inset 0 0 0 1px #3a2f1d;font:700 12.5px/1 Alegreya;letter-spacing:0;color:var(--ivory)}
.rl-gh:after{content:"";flex:1;height:1px;background:#3a2f1d}
.rl-g2{display:grid;grid-template-columns:1fr 1fr;column-gap:16px}
.rl-row{display:flex;align-items:center;gap:10px;height:38px;box-sizing:border-box;border-bottom:1px solid #2a2216;min-width:0}
.rl-fl{width:28px;height:28px;border-radius:50%;box-shadow:0 0 0 1.5px #C9A24B;flex:none;display:block;object-fit:cover}
.w .rl-fl,.rl-row.w .rl-fl{box-shadow:0 0 0 1.5px #B4543A}
.rl-nm{flex:1;min-width:0;font:700 12px/1.2 Cinzel;letter-spacing:.06em;color:var(--ivory);text-transform:uppercase;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.rl-ct{flex:none;font:400 12.5px/1 Alegreya;color:var(--dim);white-space:nowrap}
.rl-ct.b{color:var(--good)} .rl-ct.x{color:#ee8a68}
.rl-more{display:flex;align-items:center;height:30px;margin-top:6px}
.rl-more span{display:inline-flex;align-items:center;height:28px;padding:0 12px;box-sizing:border-box;border-radius:14px;font:600 13px/1 Alegreya;color:var(--hi);box-shadow:inset 0 0 0 1px #7F6A33;background:#100d09}
.rl-line{display:flex;align-items:center;gap:16px;height:54px;box-sizing:border-box;border-bottom:1px solid #2a2216}
.rl-lab{width:132px;flex:none;display:flex;align-items:baseline;gap:8px;font:600 10.5px/1 Cinzel;letter-spacing:.14em;color:var(--hi);text-transform:uppercase;white-space:nowrap}
.rl-lab b{font:700 15px/1 Alegreya;letter-spacing:0;color:var(--ivory)}
.rl-lab.w{color:#ee8a68}
.rl-st{display:flex;align-items:center;gap:8px;flex:1;min-width:0}
.rl-st .rl-fl{width:34px;height:34px}
.rl-st .rl-p{display:inline-flex;align-items:center;justify-content:center;height:30px;min-width:34px;padding:0 9px;box-sizing:border-box;border-radius:15px;font:600 13px/1 Alegreya;color:var(--hi);box-shadow:inset 0 0 0 1px #7F6A33;background:#100d09}
.rl-tabs{display:flex;gap:6px;height:30px;margin:6px 0 4px}
.rl-tabs span{display:inline-flex;align-items:center;justify-content:center;height:30px;padding:0 12px;box-sizing:border-box;font:600 10.5px/1 Cinzel;letter-spacing:.14em;text-transform:uppercase;color:var(--dim);background:#100d09;box-shadow:inset 0 0 0 1px #3a2f1d}
.rl-tabs span.on{color:#1b1408;background:linear-gradient(180deg,#EBCF85,#B38F3E);box-shadow:none}
.rl-th{display:grid;grid-template-columns:28px 1fr 120px 70px 56px;column-gap:10px;align-items:center;height:26px;font:600 10px/1 Cinzel;letter-spacing:.16em;text-transform:uppercase;color:var(--dim);border-bottom:1px solid #3a2f1d}
.rl-tr{display:grid;grid-template-columns:28px 1fr 120px 70px 56px;column-gap:10px;align-items:center;height:42px;box-sizing:border-box;border-bottom:1px solid #2a2216;min-width:0}
.rl-tr .rl-nm{flex:none}
.rl-ty{display:inline-flex;align-items:center;justify-content:center;height:22px;width:112px;box-sizing:border-box;border-radius:11px;font:600 12.5px/1 Alegreya;background:#100d09;box-shadow:inset 0 0 0 1px #3a2f1d;color:var(--dim)}
.rl-ty.a{color:var(--good)} .rl-ty.w{color:#ee8a68} .rl-ty.t{color:var(--info)} .rl-ty.m{color:#e5c77a}
.rl-r{text-align:right;font:400 12.5px/1 Alegreya;color:var(--dim);white-space:nowrap}
.rl-r.n{font:700 14px/1 Alegreya;color:var(--ivory)}
.rl-foot{display:flex;justify-content:space-between;margin-top:8px;font:400 13px/1.2 Alegreya;color:var(--dim)}
"""
def page7(title,inner):
    return ('<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s%s%s%s%s</style></head><body><div class="veil" style="background:rgba(4,6,10,.55)"></div>%s</body></html>')%(title,CSS2,EXTRA2,EXTRA3,EXTRA4,CSSR,inner)
def flag(i,w=False): return '<img class="rl-fl%s" src="flags/%s.png">'%(' w' if w else '',i)
def tag(i):
    c=INFO[i]['contact']; return {'border':('border','b'),'near':('near',''),'far':('far',''),'none':('no contact','x')}[c]
def head(): return '<div class="rl-head"><div class="rl-ic">&#9819;</div><div><h2>Temuriylar amirliklari</h2><small>Shoh Selim &middot; relations</small></div></div>'
def nm(i): return INFO[i]['name']
ALLY=['bengal','malacca','malaysian_islamic_states','zayyanid_caliphate','mi_kma_ki','congo','benin','delaware','andean_hunter_gatherers']
MARRY=['chagatai_khanate']
NAP=['hausa_states','alwa','athabaskan','madagascar','khoiasan']
WAR=['emirate_of_the_white_sheep_turks','sultanate_of_delhi']
TRADE=['ming_chinese_empire','papal_states']
ORD={'border':0,'near':1,'far':2,'none':3}
def srt(l): return sorted(l,key=lambda i:(ORD[INFO[i]['contact']],-INFO[i]['army']))
# ---- R1: groups, two columns of flag rows, nearest first, the rest behind "+n more"
def grp(title,ids,show,w=False):
    ids=srt(ids)
    rows=''.join('<div class="rl-row%s">%s<span class="rl-nm">%s</span><span class="rl-ct %s">%s</span></div>'%(' w' if w else '',flag(i,w),nm(i),tag(i)[1],tag(i)[0]) for i in ids[:show])
    more='<div class="rl-more"><span>+%d more</span></div>'%(len(ids)-show) if len(ids)>show else ''
    return '<div class="rl-gh%s">%s <span class="n">%d</span></div><div class="rl-g2">%s</div>%s'%(' w' if w else '',title,len(ids),rows,more)
r1=('<div class="rl-card">'+plate(head()+grp('Allies',ALLY,6)+grp('Royal marriage',MARRY,1)+grp('Non-aggression',NAP,4)+grp('At war',WAR,2,True)+grp('Trade partners',TRADE,2),640,12)+'</div>')
# ---- R2: one line per group: the label with its count and a strip of round flags; the far ones fold into "+n"
def line(label,ids,show,w=False):
    ids=srt(ids)
    fl=''.join(flag(i,w) for i in ids[:show])
    mo='<span class="rl-p">+%d</span>'%(len(ids)-show) if len(ids)>show else ''
    return '<div class="rl-line"><div class="rl-lab%s">%s<b>%d</b></div><div class="rl-st">%s%s</div></div>'%(' w' if w else '',label,len(ids),fl,mo)
r2=('<div class="rl-card">'+plate(head()+line('Allies',ALLY,8)+line('Marriage',MARRY,1)+line('Pacts',NAP,5)+line('At war',WAR,2,True)+line('Trade',TRADE,2)
   +'<div class="rl-foot"><span>Tap a flag to open that nation. Neighbours first; the far ones fold into the number.</span></div>',640,12)+'</div>')
# ---- R3: one ledger, every country once: tie, nearness, troops; the filters on top
def trow(i,ty,cls):
    return '<div class="rl-tr">%s<span class="rl-nm">%s</span><span class="rl-ty %s">%s</span><span class="rl-r">%s</span><span class="rl-r n">%s</span></div>'%(flag(i,cls=='w'),nm(i),cls,ty,tag(i)[0],f"{INFO[i]['army']:,}".replace(',',' '))
rows=[('emirate_of_the_white_sheep_turks','At war','w'),('sultanate_of_delhi','At war','w'),('chagatai_khanate','Royal marriage','m'),('ming_chinese_empire','Trade','t'),('papal_states','Trade','t'),('bengal','Ally','a'),('alwa','Pact','')]
r3=('<div class="rl-card">'+plate(head()+'<div class="rl-tabs"><span class="on">All 19</span><span>Allies 9</span><span>Pacts 5</span><span>War 2</span><span>Trade 2</span></div>'
   +'<div class="rl-th"><span></span><span>Country</span><span style="text-align:center">Tie</span><span class="rl-r">Contact</span><span class="rl-r">Troops</span></div>'+''.join(trow(*r) for r in rows)
   +'<div class="rl-foot"><span>War first, then the nearest. Scroll for the rest.</span></div>',640,12)+'</div>')
for n,h in [('R1_groups',r1),('R2_flagstrips',r2),('R3_ledger',r3)]:
    open(OUT+'rel_%s_desk.html'%n,'w').write(page7(n,h))
print('ok')
