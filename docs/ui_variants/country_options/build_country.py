#!/usr/bin/env python3
"""Mocks for the country-level map (zoomed out to country grade): what a country shows and what a tap offers. Real map (backdrop.png from tests/country_backdrop.gd), real figures (countries.json).
Writes country_K1_ring.html / K2_plate.html / K3_star.html (+ own-country variant of each) next to this file; render.cjs makes the PNGs."""
import json, os, math
HERE = os.path.dirname(os.path.abspath(__file__))
D = json.load(open(os.path.join(HERE, 'countries.json')))
C = {c['code']: c for c in D['countries']}
SC = 0.8                                                 # stage units -> picture pixels
FL = '../../../godot/assets/flags/timurid/%s.png'
def stars(c):
    pr = lambda r: 1.0 - (r - 1) / max(1, c['of'] - 1)
    s = (pr(c['rank_p']) + pr(c['rank_a']) + pr(c['rank_t'])) / 3.0
    return max(1, min(5, int(math.ceil(s * 5))))
def starrow(n, size=15):
    out = ''
    for i in range(5):
        on = i < n
        out += '<svg width="%d" height="%d" viewBox="0 0 24 24"><path d="M12 2.5l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.7 5.9 21.1l1.4-6.8L2.2 9.6l6.9-.8z" fill="%s" stroke="%s" stroke-width="1.2"/></svg>' % (size, size, '#E5C77A' if on else 'none', '#E5C77A' if on else '#6f5f3d')
    return '<span class="sr">%s</span>' % out
ICON = {
 'nation': '<path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z"/><path d="M8 9h8M8 13h8"/>',
 'diplo': '<path d="M3 12l5-5 4 3 4-3 5 5-6 6-3-2-3 2z"/>',
 'war': '<path d="M5 19l9-9M14 5l5 5M19 19l-9-9M10 5L5 10"/>',
 'peace': '<path d="M12 21c-4-3-7-6-7-10a4 4 0 0 1 7-2 4 4 0 0 1 7 2c0 4-3 7-7 10z"/>',
 'capital': '<path d="M6 21V4h10l-2 4 2 4H6"/>',
 'realm': '<path d="M3 18l2-10 5 5 2-8 2 8 5-5 2 10z"/>',
 'budget': '<ellipse cx="12" cy="6" rx="7" ry="3"/><path d="M5 6v6c0 1.7 3.1 3 7 3s7-1.3 7-3V6M5 12v6c0 1.7 3.1 3 7 3s7-1.3 7-3v-6"/>',
 'decree': '<path d="M12 3v18M6 21h12M5 8l7-3 7 3M5 8l-2 6a3 3 0 0 0 4 0zM19 8l2 6a3 3 0 0 1-4 0z"/>',
 'council': '<path d="M3 20h18M5 20V10M9 20V10M15 20V10M19 20V10M3 10l9-6 9 6z"/>',
 'trade': '<path d="M4 8h13l-3-3M20 16H7l3 3"/>',
}
def ico(k, s=22):
    return '<svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="#E5C77A" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % (s, s, ICON[k])
CSS = """
@font-face{font-family:Disp;font-weight:700;src:url(../../../godot/assets/fonts/display-latin-700-normal.woff2)}
@font-face{font-family:Body;font-weight:400;src:url(../../../godot/assets/fonts/body-latin-400-normal.woff2)}
@font-face{font-family:Body;font-weight:700;src:url(../../../godot/assets/fonts/body-latin-700-normal.woff2)}
@font-face{font-family:Body;font-style:italic;font-weight:400;src:url(../../../godot/assets/fonts/body-latin-400-italic.woff2)}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1280px;height:800px;overflow:hidden;background:#0A0D12;font-family:Body,Georgia,serif;color:#EFE6CF}
.bg{position:absolute;inset:0;background:url(backdrop.png) 0 0/1280px 800px}
.dim{position:absolute;inset:0;background:rgba(4,6,10,.18)}
.abs{position:absolute}
.cap{font:700 11px Disp;letter-spacing:.14em;text-transform:uppercase;color:#E5C77A}
.nm{font:700 17px Disp;letter-spacing:.07em;text-transform:uppercase;color:#EFE6CF;white-space:nowrap}
.sm{font:400 14px Body;color:#A89C80;white-space:nowrap}
.sr{display:inline-flex;gap:3px;align-items:center}
.medal{border-radius:50%;background-size:cover;background-position:center;box-shadow:0 0 0 2px #C9A24B,0 0 0 4px #0F0C09,0 0 0 5px rgba(201,162,75,.5)}
.vm{position:absolute;display:flex;flex-direction:column;align-items:center;gap:5px;width:90px;margin-left:-45px}
.vm .d{width:46px;height:46px;border-radius:50%;background:#1B1610;box-shadow:inset 0 0 0 2px #B38F3E,0 0 0 3px #0f0c09;display:grid;place-items:center}
.vm .l{font:700 10.5px Disp;letter-spacing:.14em;color:#EFE6CF;text-transform:uppercase;text-shadow:0 1px 3px #000,0 0 6px #000;white-space:nowrap}
.vm.off .d{box-shadow:inset 0 0 0 2px #4a3f28,0 0 0 3px #0f0c09} .vm.off svg{stroke:#6f5f3d}
.pill{position:absolute;transform:translate(-50%,0);display:flex;align-items:center;justify-content:center;height:17px;padding:0 8px;border-radius:9px;background:rgba(15,12,9,.84);box-shadow:inset 0 0 0 1px #7F6A33}
.star{position:absolute;transform:translate(-50%,-50%)}
.plate{position:absolute;background:linear-gradient(#1b1610,#14100b);box-shadow:inset 0 0 0 1px #7F6A33,0 14px 40px #000b;padding:14px 16px}
.chip{display:inline-flex;align-items:center;gap:6px;height:30px;padding:0 14px;background:#100d09;box-shadow:inset 0 0 0 1px #3a2f1d;font:400 13.5px Body;color:#EFE6CF}
.btn{display:flex;align-items:center;justify-content:center;gap:8px;height:34px;font:700 11.5px Disp;letter-spacing:.14em;text-transform:uppercase;background:#17120c;box-shadow:inset 0 0 0 1px #7F6A33;color:#E5C77A}
.btn.war{background:#4a1d12;box-shadow:inset 0 0 0 1px #b45a3e;color:#ee8a68}
"""
def pos(c): return c['x'] * SC, c['y'] * SC
def mapmarks(extra_skip=()):
    """at country grade every big country shows its capital star and, under it, its standing in five small stars; armies stay hidden until agents have looked"""
    out = ''
    for code in ['timurid_empire', 'mongol_empire', 'sultanate_of_delhi', 'mamluke_sultanate', 'ottoman_empire', 'holy_roman_empire', 'hungary', 'byzantine_empire', 'poland_lithuania']:
        c = C.get(code)
        if not c or code in extra_skip: continue
        x, y = pos(c)
        out += '<svg class="star" style="left:%.0fpx;top:%.0fpx" width="22" height="22" viewBox="0 0 24 24"><path d="M12 2.5l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.7 5.9 21.1l1.4-6.8L2.2 9.6l6.9-.8z" fill="#EFE6CF" stroke="#0A0D12" stroke-width="1.2"/></svg>' % (x, y)
        out += '<div class="pill" style="left:%.0fpx;top:%.0fpx">%s</div>' % (x, y + 13, starrow(stars(c), 9))
    return out
def ring_svg(cx, cy, r):
    ticks = ''
    for i in range(72):
        a = i * 5 * math.pi / 180
        l = 7 if i % 6 == 0 else 3.5
        ticks += '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#8F7637" stroke-width="1"/>' % (cx + (r - 3) * math.cos(a), cy + (r - 3) * math.sin(a), cx + (r - 3 - l) * math.cos(a), cy + (r - 3 - l) * math.sin(a))
    return ('<svg class="abs" style="left:0;top:0" width="1280" height="800"><circle cx="%.0f" cy="%.0f" r="%d" fill="rgba(10,8,6,.55)"/><circle cx="%.0f" cy="%.0f" r="%d" fill="#0F0C09" stroke="#C9A24B" stroke-width="3"/><circle cx="%.0f" cy="%.0f" r="%d" fill="none" stroke="#7F6A33" stroke-width="1"/>%s<circle cx="%.0f" cy="%.0f" r="%d" fill="#0A0806" stroke="#B38F3E" stroke-width="1.5"/></svg>' % (cx, cy, r + 14, cx, cy, r, cx, cy, r - 13, ticks, cx, cy, r - 30))
def head(title):
    return '<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s</style></head><body><div class="bg"></div><div class="dim"></div>' % (title, CSS)
def verbs(c, own):
    if own: return [('realm', 'Realm', 1), ('budget', 'Budget', 1), ('decree', 'Decrees', 1), ('council', 'Council', 1)]
    war = c['rel'] == 1
    return [('nation', 'Nation', 1), ('diplo', 'Diplomacy', 1), ('trade', 'Trade', 0), ('peace' if war else 'war', 'Peace' if war else 'War', 1), ('capital', 'Capital', 1)]
def ring_scene(code, own=False):
    c = C[code]; x, y = pos(c); r = 52
    s = stars(c)
    h = head('K1')
    h += mapmarks((code,))
    h += ring_svg(x, y, r)
    h += '<div class="abs medal" style="left:%.0fpx;top:%.0fpx;width:36px;height:36px;margin:-27px 0 0 -18px;background-image:url(%s)"></div>' % (x, y, FL % code)
    h += '<div class="abs" style="left:%.0fpx;top:%.0fpx;width:100px;margin-left:-50px;text-align:center">%s</div>' % (x, y + 14, starrow(s, 13))
    # the name plaque under the ring, the figures under it
    h += '<div class="abs" style="left:%.0fpx;top:%.0fpx;transform:translateX(-50%%);text-align:center;white-space:nowrap"><div class="nm" style="text-shadow:0 1px 4px #000,0 0 8px #000">%s</div>' % (x, y + r + 22, c['name'])
    h += '<div style="display:flex;gap:8px;margin-top:8px;justify-content:center">'
    for t in ['%d provinces' % c['prov'], '%s men' % '{:,}'.format(c['army']).replace(',', ' '), '#%d of %d' % (c['rank_p'], c['of'])]:
        h += '<span class="chip">%s</span>' % t
    h += '</div></div>'
    vs = verbs(c, own); n = len(vs)
    for i, (k, lab, ok) in enumerate(vs):
        ang = -math.pi / 2 + (i - (n - 1) / 2) * 0.80
        vx = x + (r + 52) * math.cos(ang); vy = y + (r + 52) * math.sin(ang)
        h += '<div class="vm %s" style="left:%.0fpx;top:%.0fpx"><div class="d">%s</div><div class="l">%s</div></div>' % ('' if ok else 'off', vx, vy - 23, ico(k), lab)
    h += '</body></html>'
    return h
def plate_scene(code, own=False):
    c = C[code]; x, y = pos(c)
    h = head('K2') + mapmarks((code,))
    h += '<svg class="star" style="left:%.0fpx;top:%.0fpx" width="30" height="30" viewBox="0 0 24 24"><path d="M12 2.5l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.7 5.9 21.1l1.4-6.8L2.2 9.6l6.9-.8z" fill="#E5C77A" stroke="#0A0D12" stroke-width="1.2"/></svg>' % (x, y)
    px, py = x + 34, y - 150
    h += '<div class="plate" style="left:%.0fpx;top:%.0fpx;width:400px;padding:22px 24px 24px">' % (px, py)
    h += '<div style="display:flex;gap:18px;align-items:center"><div class="medal" style="flex:none;width:64px;height:64px;background-image:url(%s)"></div><div style="min-width:0"><div class="nm" style="font-size:19px;line-height:1.15">%s</div><div class="sm" style="margin-top:7px;font-style:italic;font-size:15px">%s %s</div></div></div>' % (FL % code, c['name'], c['title'], c['ruler'])
    army = '<span class="chip" style="color:#A89C80;font-style:italic">Army ?</span>' if not own else '<span class="chip">%s men</span>' % '{:,}'.format(c['army']).replace(',', ' ')
    h += '<div style="display:flex;gap:10px;margin-top:20px;flex-wrap:nowrap"><span class="chip">%d provinces</span>%s<span class="chip">%+d gold</span></div>' % (c['prov'], army, c['gold'])
    h += '<div style="display:flex;gap:10px;margin-top:20px">'
    for k, lab, ok in verbs(c, own)[:3]:
        h += '<div class="btn" style="flex:1;height:42px;padding:0 6px">%s%s</div>' % (ico(k, 17), lab)
    h += '</div></div></body></html>'
    return h
def star_scene(code, own=False):
    c = C[code]; x, y = pos(c); s = stars(c)
    h = head('K3') + mapmarks((code,))
    # the star itself becomes a medallion: flag in a ringed star, the figure under it, three verbs hang from it
    h += '<svg class="abs" style="left:0;top:0" width="1280" height="800"><circle cx="%.0f" cy="%.0f" r="30" fill="#0F0C09" stroke="#E5C77A" stroke-width="2.5"/><circle cx="%.0f" cy="%.0f" r="36" fill="none" stroke="rgba(229,199,122,.35)" stroke-width="2"/></svg>' % (x, y, x, y)
    h += '<div class="abs medal" style="left:%.0fpx;top:%.0fpx;width:40px;height:40px;margin:-20px 0 0 -20px;background-image:url(%s)"></div>' % (x, y, FL % code)
    h += '<svg class="star" style="left:%.0fpx;top:%.0fpx" width="24" height="24" viewBox="0 0 24 24"><path d="M12 2.5l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.7 5.9 21.1l1.4-6.8L2.2 9.6l6.9-.8z" fill="#E5C77A" stroke="#0A0D12" stroke-width="1.2"/></svg>' % (x + 26, y - 26)
    h += '<div class="abs" style="left:%.0fpx;top:%.0fpx;transform:translateX(-50%%);text-align:center"><div class="nm" style="text-shadow:0 1px 4px #000,0 0 8px #000">%s</div><div style="margin-top:4px">%s</div></div>' % (x, y + 42, c['name'], starrow(s, 14))
    vs = verbs(c, own)[:4]
    for i, (k, lab, ok) in enumerate(vs):
        vx = x - 135 + i * 90; vy = y + 112
        h += '<div class="vm %s" style="left:%.0fpx;top:%.0fpx"><div class="d">%s</div><div class="l">%s</div></div>' % ('' if ok else 'off', vx + 45 - 45 + 45, vy, ico(k), lab)
    h += '</body></html>'
    return h
files = {
 'country_K1_ring_foreign': ring_scene('mamluke_sultanate'), 'country_K1_ring_own': ring_scene('timurid_empire', True),
 'country_K2_plate_foreign': plate_scene('mamluke_sultanate'), 'country_K2_plate_own': plate_scene('timurid_empire', True),
 'country_K3_star_foreign': star_scene('mamluke_sultanate'), 'country_K3_star_own': star_scene('timurid_empire', True),
}
for k, v in files.items(): open(os.path.join(HERE, k + '.html'), 'w', encoding='utf-8').write(v)
print('ok', len(files))
