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
.dock{position:absolute;background:linear-gradient(#1c1710f2,#14100bf2);border:1px solid var(--lo);box-shadow:0 14px 44px #000c;clip-path:polygon(12px 0,calc(100% - 12px) 0,100% 12px,100% 100%,0 100%,0 12px)}
.lbl{font-family:Cinzel;font-size:10px;letter-spacing:.16em;color:var(--hi);text-transform:uppercase}
.ttl{font-family:Cinzel;font-weight:900;font-size:15px;letter-spacing:.1em;color:var(--ivory)}
.arrow{width:36px;height:36px;display:grid;place-items:center;border:1px solid var(--lo);background:#1c160e;color:var(--hi);font-size:15px;border-radius:50%}
.ok{width:44px;height:44px;border-radius:50%;display:grid;place-items:center;font-size:22px;background:linear-gradient(#e0c06e,#b38f3e);color:#1b1408;border:1px solid #e0c06e;font-weight:900}
.no{width:44px;height:44px;border-radius:50%;display:grid;place-items:center;font-size:20px;border:1px solid var(--lo);color:var(--hi);background:#1c160e}
.bar{position:relative;height:36px;border:1px solid var(--lo);background:#0e0b07}
.bar u{position:absolute;left:0;top:0;bottom:0;background:linear-gradient(#e0c06e,#b38f3e)}
.bar i{position:absolute;top:-5px;bottom:-5px;width:6px;background:#EFE6CF;border:1px solid #1b1408}
.bar .v{position:absolute;inset:0;display:grid;place-items:center;font-family:Cinzel;font-weight:900;font-size:17px;color:#EFE6CF;text-shadow:0 1px 2px #000}
.ticks{display:flex;justify-content:space-between;font-family:Cinzel;font-size:9px;letter-spacing:.08em;color:var(--dim2);margin-top:3px}
.mini{display:flex;gap:4px}
.mini b{height:28px;padding:0 10px;border:1px solid var(--lo);background:#1c160e;display:grid;place-items:center;font-family:Cinzel;font-size:10.5px;letter-spacing:.06em;color:var(--hi);font-weight:500;border-radius:3px}
.mini b.on{background:#3a2f1b;color:var(--ivory)}
.cost{font-family:Cinzel;letter-spacing:.04em;color:var(--hi);font-size:14px}
.cost small{display:block;font-family:Alegreya;letter-spacing:0;color:var(--dim);font-size:12.5px;margin-top:1px}
"""
def pgd(title, dock_html, kind='desk', w=None, h=None, bottom=None):
    desk = kind=='desk'
    w = w or (820 if desk else 720); left = (1280-w)//2 if desk else (800-w)//2
    bottom = bottom if bottom is not None else (72 if desk else 14)
    pv = (560,280) if desk else (260,90)
    return ('<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s%s</style></head><body class="%s"><div class="shade"></div>'
            '<div class="prov" style="left:%dpx;top:%dpx">AISNE</div>'
            '<div class="dock" style="left:%dpx;width:%dpx;bottom:%dpx">%s</div></body></html>')%(title,CSS2,EXTRA2,'' if desk else 'phone',pv[0],pv[1],left,w,bottom,dock_html)

def slider(p=58, ticks=True):
    t='<div class="ticks"><span>1</span><span>7</span><span>14</span><span>20</span><span>26</span></div>' if ticks else ''
    return '<div style="flex:1"><div class="slim"><u style="width:%d%%"></u><s style="left:calc(%d%% - 9px)"></s></div>%s</div>'%(p,p,t)

# ---- B1: one line, AoC2's bottom bar
def b1(phone=False):
    return ('<div style="display:flex;align-items:center;gap:14px;padding:12px 18px;height:72px">'
            '<div style="width:112px"><div class="lbl">Recruit</div><div class="ttl">AISNE</div></div>'
            '<span class="arrow">&#9664;</span>%s<span class="arrow">&#9654;</span>'
            '<div class="fld" style="width:96px;height:40px;font-size:18px">15<span class="mut" style="font-family:Alegreya;font-size:14px;margin-left:6px">/ 26</span></div>'
            '<div class="cost" style="width:104px">21 g &middot; 15 men<small>Army 120 &rarr; 135</small></div>'
            '<span class="ok">&#10003;</span><span class="no">&#10005;</span></div>')%slider(58,False)

# ---- B2: two lines: title and cost above, slider with ticks and presets below
def b2(phone=False):
    return ('<div style="padding:12px 18px 12px">'
            '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px"><div><span class="lbl">Recruit</span> <span class="ttl" style="margin-left:10px">AISNE</span></div>'
            '<div class="cost" style="text-align:right">21 g &middot; 15 men &nbsp;<span class="mut" style="font-family:Alegreya;letter-spacing:0;font-size:13px">army 120 &rarr; 135 &middot; pool 11 left</span></div></div>'
            '<div style="display:flex;align-items:center;gap:12px"><span class="arrow">&#9664;</span>%s<span class="arrow">&#9654;</span>'
            '<div class="fld" style="width:70px">15</div>'
            '<div class="mini"><b>25</b><b>50</b><b class="on">75</b><b>All</b></div>'
            '<span class="ok">&#10003;</span><span class="no">&#10005;</span></div></div>')%slider(58,True)

# ---- B3: a thick bar-slider with the number in it, the way AoC2 draws its army slider
def b3(phone=False):
    return ('<div style="padding:12px 18px">'
            '<div style="display:flex;align-items:center;gap:14px"><div style="width:96px"><div class="lbl">Recruit</div><div class="ttl">AISNE</div></div>'
            '<span class="arrow">&#9664;</span>'
            '<div style="flex:1"><div class="bar"><u style="width:58%"></u><i style="left:calc(58% - 3px)"></i><span class="v">15 <span style="font-family:Alegreya;font-weight:400;font-size:14px;margin-left:6px;color:#d9cfb6"> of 26 ready</span></span></div>'
            '<div class="ticks"><span>1</span><span>25 %</span><span>50 %</span><span>75 %</span><span>26</span></div></div>'
            '<span class="arrow">&#9654;</span><div class="cost" style="width:100px">21 g &middot; 15 men<small>Army 120 &rarr; 135</small></div><span class="ok">&#10003;</span><span class="no">&#10005;</span></div></div>')

for name,fn in [('B1_oneline',b1),('B2_twolines',b2),('B3_bar',b3)]:
    for kind in ('desk','phone'):
        open('rec_%s_%s.html'%(name,kind),'w').write(pgd(name, fn(kind=='phone'), kind=kind))
print('ok')
