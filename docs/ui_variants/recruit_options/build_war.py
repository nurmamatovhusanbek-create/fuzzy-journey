#!/usr/bin/env python3
"""War declaration (rules 4) and the call-to-arms prompt: mockups on the game's own parts. Run from recruit_options; writes ../war_options/war_*.html"""
src=open('build.py').read()
exec(src[:src.index("def pg_old(")])
a=src.index('EXTRA2 = """'); b=src.index("def pgd(")
exec(src[a:b])
OUT='../war_options/'
EXTRA3 = """
.dlg{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);filter:drop-shadow(0 20px 50px #000d)}
.veil{position:absolute;inset:0;background:rgba(18,6,3,.62)}
.rust{--lo:#B4543A}
.war .pin{background:linear-gradient(180deg,#241410,#170d0a)}
.med{width:64px;height:64px;border-radius:50%;border:1.5px solid var(--brass);display:grid;place-items:center;color:var(--hi);background:#0f0c09;margin:0 auto}
.h1{font:900 25px Cinzel;letter-spacing:.1em;color:var(--ivory);text-align:center;margin:10px 0 6px}
.rule{height:12px;margin:2px 0 10px;background:repeating-linear-gradient(90deg,#7F6A33 0 1px,transparent 1px 8px);opacity:.8}
.p{font:400 15.5px/1.4 Alegreya;color:var(--dim);margin:0 0 10px}
.fx{display:flex;align-items:baseline;gap:8px;height:26px;font:400 15px Alegreya;color:var(--ivory)}
.fx i{flex:1;border-bottom:1px dotted #6b5a30;transform:translateY(-4px)}
.fx b{font:700 15px Alegreya;color:#ee8a68} .fx b.g{color:var(--good)} .fx b.n{color:var(--dim)}
.faceoff{display:flex;align-items:center;justify-content:space-between;margin:6px 24px 10px}
.flag{width:56px;height:56px;border-radius:50%;box-shadow:0 0 0 2px #C9A24B;display:grid;place-items:center;font:900 11px Cinzel;color:#fff}
.who{text-align:center;font:700 13px Cinzel;letter-spacing:.12em;color:var(--ivory)} .who small{display:block;font:italic 400 11px Alegreya;letter-spacing:0;color:var(--dim);margin-top:2px}
.sec{font:600 10.5px Cinzel;letter-spacing:.2em;color:var(--hi);text-transform:uppercase;margin:12px 0 6px;display:flex;align-items:center;gap:10px}
.sec:after{content:"";flex:1;height:1px;background:#3a2f1d}
.badge{display:inline-flex;align-items:center;gap:6px;height:24px;padding:0 10px;border-radius:12px;font:600 13.5px Alegreya;background:#100d09;box-shadow:inset 0 0 0 1px #3a2f1d}
.badge.g{color:var(--good)} .badge.b{color:#ee8a68} .badge.n{color:var(--dim)} .badge.i{color:var(--info)}
.row2{display:flex;align-items:center;gap:10px;min-height:34px;border-bottom:1px solid #2a2216;font:400 15px Alegreya}
.row2 .l{flex:1;color:var(--ivory)} .row2 .l small{display:block;color:var(--dim);font-size:12.5px}
.pct{font:700 14px Alegreya;width:48px;text-align:right}
.meter{width:90px;height:8px;background:#0c0a07;box-shadow:inset 0 0 0 1px #4a3f28;border-radius:4px;overflow:hidden} .meter u{display:block;height:100%;background:linear-gradient(#E5C77A,#A8842f)} .meter.g u{background:linear-gradient(#7fcab9,#3f8d7d)} .meter.b u{background:linear-gradient(#e0795a,#a8442b)}
.cols{display:grid;grid-template-columns:1fr 1fr;gap:16px}
.seal{width:76px;height:76px;border-radius:50%;margin:8px auto 4px;display:grid;place-items:center;background:radial-gradient(circle at 36% 30%,#e0795a,#a8442b);box-shadow:0 0 0 3px #3a1a12,0 0 0 4px #B4543A,0 0 24px #e0795a55;color:#fff1e2}
.holdt{font:700 11.5px Cinzel;letter-spacing:.16em;color:#ee8a68;text-align:center;text-transform:uppercase}
.bar{display:flex;gap:10px;justify-content:center;margin-top:8px}
.fl{height:10px}
"""
SW='<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M5 19L18 6M14 5l5-1-1 5M6 6l12 12"/></svg>'
def faceoff(left='FRANCE',lsub='Emperor Napoleon',right='SPAIN',rsub='King Charles IV'):
    t='<div class="faceoff"><div class="who"><div class="flag" style="background:linear-gradient(90deg,#1b3c8c 33%,#fff 33% 66%,#c8202f 66%);margin:0 auto 6px"></div>@L@<small>@LS@</small></div><div style="flex:1;height:1px;background:#8a4632;margin:0 18px;position:relative"><div class="med" style="position:absolute;left:50%;top:-22px;margin-left:-22px;width:44px;height:44px;border-color:#B4543A;color:#ee8a68">@SW@</div></div><div class="who"><div class="flag" style="background:radial-gradient(circle,#fff 0 28%,#c8202f 29% 60%,#f1bf00 61%);margin:0 auto 6px"></div>@R@<small>@RS@</small></div></div>'
    return t.replace('@LS@',lsub).replace('@L@',left).replace('@SW@',SW).replace('@RS@',rsub).replace('@R@',right)
def hdr(title):
    return '<div style="position:relative"><div class="med">%s</div><div class="h1">%s</div><div class="rule"></div></div>'%(SW,title)
def seal(): return '<div class="seal">%s</div><div class="holdt">Hold to declare war</div><div class="bar"><span class="bt" style="min-width:150px">Cancel</span></div>'%SW
def dlg(inner,w=560,cls='war'):
    return '<div class="dlg %s" style="width:%dpx"><div class="plate rust" style="--c:12px"><div class="pin" style="--c:12px;padding:18px 22px 18px">%s</div></div></div>'%(cls,w,inner)
def page(title,inner,kind='desk'):
    return ('<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s%s%s</style></head><body class="%s"><div class="veil"></div>%s</body></html>')%(title,CSS2,EXTRA2,EXTRA3,'' if kind=='desk' else 'phone',inner)

# ---- W1: today's card, extended: the reason, what you may ask at peace, which allies answer
w1=hdr('Declare war on Spain?')+'<p class="p">You have no casus belli, neighbours may form a coalition against you. It costs <b style="color:#ee8a68">3 envoys</b> and cannot be undone.</p>'+faceoff()+(
 '<div class="fx">Envoys<i></i><b>&minus;3</b></div><div class="fx">Their grudge<i></i><b>+40</b></div><div class="fx">Infamy<i></i><b>+8</b></div>'
 '<div class="fx">Casus belli<i></i><b>none</b></div>'
 '<div class="fx">Land of theirs you may ask at peace by right<i></i><b class="n">0 provinces</b></div>'
 '<div class="fx">Will answer Spain&rsquo;s call<i></i><b>Portugal 72 % &middot; Naples 28 %</b></div>'
 '<div class="fx">Will answer your call<i></i><b class="g">Prussia 64 %</b></div>'
 )+seal()
# ---- W2: the two sides
def side(name,items):
    out='<div><div class="sec" style="margin-top:0">%s</div>'%name
    for n,p,col,note in items:
        out+='<div class="row2" style="min-height:40px"><span class="l">%s<small>%s</small></span><div class="meter %s"><u style="width:%d%%"></u></div><span class="pct" style="color:%s">%d%%</span></div>'%(n,note,col,p,'#69B3A2' if col=='g' else ('#ee8a68' if col=='b' else '#E5C77A'),p)
    return out+'</div>'
w2=hdr('Declare war on Spain?')+faceoff()+'<div class="cols">'+side('Spain calls',[('Portugal',72,'b','trust 0.4 · border · near'),('Naples',28,'','far · tired of war')])+side('You call',[('Prussia',64,'g','trust 0.5 · threat · border')])+'</div>'+(
 '<div class="sec">Grounds and goals</div>'
 '<div class="row2"><span class="l">Casus belli</span><span class="badge b">None</span><span class="badge n">no bonus to the war score</span></div>'
 '<div class="row2"><span class="l">Claims on their land</span><span class="badge n">0 provinces</span></div>'
 '<div class="fx" style="margin-top:6px">Cost: <b>&minus;3</b> envoys<i></i>infamy <b>+8</b> · their grudge <b>+40</b></div>')+seal()
# ---- W3: the prompt an ally sees when called
def fac(n,v,col,txt): return '<div class="row2" style="min-height:34px"><span class="l">%s</span><div class="meter %s" style="width:130px"><u style="width:%d%%"></u></div><span class="pct" style="width:56px;color:%s">%s</span></div>'%(n,col,abs(v),'#69B3A2' if col=='g' else '#ee8a68',txt)
w3=('<div class="med" style="width:52px;height:52px">%s</div><div class="h1" style="font-size:21px">Spain calls you to arms</div><div class="rule"></div>'%SW)+'<p class="p">Britain has declared war on Spain, your ally. Join and you are at war with Britain from this turn; refuse and Spain remembers it.</p>'+(
 '<div class="sec">What weighs with you</div>'+fac('Trust in Spain',80,'g','+0.40')+fac('The threat Britain is to you',55,'g','+0.17')+fac('A shared border',100,'g','+0.20')+fac('Distance to the war',40,'b','&minus;0.16')+fac('Your own war weariness',30,'b','&minus;0.09')+
 '<div class="row2" style="border:0;min-height:40px"><span class="l" style="font:700 15px Alegreya">Willingness</span><b style="font:700 18px Alegreya;color:#69B3A2">0.52</b><span class="mut">needs 0.45</span></div>'
 '<div class="sec">If you decline</div><div class="fx">Spain&rsquo;s grudge against you<i></i><b>+20</b></div><div class="fx">Your standing with their friends<i></i><b>&minus;5</b></div>')+'<div class="bar" style="margin-top:14px"><span class="bt pri" style="min-width:170px">%s Join the war</span><span class="bt" style="min-width:150px">Decline</span></div>'%SW
for n,h in [('W1_brief',dlg(w1,560)),('W2_sides',dlg(w2,640)),('W3_calltoarms',dlg(w3,520))]:
    open(OUT+'war_%s_desk.html'%n,'w').write(page(n,h))
print('ok')
