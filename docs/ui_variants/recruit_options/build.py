#!/usr/bin/env python3
"""Recruit window ("How many?"): four layouts, each at desktop size and phone size, on the map beside the province. Writes rec_*.html; render.cjs turns them into PNGs (desktop and phone), compose.py joins the two."""
exec(open('_base.py').read())
CSS2 = CSS + """
html,body{width:100%;height:100%}
body{background:#0a0d12 url(../mock_assets/game_bg.jpg) center/cover}
.shade{position:absolute;inset:0;background:radial-gradient(900px 500px at 55% 45%,#0000 0,#000a 100%)}
.prov{position:absolute;width:74px;height:74px;border:2px solid var(--hi);border-radius:50%;box-shadow:0 0 0 6px #e5c77a22,0 0 30px #e5c77a55;display:grid;place-items:center;font-family:Cinzel;font-size:11px;letter-spacing:.1em;color:var(--ivory);background:#0006}
.card{position:absolute;background:linear-gradient(#1c1710,#14100b);border:1px solid var(--lo);box-shadow:0 18px 50px #000b;padding:16px 18px 16px;clip-path:polygon(12px 0,100% 0,100% calc(100% - 12px),calc(100% - 12px) 100%,0 100%,0 12px)}
.card .cap{font-size:10px}
.card h2{font-family:Cinzel;font-weight:900;font-size:19px;letter-spacing:.12em;color:var(--ivory);margin:3px 0 12px}
.num{font-family:Cinzel;font-weight:900;color:var(--ivory)}
.mut{color:var(--dim);font-size:14px}
.gold{color:var(--hi)}
.btns{display:flex;gap:8px;margin-top:14px}
.btns .btn{flex:none;text-align:center;padding:10px 16px;font-size:11px}
.btns .btn.pri{flex:1}
.stpb{width:34px;height:34px;border:1px solid var(--lo);border-radius:50%;display:grid;place-items:center;color:var(--hi);font-size:18px;background:#1c160e}
.chip{height:34px;padding:0 12px;border:1px solid var(--lo);background:#1c160e;display:grid;place-items:center;font-family:Cinzel;font-size:11px;letter-spacing:.08em;color:var(--hi);border-radius:3px;flex:1}
.chip.on{background:linear-gradient(#e0c06e,#b38f3e);color:#1b1408;font-weight:900;border-color:#e0c06e}
.fld{height:34px;min-width:64px;border:1px solid var(--lo);background:#0e0b07;display:flex;align-items:center;justify-content:flex-end;padding:0 10px;font-family:Cinzel;font-size:15px;color:var(--ivory)}
.hair{height:1px;background:#2a2216;margin:12px 0}
.kv{display:flex;justify-content:space-between;align-items:center;height:32px;border-bottom:1px solid #2a2216;font-size:15px}
.kv span:first-child{color:var(--dim)} .kv b{font-family:Cinzel;font-weight:500;color:var(--ivory);letter-spacing:.04em}
.seg4{display:flex;border:1px solid var(--lo);border-radius:10px;padding:3px;gap:0;background:#17120c}
.seg4 b{flex:1;height:28px;display:grid;place-items:center;font-family:Cinzel;font-size:11px;letter-spacing:.06em;color:var(--dim);border-radius:7px;font-weight:500}
.seg4 b.on{background:#3a2f1b;color:var(--ivory)}
.slim{position:relative;height:28px}
.slim:before{content:"";position:absolute;left:0;right:0;top:12px;height:4px;background:#2d2415;border-radius:2px}
.slim u{position:absolute;left:0;top:12px;height:4px;background:linear-gradient(#e0c06e,#b38f3e);border-radius:2px}
.slim s{position:absolute;top:5px;width:18px;height:18px;border-radius:50%;background:#1b1408;border:2px solid var(--brass)}
.phone .card{padding:12px 14px}
.phone .card h2{font-size:16px;margin-bottom:8px}
"""
def pg_old(title, card_html, w_desk=392, w_phone=330, kind='desk', ptop=170):
    cw = w_desk if kind=='desk' else w_phone
    cls = '' if kind=='desk' else 'phone'
    left = 640 if kind=='desk' else 360
    top = ptop if kind=='desk' else 18
    pv = (520, 250) if kind=='desk' else (250, 110)
    return ('<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s</style></head><body class="%s"><div class="shade"></div>'
            '<div class="prov" style="left:%dpx;top:%dpx">AISNE</div>'
            '<div class="card" style="left:%dpx;top:%dpx;width:%dpx">%s</div></body></html>')%(title, CSS2, cls, pv[0], pv[1], left, top, cw, card_html)


EXTRA2 = """
/* ---- the game's own parts, copied from the kit demo ---- */
.plate{--c:10px;background:var(--lo);clip-path:polygon(var(--c) 0,calc(100% - var(--c)) 0,100% var(--c),100% calc(100% - var(--c)),calc(100% - var(--c)) 100%,var(--c) 100%,0 calc(100% - var(--c)),0 var(--c))}
.pin{margin:1px;background:linear-gradient(180deg,#1d1812,#13100c);clip-path:polygon(calc(var(--c) - 1px) 0,calc(100% - var(--c) + 1px) 0,100% calc(var(--c) - 1px),100% calc(100% - var(--c) + 1px),calc(100% - var(--c) + 1px) 100%,calc(var(--c) - 1px) 100%,0 calc(100% - var(--c) + 1px),0 calc(var(--c) - 1px));box-shadow:inset 0 0 0 3px #13100c,inset 0 0 0 4px rgba(201,162,75,.22);position:relative}
.bt{--lo:#7F6A33;--fill:#1a150f;--tx:#E5C77A;display:inline-flex;align-items:center;justify-content:center;position:relative;isolation:isolate;height:34px;padding:0 14px;gap:7px;font:700 11.5px/1 Cinzel;letter-spacing:.16em;text-transform:uppercase;color:var(--tx);background:var(--lo);border-radius:0;clip-path:polygon(6px 0,calc(100% - 6px) 0,100% 6px,100% calc(100% - 6px),calc(100% - 6px) 100%,6px 100%,0 calc(100% - 6px),0 6px)}
.bt::before{content:'';position:absolute;inset:1px;z-index:-2;background:var(--fill);clip-path:polygon(5px 0,calc(100% - 5px) 0,100% 5px,100% calc(100% - 5px),calc(100% - 5px) 100%,5px 100%,0 calc(100% - 5px),0 5px)}
.bt.pri{--tx:#1b1408;--lo:#B38F3E;background:var(--lo)}.bt.pri::before{background:linear-gradient(180deg,#EBCF85,#B38F3E)}
.bt svg{width:15px;height:15px;flex:none}
.stp{width:34px;height:34px;flex:none;border-radius:50%;display:grid;place-items:center;background:#0f0c09;box-shadow:0 0 0 1.5px var(--lo);color:var(--hi);font:700 19px/1 Alegreya}
.slr{position:relative;flex:1;margin:0 14px;height:44px}
.slr .trk{position:absolute;left:0;right:0;top:12px;height:10px;background:#0c0a07;box-shadow:inset 0 0 0 1px #4a3f28;border-radius:5px;overflow:hidden}
.slr .trk .fill{position:absolute;left:0;top:0;bottom:0;background:linear-gradient(180deg,#E5C77A,#A8842f);border-radius:5px 0 0 5px}
.slr .tks{position:absolute;left:0;right:0;top:25px;height:8px;background:repeating-linear-gradient(90deg,#7F6A33 0 1px,transparent 1px 5%),repeating-linear-gradient(90deg,#C9A24B 0 1px,transparent 1px 25%);background-size:100% 4px,100% 8px;background-repeat:no-repeat}
.slr .tks::after{content:'';position:absolute;right:0;top:0;width:1px;height:8px;background:#C9A24B}
.slr .thumb{position:absolute;top:5px;width:24px;height:24px;margin-left:-12px;border-radius:50%;background:radial-gradient(circle at 36% 30%,#2a2218,#0f0c09 70%);box-shadow:0 0 0 1.5px #C9A24B,0 0 0 2.5px rgba(5,4,3,.4),0 3px 6px rgba(0,0,0,.6)}
.slr .thumb::after{content:'';position:absolute;left:50%;top:3px;width:2px;height:8px;margin-left:-1px;background:#EFE6CF;border-radius:1px}
.slr .nums{position:absolute;left:0;right:0;top:32px;display:flex;justify-content:space-between;font:500 9.5px Cinzel;letter-spacing:.1em;color:var(--dim2)}
.share{display:flex;border:1px solid var(--lo);border-radius:10px;padding:3px;background:#17120c;height:34px}
.share b{flex:1;min-width:44px;display:grid;place-items:center;font:500 13px Alegreya;color:var(--dim);border-radius:7px}
.share b.on{background:#3a2f1b;color:var(--ivory)}
.num{font:700 15px Alegreya;color:var(--ivory)}
.fld{height:34px;border:1px solid var(--lo);background:#0e0b07;display:flex;align-items:center;justify-content:flex-end;padding:0 10px;font:700 15px Alegreya;color:var(--ivory)}
.lbl{font:500 10px Cinzel;letter-spacing:.16em;color:var(--hi);text-transform:uppercase}
.ttl{font:900 15px Cinzel;letter-spacing:.1em;color:var(--ivory)}
.cost{font:700 14px Alegreya;color:var(--hi)} .cost small{display:block;font:400 12.5px Alegreya;color:var(--dim);margin-top:1px}
.mut{color:var(--dim);font:400 14px Alegreya}
.dock{position:absolute;filter:drop-shadow(0 14px 30px #000c)}
.bigbar{position:relative;height:36px;border-radius:5px;background:#0c0a07;box-shadow:inset 0 0 0 1px #4a3f28;overflow:hidden}
.bigbar u{position:absolute;left:0;top:0;bottom:0;background:linear-gradient(180deg,#E5C77A,#A8842f)}
.bigbar .v{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;white-space:nowrap;font:700 17px Alegreya;color:#F6EFDD;text-shadow:0 1px 3px #000,0 0 6px #000a}
.bigbar u{background:linear-gradient(180deg,#B8963F,#7d5f22)!important}
"""
ICON='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M6 21V4M6 5h12l-3 4 3 4H6"/></svg>'
def pgd(title, inner, kind='desk', w=None, bottom=None):
    desk = kind=='desk'
    w = w or (900 if desk else 760); left = (1280-w)//2 if desk else (800-w)//2
    bottom = bottom if bottom is not None else (72 if desk else 12)
    pv = (560,280) if desk else (260,90)
    return ('<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s%s</style></head><body class="%s"><div class="shade"></div>'
            '<div class="prov" style="left:%dpx;top:%dpx">AISNE</div>'
            '<div class="dock" style="left:%dpx;width:%dpx;bottom:%dpx"><div class="plate" style="--c:12px"><div class="pin" style="--c:12px">%s</div></div></div></body></html>')%(title,CSS2,EXTRA2,'' if desk else 'phone',pv[0],pv[1],left,w,bottom,inner)

def slr(p=58,nums=True):
    n='<div class="nums"><span>1</span><span>7</span><span>14</span><span>20</span><span>26</span></div>' if nums else ''
    return '<div class="slr"><div class="trk"><div class="fill" style="width:%d%%"></div></div><div class="tks"></div><div class="thumb" style="left:%d%%"></div>%s</div>'%(p,p,n)
def stp(c): return '<span class="stp">%s</span>'%c
def share(): return '<div class="share"><b>25</b><b>50</b><b class="on">75</b><b>100%</b></div>'
def go(): return '<span class="bt pri">%s Recruit</span>'%ICON
def no(): return '<span class="bt">Cancel</span>'

def b1(phone=False):
    return ('<div style="display:flex;align-items:center;gap:12px;padding:12px 20px;height:76px">'
            '<div style="width:132px"><div class="lbl">Recruit &middot; <span style="color:var(--ivory)">AISNE</span></div><div class="cost" style="margin-top:4px">21 g &middot; 15 men<small>Army 120 &rarr; 135</small></div></div>'
            '%s%s%s<div class="fld" style="width:98px">15<span class="mut" style="margin-left:6px">/ 26</span></div>%s%s</div>')%(stp('&minus;'),slr(58,False),stp('+'),go(),no())

def b2(phone=False):
    return ('<div style="padding:12px 20px 14px">'
            '<div style="display:flex;align-items:center;justify-content:space-between"><div><span class="lbl">Recruit</span><span class="ttl" style="margin-left:12px">AISNE</span></div>'
            '<div class="cost">21 g &middot; 15 men <span class="mut" style="margin-left:8px">army 120 &rarr; 135 &middot; pool 11 left</span></div></div>'
            '<div style="display:flex;align-items:center;gap:12px;height:52px">%s%s%s<div class="fld" style="width:84px">15</div></div>'
            '<div style="display:flex;align-items:center;justify-content:space-between;gap:12px">%s<div style="display:flex;gap:10px">%s%s</div></div></div>')%(stp('&minus;'),slr(58,True),stp('+'),share(),go(),no())

def b3(phone=False):
    return ('<div style="padding:12px 20px">'
            '<div style="display:flex;align-items:center;gap:12px"><div style="width:96px"><div class="lbl">Recruit</div><div class="ttl">AISNE</div></div>'
            '%s<div style="flex:1;margin:0 4px"><div class="bigbar"><u style="width:58%%"></u><span class="v">15 <span style="font:400 14px Alegreya;margin-left:6px">of 26 ready</span></span></div>'
            '<div class="slr" style="margin:0;height:14px"><div class="tks" style="top:2px"></div><div class="nums" style="top:12px"><span>1</span><span>25 %%</span><span>50 %%</span><span>75 %%</span><span>26</span></div></div></div>%s'
            '<div class="cost" style="width:100px">21 g &middot; 15 men<small>Army 120 &rarr; 135</small></div>%s%s</div></div>')%(stp('&minus;'),stp('+'),go(),no())


XCSS = """
.share.sm b{min-width:34px;font-size:12.5px}
.bt.ico{padding:0;width:34px}
.slr .nums span{cursor:default}
.slr .nums.pct{font:500 10px Cinzel}
"""
def pgx(title, inner, kind):
    html=pgd(title, inner, kind=kind, w=(1100 if kind=='desk' else 780), bottom=(72 if kind=='desk' else 12))
    return html.replace('</style>', XCSS+'</style>',1)
X=ICON.replace('M6 21V4M6 5h12l-3 4 3 4H6','M6 6l12 12M18 6L6 18')
def cross(): return '<span class="bt ico">%s</span>'%X
def share_sm(): return '<div class="share sm"><b>25</b><b>50</b><b class="on">75</b><b>100</b></div>'

# ---- O1: B2 in one row, every control kept (phone: shorter slider, Cancel becomes a cross plate)
def o1(phone):
    left='<div style="width:%dpx;line-height:1.15"><div class="lbl">Recruit &middot; <span style="color:var(--ivory)">AISNE</span></div><div class="cost" style="margin-top:3px">21 g &middot; 15 men<small>army 120 &rarr; 135%s</small></div></div>'%(150 if not phone else 132, '' if phone else ' &middot; pool 11 left')
    return ('<div style="display:flex;align-items:center;gap:10px;padding:12px 18px;height:78px">%s%s%s%s<div class="fld" style="width:%dpx">15</div>%s%s%s</div>')%(left,stp('&minus;'),slr(58,False),stp('+'),64 if phone else 76,share_sm() if phone else share(),go(),cross() if phone else no())

# ---- O2: the presets are the slider's own labelled ticks (tap a mark to jump there): one control fewer
def o2(phone):
    left='<div style="width:%dpx;line-height:1.15"><div class="lbl">Recruit &middot; <span style="color:var(--ivory)">AISNE</span></div><div class="cost" style="margin-top:3px">21 g &middot; 15 men<small>army 120 &rarr; 135%s</small></div></div>'%(150 if not phone else 132, '' if phone else ' &middot; pool 11 left')
    sl='<div class="slr"><div class="trk"><div class="fill" style="width:58%"></div></div><div class="tks"></div><div class="thumb" style="left:58%"></div><div class="nums pct"><span>1</span><span>25</span><span>50</span><span style="color:var(--hi)">75</span><span>100 %</span></div></div>'
    return ('<div style="display:flex;align-items:center;gap:10px;padding:12px 18px;height:78px">%s%s%s%s<div class="fld" style="width:%dpx">15</div>%s%s</div>')%(left,stp('&minus;'),sl,stp('+'),70,go(),no())


CHK=ICON.replace('M6 21V4M6 5h12l-3 4 3 4H6','M5 12.5l4.5 4.5L19 7.5')
def okb(): return '<span class="bt pri ico" style="width:38px">%s</span>'%CHK
def nob(): return '<span class="bt ico" style="width:38px">%s</span>'%X
def okl(): return '<span class="bt pri" style="padding:0 12px;gap:6px">%s Recruit</span>'%CHK

def left(phone):
    return '<div style="width:%dpx;line-height:1.15"><div class="lbl" style="color:var(--ivory)">AISNE</div><div class="cost" style="margin-top:2px">21 g &middot; 15 men<small>%s</small></div></div>'%(104 if phone else 150,'army 120 &rarr; 135' if not phone else '&rarr; 135')
def sl2():
    return '<div class="slr" style="margin:0 6px"><div class="trk"><div class="fill" style="width:58%"></div></div><div class="tks"></div><div class="thumb" style="left:58%"></div><div class="nums pct"><span>1</span><span>25</span><span>50</span><span style="color:var(--hi)">75</span><span>100 %</span></div></div>'
def p1(phone):   # both buttons as icon plates
    return ('<div style="display:flex;align-items:center;gap:8px;padding:10px 14px;height:70px">%s%s%s%s<div class="fld" style="width:62px">15</div>%s%s</div>')%(left(phone),stp('&minus;'),sl2(),stp('+'),okb(),nob())
def p2(phone):   # Recruit keeps its word but is smaller; Cancel is a cross plate
    return ('<div style="display:flex;align-items:center;gap:8px;padding:10px 14px;height:70px">%s%s%s%s<div class="fld" style="width:62px">15</div>%s%s</div>')%(left(phone),stp('&minus;'),sl2(),stp('+'),okl(),nob())
def pgy(title, inner, kind):
    return pgx(title, inner, kind)
for name,fn in [('P1_iconbuttons',p1),('P2_smallword',p2)]:
    for kind in ('desk','phone'):
        open('rec_%s_%s.html'%(name,kind),'w').write(pgy(name, fn(kind=='phone'), kind))
for name,fn in [('O1_allcontrols',o1),('O2_tickpresets',o2)]:
    for kind in ('desk','phone'):
        open('rec_%s_%s.html'%(name,kind),'w').write(pgx(name, fn(kind=='phone'), kind))
for name,fn in [('B1_oneline',b1),('B2_twolines',b2),('B3_bar',b3)]:
    for kind in ('desk','phone'):
        open('rec_%s_%s.html'%(name,kind),'w').write(pgd(name, fn(kind=='phone'), kind=kind))
print('ok')
