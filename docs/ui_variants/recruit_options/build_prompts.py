#!/usr/bin/env python3
"""The call to arms a human ally receives: three presentations. Run from recruit_options; writes ../war_options/prompt_*.html"""
src=open('build_calls.py').read()
exec(src[:src.index("# ---- C1")])
OUT='../war_options/'
EXTRA5="""
.tick{position:absolute;right:24px;top:92px;width:440px;display:flex;flex-direction:column;gap:8px}
.tk{display:flex;align-items:center;gap:12px;min-height:64px;padding:8px 12px 8px 12px;border-radius:32px;background:rgba(18,16,13,.96);box-shadow:inset 0 0 0 1px var(--lo),0 8px 20px rgba(0,0,0,.55)}
.tk .m{width:44px;height:44px;border-radius:50%;box-shadow:0 0 0 1.5px #B4543A;display:grid;place-items:center;color:#ee8a68;background:#0f0c09;flex:none}
.tk .tx{flex:1;font:500 15px/1.2 Alegreya;color:var(--ivory)} .tk .tx small{display:block;color:var(--dim);font-size:12.5px;margin-top:2px}
.tk .ab{display:flex;gap:6px}
.ib{width:36px;height:36px;border-radius:50%;display:grid;place-items:center;box-shadow:0 0 0 1.5px var(--lo);background:#0f0c09;color:var(--hi);font:700 17px Alegreya}
.ib.y{background:linear-gradient(180deg,#EBCF85,#B38F3E);color:#1b1408;box-shadow:0 0 0 1.5px #EBCF85}
.band{height:104px;margin:-18px -20px 14px;position:relative;background:radial-gradient(circle at 50% 52%,#3a1a12 0,#1d0f0b 60%,#150b08 100%);display:grid;place-items:center;overflow:hidden}
.band .rr{position:absolute;left:50%;top:52%;border:1px solid rgba(238,138,104,.22);border-radius:50%;transform:translate(-50%,-50%)}
.chips2{display:flex;gap:8px;flex-wrap:wrap;margin:6px 0 10px}
"""
def page3(title,inner):
    return ('<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s%s%s%s%s</style></head><body><div class="veil" style="background:rgba(4,6,10,.45)"></div>%s</body></html>')%(title,CSS2,EXTRA2,EXTRA3,EXTRA4,EXTRA5,inner)
FLAGES='<div class="flag" style="background:radial-gradient(circle,#fff 0 28%,#c8202f 29% 60%,#f1bf00 61%);margin:0 auto 6px"></div>'
def lkbar2(p):
    return '<div class="lk"><div><i class="no" style="width:%d%%"></i><i class="yes" style="width:%d%%"></i></div><span style="left:0;width:%d%%;color:#f3b5a0">%d%%</span><span style="right:0;width:%d%%;color:#1b1408">%d%%</span></div>'%(100-p,p,100-p,100-p,p,p)
# ---- D1: an inline offer in the alert ticker (the pattern peace offers already use)
d1=('<div class="tick">'
    '<div class="tk"><div class="m">@@</div><div class="tx">Spain asks you to join the war on Britain<small>Willingness 52 % · declining costs Spain&rsquo;s trust</small></div><div class="ab"><span class="ib">&#10005;</span><span class="ib y">&#10003;</span></div></div>'
    '<div class="tk" style="opacity:.8"><div class="m" style="box-shadow:0 0 0 1.5px #7F6A33;color:#E5C77A">&#9873;</div><div class="tx">Prussia offers a pact<small>Non-aggression, 20 turns</small></div><div class="ab"><span class="ib">&#10005;</span><span class="ib y">&#10003;</span></div></div>'
    '</div>').replace('@@',SW)
# ---- D2: an announcement dialog in the war dialog's language: flags face to face, the reasons, Join / Decline
d2=('<div class="dlg" style="width:520px">'+plate('<div class="med">@@</div><div class="h1" style="font-size:23px">Spain calls you to arms</div><div class="rule"></div>'
    '<p class="p">Britain has declared war on Spain, your ally. Join, and you are at war with Britain from this turn.</p>'
    +faceoff('SPAIN','King Charles IV','BRITAIN','King George III')+
    '<div class="chips2"><span class="badge g">Trust in Spain +</span><span class="badge g">Britain is a danger to you</span><span class="badge b">Far from your borders</span><span class="badge n">Willingness 52 %</span></div>'
    +lkbar2(52)+
    '<div class="fx">If you decline<i></i><b>Spain&rsquo;s grudge +20</b></div>'
    '<div class="bar" style="margin-top:14px"><span class="bt pri" style="min-width:180px">@@ Join the war</span><span class="bt" style="min-width:150px">Decline</span></div>',520,12)+'</div>').replace('@@',SW)
# ---- D3: the event pop-up of an ultimatum: illustration band, a short question, two buttons, the numbers as a strip
d3=('<div class="dlg" style="width:480px">'+plate('<div class="band"><div class="rr" style="width:132px;height:132px"></div><div class="rr" style="width:168px;height:168px"></div><div class="med" style="width:72px;height:72px;border-color:#ee8a68;color:#ee8a68;position:relative">@@</div></div>'
    '<div class="lbl" style="text-align:center;color:#ee8a68">Call to arms</div><div class="h1" style="font-size:21px;margin-top:6px">Will you stand with Spain?</div>'
    '<p class="p" style="text-align:center">Britain has attacked your ally. Stand with it, and you are at war with Britain from this turn.</p>'
    '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:8px 0 12px">'
    '<div class="stat" style="border:1px solid #3a2f1b;background:#17120c;padding:8px 12px;text-align:center"><div class="k" style="font:500 10px Cinzel;letter-spacing:.14em;color:var(--dim2)">THEIR ARMY</div><div style="font:700 17px Alegreya">5 734</div></div>'
    '<div class="stat" style="border:1px solid #3a2f1b;background:#17120c;padding:8px 12px;text-align:center"><div class="k" style="font:500 10px Cinzel;letter-spacing:.14em;color:var(--dim2)">YOURS</div><div style="font:700 17px Alegreya">2 310</div></div>'
    '<div class="stat" style="border:1px solid #3a2f1b;background:#17120c;padding:8px 12px;text-align:center"><div class="k" style="font:500 10px Cinzel;letter-spacing:.14em;color:var(--dim2)">IF YOU REFUSE</div><div style="font:700 17px Alegreya;color:#ee8a68">−trust</div></div></div>'
    '<div class="bar"><span class="bt pri" style="min-width:170px">@@ Stand with Spain</span><span class="bt" style="min-width:140px">Stay out</span></div>',480,12)+'</div>').replace('@@',SW)
for n,h in [('D1_ticker',d1),('D2_flags',d2),('D3_band',d3)]:
    open(OUT+'prompt_%s_desk.html'%n,'w').write(page3(n,h))
print('ok')
