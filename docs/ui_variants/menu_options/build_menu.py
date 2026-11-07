#!/usr/bin/env python3
"""Main menu in two stages (mocks): stage 1 = Play / Settings / How to play beside a big slowly turning globe in the lower right corner; Play morphs it into stage 2, the screen the game has now.
The globe is a real render of the title globe (tests/title_globe_big.gd), stage 2 is a real screenshot (tests/title_shots.gd). Writes menu_M1_left.html, menu_M2_row.html, menu_T1_morph.html; render.cjs makes the PNGs."""
import os, math
HERE = os.path.dirname(os.path.abspath(__file__))
DISC = 0.875                                         # the globe's disc as a share of globe_alpha.png
CSS = """
@font-face{font-family:Disp;font-weight:700;src:url(../../../godot/assets/fonts/display-latin-700-normal.woff2)}
@font-face{font-family:Disp;font-weight:900;src:url(../../../godot/assets/fonts/display-latin-900-normal.woff2)}
@font-face{font-family:Body;font-weight:400;src:url(../../../godot/assets/fonts/body-latin-400-normal.woff2)}
@font-face{font-family:Body;font-weight:700;src:url(../../../godot/assets/fonts/body-latin-700-normal.woff2)}
@font-face{font-family:Body;font-style:italic;font-weight:400;src:url(../../../godot/assets/fonts/body-latin-400-italic.woff2)}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1280px;height:720px;overflow:hidden;background:#04070d;font-family:Body,Georgia,serif;color:#EFE6CF;position:relative}
.stars{position:absolute;inset:0;background-image:radial-gradient(1px 1px at 12% 22%,#8a93a8 50%,transparent 51%),radial-gradient(1px 1px at 33% 71%,#6d7588 50%,transparent 51%),radial-gradient(1.4px 1.4px at 47% 14%,#aab2c4 50%,transparent 51%),radial-gradient(1px 1px at 61% 38%,#6d7588 50%,transparent 51%),radial-gradient(1px 1px at 78% 8%,#8a93a8 50%,transparent 51%),radial-gradient(1px 1px at 88% 55%,#6d7588 50%,transparent 51%),radial-gradient(1.4px 1.4px at 7% 83%,#aab2c4 50%,transparent 51%),radial-gradient(1px 1px at 55% 92%,#6d7588 50%,transparent 51%),radial-gradient(1px 1px at 24% 46%,#6d7588 50%,transparent 51%),radial-gradient(1px 1px at 93% 88%,#8a93a8 50%,transparent 51%);background-size:640px 360px}
.globe{position:absolute}
.abs{position:absolute}
.wm{font:900 54px/1.06 Disp;letter-spacing:.1em;color:#E5C77A;text-transform:uppercase}
.rule{display:flex;align-items:center;gap:0;height:12px;width:270px}
.rule i{flex:1;height:1px;background:#7F6A33} .rule b{width:7px;height:7px;transform:rotate(45deg);background:#E5C77A;margin:0 6px}
.tag{font:700 11px/1.7 Disp;letter-spacing:.22em;color:#A89C80;text-transform:uppercase}
.play{position:relative;display:flex;align-items:center;gap:18px;width:272px;height:64px;padding:0 22px;background:linear-gradient(#1d1710,#15100a);clip-path:polygon(10px 0,calc(100% - 10px) 0,100% 10px,100% calc(100% - 10px),calc(100% - 10px) 100%,10px 100%,0 calc(100% - 10px),0 10px);box-shadow:inset 0 0 0 1px #C9A24B}
.play:before{content:"";position:absolute;inset:0;border:1.5px solid #E5C77A;clip-path:inherit}
.play .t{font:700 22px Disp;letter-spacing:.16em;color:#EFE6CF;text-transform:uppercase;flex:1}
.play svg{flex:none}
.item{display:flex;align-items:center;gap:16px;height:40px;font:700 15px Disp;letter-spacing:.18em;color:#C9BFA2;text-transform:uppercase;white-space:nowrap}
.item i{width:6px;height:6px;transform:rotate(45deg);background:#B38F3E;flex:none}
.bar{position:absolute;left:0;right:0;bottom:14px;display:flex;justify-content:center;align-items:center;gap:26px;font:700 12.5px Body;color:#C9BFA2;height:26px}
.bar span{display:flex;align-items:center;gap:7px} .bar u{text-decoration:none;color:#E5C77A} .bar .sep{width:1px;height:14px;background:#3a3f4a}
.ver{position:absolute;right:12px;top:8px;font:400 10px Body;color:#6d7588}
.ring{position:absolute;pointer-events:none}
"""
def head(t): return '<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s</style></head><body><div class="stars"></div>' % (t, CSS)
def globe(cx, cy, r, extra=''):
    S = 2 * r / DISC
    return '<img class="globe" src="globe_alpha.png" style="left:%.0fpx;top:%.0fpx;width:%.0fpx;height:%.0fpx;%s">' % (cx - S / 2, cy - S / 2, S, S, extra)
def title(x, y):
    return ('<div class="abs" style="left:%dpx;top:%dpx"><div class="wm">Terra<br>Bellum</div><div class="rule" style="margin-top:18px"><i></i><b></b><i></i></div><div class="tag" style="margin-top:14px">A turn-based chronicle<br>of the globe</div></div>') % (x, y)
CHEV = '<svg width="14" height="22" viewBox="0 0 14 22" fill="none" stroke="#E5C77A" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3l8 8-8 8"/></svg>'
def bar():
    return ('<div class="bar"><span><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#E5C77A" stroke-width="1.8"><path d="M7 4h10v5a5 5 0 0 1-10 0zM5 5H3v2a3 3 0 0 0 3 3M19 5h2v2a3 3 0 0 1-3 3M12 14v4M8 20h8"/></svg>Honours <u>0/20</u></span><span class="sep"></span><span style="color:#EFE6CF;border-bottom:1.5px solid #E5C77A;padding-bottom:1px">EN</span><span class="sep"></span><span>RU</span><span class="sep"></span><span>UZ</span></div>')
def menu_left(x, y):
    return ('<div class="abs" style="left:%dpx;top:%dpx"><div class="play"><span class="t">Play</span>%s</div>'
            '<div style="margin-top:26px;display:flex;flex-direction:column;gap:8px;padding-left:6px"><div class="item"><i></i>Settings</div><div class="item"><i></i>How to play</div></div></div>') % (x, y, CHEV)
def m1():
    h = head('M1') + globe(1210, 740, 690)
    h += title(54, 64) + menu_left(54, 372) + bar() + '<div class="ver">v1.4.0</div></body></html>'
    return h
def m2():
    h = head('M2') + globe(1230, 770, 700)
    h += ('<div class="abs" style="left:0;right:0;top:70px;text-align:center"><div class="wm" style="font-size:58px;display:inline-block">Terra Bellum</div><div class="rule" style="margin:20px auto 0;width:340px"><i></i><b></b><i></i></div><div class="tag" style="margin-top:14px">A turn-based chronicle of the globe</div></div>')
    h += ('<div class="abs" style="left:54px;bottom:78px;display:flex;align-items:center;gap:30px"><div class="play"><span class="t">Play</span>%s</div><div class="item"><i></i>Settings</div><div class="item"><i></i>How to play</div></div>') % CHEV
    h += bar() + '<div class="ver">v1.4.0</div></body></html>'
    return h
def ring_svg(cx, cy, r, op):
    t = ''
    for i in range(120):
        a = i * 3 * math.pi / 180
        l = 10 if i % 10 == 0 else 5
        t += '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#8F7637" stroke-width="1.2"/>' % (cx + (r - 3) * math.cos(a), cy + (r - 3) * math.sin(a), cx + (r - 3 - l) * math.cos(a), cy + (r - 3 - l) * math.sin(a))
    return '<svg class="ring" style="left:0;top:0;opacity:%.2f" width="1280" height="720"><circle cx="%.0f" cy="%.0f" r="%.0f" fill="none" stroke="#E5C77A" stroke-width="2.4"/><circle cx="%.0f" cy="%.0f" r="%.0f" fill="none" stroke="#7F6A33" stroke-width="1"/>%s</svg>' % (op, cx, cy, r, cx, cy, r + 14, t)
def frame(globe_xy_r, menu_op, menu_dx, ring_op, label):
    cx, cy, r = globe_xy_r
    h = '<div class="frame" style="position:relative;width:1280px;height:720px;overflow:hidden;background:#04070d">'
    h += '<div class="stars"></div>' + globe(cx, cy, r) + ring_svg(cx, cy, r * 1.38, ring_op)
    h += '<div style="opacity:%.2f;transform:translateX(%dpx)">%s%s</div>' % (menu_op, menu_dx, title(54, 64), menu_left(54, 372))
    h += '<div class="abs" style="left:14px;top:10px;font:700 13px Disp;letter-spacing:.14em;color:#E5C77A;background:rgba(4,7,13,.7);padding:4px 10px">%s</div></div>' % label
    return h
def t1():
    # three frames of the morph, stacked small in one sheet: 0 %, 50 %, the real stage 2
    f1 = frame((1085, 700, 700), 1.0, 0, 0.0, '1  Press Play')
    f2 = frame((700, 385, 245), 0.35, -70, 0.6, '2  The globe moves to the centre and shrinks, the ring draws in, the menu slides away')
    f3 = '<div style="position:relative;width:1280px;height:720px"><img src="stage2_current.png" style="width:1280px;height:720px"><div class="abs" style="left:14px;top:10px;font:700 13px Disp;letter-spacing:.14em;color:#E5C77A;background:rgba(4,7,13,.7);padding:4px 10px">3  Stage 2: the screen the game has now (Continue / New game / Load / Multiplayer)</div></div>'
    return ('<!doctype html><html><head><meta charset="utf-8"><title>T1</title><style>%s html,body{width:1280px;height:2200px;overflow:hidden}.frame{margin-bottom:20px}</style></head><body>%s<div style="height:20px"></div>%s<div style="height:20px"></div>%s</body></html>') % (CSS.replace('html,body{width:1280px;height:720px;overflow:hidden;background:#04070d;', 'html,body{background:#04070d;'), f1, f2, f3)
for k, v in {'menu_M1_left': m1(), 'menu_M2_row': m2(), 'menu_T1_morph': t1()}.items():
    open(os.path.join(HERE, k + '.html'), 'w', encoding='utf-8').write(v)
print('ok')
