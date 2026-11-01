#!/usr/bin/env python3
"""Calling allies to war: three mockups on the game's own parts. Run from recruit_options; writes ../war_options/call_*.html"""
src=open('build_war.py').read()
exec(src[:src.index("# ---- W1")])
OUT='../war_options/'
EXTRA4 = """
.card2{background:#17120c;box-shadow:inset 0 0 0 1px #3a2f1d;padding:14px 16px;margin-bottom:10px}
.card2 .t{display:flex;align-items:center;gap:10px}
.card2 .t h3{flex:1;font:900 16px Cinzel;letter-spacing:.08em;color:var(--ivory)}
.card2 .t b{font:700 18px Alegreya;color:var(--ivory)}
.lk{position:relative;height:28px;margin:10px 0 6px;clip-path:polygon(9px 0,calc(100% - 9px) 0,100% 9px,100% calc(100% - 9px),calc(100% - 9px) 100%,9px 100%,0 calc(100% - 9px),0 9px);background:#7F6A33;padding:1px}
.lk div{position:absolute;inset:1px;display:flex;background:#0C0A07;clip-path:polygon(8px 0,calc(100% - 8px) 0,100% 8px,100% calc(100% - 8px),calc(100% - 8px) 100%,8px 100%,0 calc(100% - 8px),0 8px)}
.lk .no{background:repeating-linear-gradient(135deg,rgba(210,96,63,.55) 0 2px,transparent 2px 9px)}
.lk .yes{background:linear-gradient(180deg,#E5C77A,#A8842f)}
.lk span{position:absolute;top:0;bottom:0;display:grid;place-items:center;font:700 16px Alegreya}
.row3{display:flex;gap:10px;align-items:center;justify-content:space-between;margin-top:8px}
.ally{display:flex;align-items:center;gap:12px;height:54px;border-bottom:1px solid #2a2216}
.ally .f{width:38px;height:38px;border-radius:50%;box-shadow:0 0 0 1.5px #C9A24B}
.ally .n{flex:1;font:700 14px Cinzel;letter-spacing:.1em;color:var(--ivory)} .ally .n small{display:block;font:400 12.5px Alegreya;letter-spacing:0;color:var(--dim);margin-top:2px}
.chk{width:22px;height:22px;border:1.5px solid var(--lo);display:grid;place-items:center;color:#1b1408;background:#0e0b07;border-radius:3px;font:900 14px Alegreya}
.chk.on{background:linear-gradient(180deg,#EBCF85,#B38F3E);border-color:#EBCF85}
.mini{display:inline-flex;height:28px;align-items:center;padding:0 10px;font:600 13.5px Alegreya;border-radius:14px;background:#100d09;box-shadow:inset 0 0 0 1px #3a2f1d}
.win{position:absolute;background:linear-gradient(#1b1610,#14100b)}
.dlg2{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);filter:drop-shadow(0 20px 50px #000d)}
.card3{position:absolute;width:420px;right:40px;bottom:100px;filter:drop-shadow(0 14px 34px #000c)}
.bx{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);width:740px}
.hdr2{display:flex;align-items:center;gap:14px;margin-bottom:12px}
.hdr2 .ic{width:44px;height:44px;border-radius:50%;border:1.5px solid var(--brass);display:grid;place-items:center;color:var(--hi)}
.hdr2 h2{flex:1;font:900 20px Cinzel;letter-spacing:.1em;color:var(--ivory)} .hdr2 small{display:block;font:italic 400 13px Alegreya;color:var(--dim);letter-spacing:0;margin-top:2px}
"""
def page2(title,inner):
    return ('<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s%s%s%s</style></head><body><div class="veil" style="background:rgba(4,6,10,.55)"></div>%s</body></html>')%(title,CSS2,EXTRA2,EXTRA3,EXTRA4,inner)
def lkbar(p):
    return '<div class="lk"><div><i class="no" style="width:%d%%"></i><i class="yes" style="width:%d%%"></i></div><span style="left:0;width:%d%%;color:#f3b5a0">%d%%</span><span style="right:0;width:%d%%;color:#1b1408">%d%%</span></div>'%(100-p,p,100-p,100-p,p,p)
def plate(inner,w,c=10): return '<div class="plate" style="--c:%dpx"><div class="pin" style="--c:%dpx;padding:18px 20px">%s</div></div>'%(c,c,inner)
FLAGES='<div class="f" style="background:radial-gradient(circle,#fff 0 28%,#c8202f 29% 60%,#f1bf00 61%)"></div>'
FLAGPR='<div class="f" style="background:linear-gradient(90deg,#222 33%,#fff 33% 66%,#c00 66%)"></div>'
FLAGPO='<div class="f" style="background:linear-gradient(#fff 50%,#c8202f 50%)"></div>'
# ---- C1: a Call to war action on the ally's card, answered with a likelihood bar
c1_card=('<div class="card2"><div class="t"><h3>Call Spain to the war</h3><b>68%</b></div>'
  '<p class="p" style="margin:8px 0 0">Britain is at war with you. Spain is bound to you by alliance; whether it joins depends on trust, the danger Britain is to it, a shared border, the distance and how tired it is of war.</p>'+lkbar(68)+
  '<div class="fx">Trust in you<i></i><b class="g">+0.40</b></div><div class="fx">Danger from Britain<i></i><b class="g">+0.17</b></div><div class="fx">Shared border with Britain<i></i><b class="n">0</b></div><div class="fx">Distance to the war<i></i><b>&minus;0.16</b></div><div class="fx">Its war weariness<i></i><b>&minus;0.09</b></div>'
  '<div class="row3"><span class="mut" style="font-size:13px">A call costs 1 envoy. A refusal costs you nothing but a little trust.</span><span class="bt pri" style="min-width:140px">@@ Call to war</span></div></div>').replace('@@',SW)
c1=('<div class="bx">'+plate('<div class="hdr2"><div class="ic">@@</div><h2>Nations<small>Spain &middot; allied +70</small></h2></div>'.replace('@@',SW)+
  '<div class="sec" style="margin-top:0">Diplomacy</div><div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:12px"><span class="bt" style="opacity:.45">Trade 56%</span><span class="bt">Embassy 2</span><span class="bt">Break pact</span><span class="bt pri" style="--lo:#B38F3E">@@ Call to war 1</span></div>'.replace('@@',SW)+c1_card,740)+'</div>')
# ---- C2: after the declaration, a short sheet: which allies to call
def ally(f,n,sub,p,on): return '<div class="ally">%s<div class="n">%s<small>%s</small></div><span class="mini" style="color:%s">%d%%</span><span class="chk %s">%s</span></div>'%(f,n,sub,'#69B3A2' if p>=60 else ('#E5C77A' if p>=45 else '#ee8a68'),p,'on' if on else '','&#10003;' if on else '')
c2=('<div class="dlg2" style="width:560px">'+plate('<div class="hdr2"><div class="ic">@@</div><h2>War with Britain<small>Call your allies? Each call costs 1 envoy; they answer at once</small></h2></div>'.replace('@@',SW)+
  ally(FLAGES,'SPAIN','trust high · shares no border · far',68,True)+ally(FLAGPR,'PRUSSIA','trust high · no shared border · near',57,True)+ally(FLAGPO,'PORTUGAL','tired of war · far',31,False)+
  '<div class="row3" style="margin-top:14px"><span class="mut">2 chosen · 2 envoys of 6</span><div style="display:flex;gap:10px"><span class="bt">Not now</span><span class="bt pri">@@ Call 2 allies</span></div></div>'.replace('@@',SW),560,12)+'</div>')
# ---- C3: the call that reaches a human ally: short, AoC2-like, a corner prompt that does not cover the map
c3=('<div class="card3">'+plate('<div style="display:flex;gap:12px;align-items:center"><div class="ic" style="width:44px;height:44px;border-radius:50%;border:1.5px solid var(--brass);display:grid;place-items:center;color:var(--hi);flex:none">@@</div><div style="flex:1"><div class="lbl">Call to arms</div><div class="ttl" style="font-size:15px">SPAIN asks for your help</div></div></div>'.replace('@@',SW)+
  '<p class="p" style="margin:10px 0 4px">Spain is at war with Britain. Join and you are at war with Britain from this turn.</p>'+lkbar(52)+
  '<div class="fx" style="height:22px">Declining<i></i><b>Spain&rsquo;s grudge +20</b></div>'
  '<div class="row3" style="margin-top:10px"><span class="bt" style="flex:1">Decline</span><span class="bt pri" style="flex:1">@@ Join the war</span></div>'.replace('@@',SW),420,10)+'</div>')
for n,h in [('C1_actiononcard',c1),('C2_afterdeclaring',c2),('C3_incomingcall',c3)]:
    open(OUT+'call_%s_desk.html'%n,'w').write(page2(n,h))
print('ok')
