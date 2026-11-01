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
def pg(title, card_html, w_desk=392, w_phone=330, kind='desk', ptop=170):
    cw = w_desk if kind=='desk' else w_phone
    cls = '' if kind=='desk' else 'phone'
    left = 640 if kind=='desk' else 360
    top = ptop if kind=='desk' else 18
    pv = (520, 250) if kind=='desk' else (250, 110)
    return ('<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s</style></head><body class="%s"><div class="shade"></div>'
            '<div class="prov" style="left:%dpx;top:%dpx">AISNE</div>'
            '<div class="card" style="left:%dpx;top:%dpx;width:%dpx">%s</div></body></html>')%(title, CSS2, cls, pv[0], pv[1], left, top, cw, card_html)

POOL, CAP, TAKE, ARMY = 26, 75, 15, 120
def btns(label='Recruit'):
    return '<div class="btns"><span class="btn pri">&#9906; %s</span><span class="btn">Cancel</span></div>'%label
def head(): return '<div class="cap">Recruit</div><h2>AISNE</h2>'
def pct(p): return int(p*100)

# ---- R1: the pool as a gauge, the number in its middle
def r1(phone=False):
    import math
    R=58; C=2*math.pi*R; span=0.75
    def arc(frac,col,w=10): return '<circle cx="80" cy="80" r="%d" fill="none" stroke="%s" stroke-width="%d" stroke-linecap="butt" stroke-dasharray="%.1f %.1f" transform="rotate(135 80 80)"/>'%(R,col,w,C*span*frac,C)
    gauge='<svg width="160" height="140" viewBox="0 0 160 160" style="display:block">%s%s%s<text x="80" y="88" text-anchor="middle" font-family="Cinzel" font-weight="900" font-size="38" fill="#EFE6CF">%d</text><text x="80" y="110" text-anchor="middle" font-family="Cinzel" font-size="10" letter-spacing="2" fill="#A89C80">OF %d READY</text></svg>'%(arc(1,'#2d2415'),arc(POOL/CAP,'#6b5a30'),arc(TAKE/CAP,'#e0c06e'),TAKE,POOL)
    row='<div style="display:flex;align-items:center;justify-content:center;gap:14px;margin-top:-6px"><span class="stpb">&minus;</span>%s<span class="stpb">+</span></div>'%gauge
    return head()+row+'<div style="height:10px"></div><div class="seg4"><b>25</b><b>50</b><b class="on">75</b><b>100%</b></div><div class="hair"></div><div class="kv" style="border:0;height:24px"><span>Costs</span><b class="gold">21 g &middot; 15 men</b></div><div class="kv" style="border:0;height:24px"><span>Army here</span><b>120 &rarr; 135</b></div>'+btns()

# ---- R2: a ledger, one grid, the number is a cell
def r2(phone=False):
    rows=('<div class="kv"><span>Ready in the pool</span><b>26 / 75</b></div>'
          '<div class="kv" style="height:44px"><span>Recruit</span><span style="display:flex;gap:6px;align-items:center"><span class="stpb" style="border-radius:3px;width:34px">&minus;</span><span class="fld" style="width:70px">15</span><span class="stpb" style="border-radius:3px">+</span></span></div>'
          '<div class="kv"><span>Left in the pool</span><b>11</b></div>'
          '<div class="kv"><span>Army here</span><b>120 &rarr; 135</b></div>'
          '<div class="kv" style="border:0"><span>Cost</span><b class="gold">21 g &middot; 15 men</b></div>')
    return head()+'<div class="seg4" style="margin-bottom:10px"><b>25</b><b>50</b><b class="on">75</b><b>100%</b></div>'+rows+btns()

# ---- R3: one bar shows what happens: army | new men | pool left
def r3(phone=False):
    a=ARMY; t=TAKE; l=POOL-TAKE; tot=a+POOL
    wa=a/tot*100; wt=t/tot*100; wl=l/tot*100
    bar=('<div style="position:relative;height:44px;margin:6px 0 4px"><div style="display:flex;height:30px;margin-top:7px;border:1px solid var(--lo)">'
         '<div style="width:%.1f%%;background:#2d2415"></div><div style="width:%.1f%%;background:linear-gradient(#e0c06e,#b38f3e)"></div><div style="width:%.1f%%;background:repeating-linear-gradient(45deg,#3b3220 0 4px,#241d12 4px 8px)"></div></div>'
         '<div style="position:absolute;left:calc(%.1f%% + %.1f%% - 9px);top:0;width:18px;height:44px;border:2px solid var(--hi);background:#1b1408;border-radius:9px"></div></div>')%(wa,wt,wl,wa,wt)
    leg='<div style="display:flex;justify-content:space-between;font-size:13px;color:var(--dim);margin-bottom:10px"><span>Army <b class="num" style="font-size:12px;color:var(--ivory)">120</b></span><span style="color:var(--hi)">+ new <b class="num" style="font-size:12px">15</b></span><span>Pool left <b class="num" style="font-size:12px;color:var(--ivory)">11</b></span></div>'
    ctl='<div style="display:flex;gap:8px;align-items:center"><div class="seg4" style="flex:1"><b>25</b><b>50</b><b class="on">75</b><b>100%</b></div><span class="fld" style="width:64px">15</span></div>'
    return head()+bar+leg+ctl+'<div class="hair"></div><div class="kv" style="border:0;height:24px"><span>Costs</span><b class="gold">21 g &middot; 15 men</b></div>'+btns()

# ---- R4: big number, step chips (no slider)
def r4(phone=False):
    big='<div style="display:flex;align-items:baseline;justify-content:center;gap:8px;margin:2px 0 10px"><span class="num" style="font-size:54px;line-height:1">15</span><span class="mut">of 26 ready</span></div>'
    steps='<div style="display:flex;gap:6px;margin-bottom:8px"><span class="chip">&minus;10</span><span class="chip">&minus;5</span><span class="chip">&minus;1</span><span class="chip">+1</span><span class="chip">+5</span><span class="chip">+10</span></div>'
    pres='<div style="display:flex;gap:6px"><span class="chip">Min</span><span class="chip">Half</span><span class="chip on">&frac34;</span><span class="chip">All</span></div>'
    return head()+big+steps+pres+'<div class="hair"></div><div class="kv" style="border:0;height:24px"><span>Costs</span><b class="gold">21 g &middot; 15 men</b></div><div class="kv" style="border:0;height:24px"><span>Army here</span><b>120 &rarr; 135</b></div>'+btns()

for name,fn in [('R1_gauge',r1),('R2_ledger',r2),('R3_bar',r3),('R4_steps',r4)]:
    for kind in ('desk','phone'):
        open('rec_%s_%s.html'%(name,kind),'w').write(pg(name, fn(kind=='phone'), kind=kind))
print('ok')
