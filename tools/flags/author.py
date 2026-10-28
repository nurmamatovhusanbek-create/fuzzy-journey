#!/usr/bin/env python3
"""Authored flags for the nations that have no real flag in an era (flags/authored/<nation>.svg, 300x200).

python3 tools/flags/author.py            write every authored flag (all nations in godot/data/eras/*.json, plus the files already in flags/authored)
python3 tools/flags/author.py zulu inca_empire   only these ids

Every nation gets a deterministic design (hash of its id) chosen from a culture recipe (steppe tamga, Andean textile, heraldic, sun-and-spears ...),
so the same nation always looks the same, related spellings share one design (ALIAS), and neighbouring nations differ. The pictures are bold on purpose:
they are shown at 48x32 in the HUD and as a centred square crop on the medals.
"""
import os, sys, re, json, math, hashlib, random

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
W, H = 300, 200

# ---------------------------------------------------------------- colour
RED = '#b5262e'; CRIM = '#8c1c2b'; BLUE = '#1f4f9e'; NAVY = '#14305e'; SKY = '#4d9bd6'; GREEN = '#2e7d45'; FOREST = '#1c5a37'
GOLD = '#e2b33c'; YEL = '#f2c94c'; WHITE = '#f3eee0'; BLACK = '#1b1b20'; PURP = '#5d2a86'; ORNG = '#e07a2e'; TEAL = '#1c8387'
BROWN = '#6e4528'; SAFF = '#ea8b2c'; MAR = '#6f1b27'; TERRA = '#b4562e'; TURQ = '#2fb3a4'; OCHRE = '#c9902f'; SAND = '#d8c08c'
IND = '#2b3a8c'; OLIVE = '#6b7a2e'; ROSE = '#c2506b'; STONE = '#4a4540'; CLAY = '#a86a43'


def hx(c):
    c = c.lstrip('#'); return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def lum(c):
    f = lambda v: v / 12.92 if v <= .03928 else ((v + .055) / 1.055) ** 2.4
    r, g, b = [f(v / 255) for v in hx(c)]
    return .2126 * r + .7152 * g + .0722 * b


def cr(a, b):
    la, lb = lum(a), lum(b)
    return (max(la, lb) + .05) / (min(la, lb) + .05)


def mix(a, b, t):
    A, B = hx(a), hx(b)
    return '#%02x%02x%02x' % tuple(round(A[i] + (B[i] - A[i]) * t) for i in range(3))


def dark(c, t=.35): return mix(c, '#000000', t)
def light(c, t=.35): return mix(c, '#ffffff', t)


# ---------------------------------------------------------------- tiny svg helpers
def n(v): return ('%.2f' % v).rstrip('0').rstrip('.')
def rect(x, y, w, h, f, extra=''): return f'<rect x="{n(x)}" y="{n(y)}" width="{n(w)}" height="{n(h)}" fill="{f}" {extra}/>'
def circ(x, y, r, f, extra=''): return f'<circle cx="{n(x)}" cy="{n(y)}" r="{n(r)}" fill="{f}" {extra}/>'
def poly(pts, f, extra=''): return '<polygon points="%s" fill="%s" %s/>' % (' '.join(f'{n(x)},{n(y)}' for x, y in pts), f, extra)
def path(d, f='none', extra=''): return f'<path d="{d}" fill="{f}" {extra}/>'
def line(d, s, w, extra=''): return f'<path d="{d}" fill="none" stroke="{s}" stroke-width="{n(w)}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'
def grp(body, x=0, y=0, s=1, rot=0, mirror=False):
    t = f'translate({n(x)} {n(y)})' + (f' rotate({n(rot)})' if rot else '') + (f' scale({n(-s)} {n(s)})' if mirror else (f' scale({n(s)})' if s != 1 else ''))
    return f'<g transform="{t}">{body}</g>'


def rot_pts(pts, a):
    c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
    return [(x * c - y * s, x * s + y * c) for x, y in pts]


def star_pts(k, ri=.42, r=1., a0=-90, cx=0, cy=0):
    out = []
    for i in range(2 * k):
        rr = r if i % 2 == 0 else r * ri; a = math.radians(a0 + i * 180 / k)
        out.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return out


# ---------------------------------------------------------------- charges (unit space, radius ~1, centred on 0,0)  f = main colour, a = accent / detail colour
def c_star(f, a, k=5, ri=.42): return poly(star_pts(k, ri), f)
def c_star8(f, a): return poly(star_pts(8, .55), f) + circ(0, 0, .22, a)
def c_star6(f, a): return poly(star_pts(6, .5), f)
def c_crescent(f, a, rot=0):
    return grp(path('M.75 -.661A1 1 0 1 0 .75 .661A.8 .8 0 1 1 .75 -.661Z', f), rot=rot)
def c_crescent_star(f, a):
    return grp(path('M.62 -.66A1 1 0 1 0 .62 .66A.8 .8 0 1 1 .62 -.66Z', f), -.15, 0, .95) + grp(poly(star_pts(5, .42), f), .68, 0, .3)
def c_moon_orb(f, a): return c_crescent(f, a, -90) + circ(0, -.05, .24, a) if False else grp(c_crescent(f, a, -90), 0, .3, .8) + circ(0, -.38, .26, f)
def c_sun(f, a, k=16):
    return poly(star_pts(k, .66, 1), f) + circ(0, 0, .52, a) + circ(0, 0, .36, f)
def c_sun_face(f, a):
    rays = ''.join(grp(poly([(-.1, -.62), (0, -1), (.1, -.62)], f), rot=i * 22.5) for i in range(16))
    return rays + circ(0, 0, .6, f) + circ(-.2, -.1, .09, a) + circ(.2, -.1, .09, a) + line('M-.22 .22Q0 .38 .22 .22', a, .08)
def c_sun_half(f, a):
    rays = ''.join(grp(poly([(-.09, -.72), (0, -1.0), (.09, -.72)], f), rot=-90 + i * 22.5 - 90 + 90) for i in range(0)) + ''
    rr = ''.join(grp(poly([(-.1, -.6), (0, -1), (.1, -.6)], f), 0, .5, 1, i * 27) for i in range(-3, 4))
    return rr + path('M-.55 .5A.55 .55 0 0 1 .55 .5Z', f)
def c_cross_greek(f, a, w=.34): return rect(-1, -w / 2, 2, w, f) + rect(-w / 2, -1, w, 2, f)
def c_cross_latin(f, a): return rect(-.17, -1, .34, 2, f) + rect(-.6, -.5, 1.2, .3, f)
def c_cross_patee(f, a):
    arm = [(-.2, -.2), (-.42, -1), (.42, -1), (.2, -.2)]
    return ''.join(poly(rot_pts(arm, k * 90), f) for k in range(4)) + rect(-.2, -.2, .4, .4, f)
def c_cross_potent(f, a): return c_cross_greek(f, a, .3) + ''.join(rect(-.38 + (0), -1, .76, .2, f, f'transform="rotate({k * 90})"') for k in range(4))
def c_saltire(f, a): return grp(c_cross_greek(f, a, .3), rot=45)
def c_cross_jerusalem(f, a):
    return c_cross_greek(f, a, .3) + ''.join(grp(c_cross_greek(f, a, .1), x * .68, y * .68, .28) for x in (-1, 1) for y in (-1, 1))
def c_fleur(f, a):
    side = 'M.1 .1C.55 -.5 1.0 -.2 .86 .22C.78 .45 .5 .4 .42 .26C.58 .3 .66 .1 .54 0C.4 -.1 .2 .0 .1 .2Z'
    mid = 'M0 -1C.3 -.62 .34 -.18 0 .3C-.34 -.18 -.3 -.62 0 -1Z'
    return path(mid, f) + path(side, f) + grp(path(side, f), mirror=True) + \
        rect(-.5, .34, 1, .16, f) + path('M-.2 .5Q0 .7 0 1Q0 .7 .2 .5Z', f)
def c_crown(f, a):
    body = 'M-.85 .4L-.85 -.35L-.42 .05L0 -.65L.42 .05L.85 -.35L.85 .4Z'
    return path(body, f) + rect(-.85, .4, 1.7, .26, f) + ''.join(circ(x, y, .1, f) for x, y in ((-.85, -.4), (0, -.72), (.85, -.4))) + \
        circ(-.4, .53, .06, a) + circ(0, .53, .06, a) + circ(.4, .53, .06, a)
def c_tower(f, a):
    body = rect(-.55, -.3, 1.1, 1.0, f) + ''.join(rect(x, -.55, .22, .28, f) for x in (-.55, -.18, .2, .33 - .0)[:3]) + rect(.33, -.55, .22, .28, f)
    gate = path('M-.17 .7V.2A.17 .17 0 0 1 .17 .2V.7Z', a)
    sides = rect(-.9, -.05, .38, .75, f) + rect(.52, -.05, .38, .75, f) + rect(-.9, -.28, .13, .24, f) + rect(-.66, -.28, .13, .24, f) + rect(.52, -.28, .13, .24, f) + rect(.77, -.28, .13, .24, f)
    return sides + body + gate
def c_mosque(f, a):
    return path('M-.62 .7V.1A.62 .55 0 0 1 .62 .1V.7Z', f) + rect(-.05, -.85, .1, .3, f) + circ(0, -.9, .09, f) + \
        rect(-.95, -.35, .2, 1.05, f) + rect(.75, -.35, .2, 1.05, f) + poly([(-.95, -.35), (-.85, -.65), (-.75, -.35)], f) + poly([(.75, -.35), (.85, -.65), (.95, -.35)], f) + \
        path('M-.14 .7V.35A.14 .14 0 0 1 .14 .35V.7Z', a)
def c_mud_mosque(f, a):
    body = rect(-.7, -.1, 1.4, .8, f) + ''.join(rect(x - .1, -.7, .2, .62, f) + poly([(x - .1, -.7), (x, -.95), (x + .1, -.7)], f) for x in (-.5, 0, .5))
    spikes = ''.join(rect(x - .015, -.35, .03, .4, a) for x in (-.5, 0, .5))
    return body + path('M-.12 .7V.3A.12 .12 0 0 1 .12 .3V.7Z', a) + spikes
def c_swords(f, a):
    blade = poly([(-.07, -1), (.07, -1), (.09, .55), (-.09, .55)], f) + rect(-.3, .55, .6, .1, f) + rect(-.05, .65, .1, .25, f) + circ(0, .95, .08, f)
    return grp(blade, rot=40) + grp(blade, rot=-40)
def c_spears_shield(f, a):
    sp = lambda r: grp(rect(-.025, -1.05, .05, 2.1, f) + poly([(-.1, -.7), (0, -1.15), (.1, -.7)], f), rot=r)
    shield = path('M0 -.7C.42 -.7 .5 -.2 .45 .2C.4 .62 .18 .72 0 .72C-.18 .72 -.4 .62 -.45 .2C-.5 -.2 -.42 -.7 0 -.7Z', f)
    return sp(24) + sp(-24) + shield + rect(-.03, -.62, .06, 1.25, a) + ''.join(circ(0, y, .05, a) for y in (-.35, -.05, .25, .5))
def c_shield(f, a):
    return path('M-.7 -.8H.7V.1C.7 .55 .3 .8 0 .98C-.3 .8 -.7 .55 -.7 .1Z', f)
def c_axe(f, a):
    return rect(-.04, -.95, .08, 1.9, f) + path('M.04 -.8C.5 -.95 .85 -.6 .85 -.1C.85 .3 .5 .5 .04 .4Z', f) + path('M-.04 -.8C-.5 -.95 -.85 -.6 -.85 -.1C-.85 .3 -.5 .5 -.04 .4Z', f)
def c_anchor(f, a):
    return line('M0 -.7V.85', f, .13) + line('M-.4 -.3H.4', f, .13) + circ(0, -.82, .15, 'none', f'stroke="{f}" stroke-width=".1"') + line('M-.85 .25Q-.8 .85 0 .88Q.8 .85 .85 .25', f, .13) + poly([(-.85, .1), (-.6, .38), (-1.05, .38)], f) + poly([(.85, .1), (.6, .38), (1.05, .38)], f)
def c_ship(f, a):
    hull = path('M-.9 .25H.9L.62 .68H-.62Z', f)
    return hull + rect(-.03, -.85, .06, 1.1, f) + path('M.06 -.8C.55 -.55 .7 -.1 .74 .18H.06Z', a) + path('M-.06 -.6C-.4 -.4 -.55 -.05 -.6 .18H-.06Z', a)
def c_longship(f, a):
    hull = path('M-1 -.1C-.8 .0 -.8 .0 -.5 .4H.5C.8 .0 .8 .0 1 -.1C.9 -.3 .9 -.4 .85 -.5C.7 -.2 .6 .0 0 .05C-.6 0 -.7 -.2 -.85 -.5C-.9 -.4 -.9 -.3 -1 -.1Z', f)
    sail = poly([(-.55, -.12), (.55, -.12), (.4, -.88), (-.4, -.88)], a)
    stripes = ''.join(rect(x, -.9, .16, .8, f, 'opacity=".55"') for x in (-.33, -.01, .31))
    return hull + rect(-.03, -.95, .06, .95, f) + sail + stripes
def c_trident(f, a):
    return line('M0 -.95V.95', f, .12) + line('M-.5 -.7Q-.5 -.05 0 -.05Q.5 -.05 .5 -.7', f, .12) + ''.join(poly([(x - .1, -.7), (x, -1.0), (x + .1, -.7)], f) for x in (-.5, .5)) + poly([(-.1, -.8), (0, -1.1), (.1, -.8)], f)
def c_wheel(f, a, k=12):
    sp = ''.join(line(f'M0 0L{n(.88 * math.cos(math.radians(i * 360 / k)))} {n(.88 * math.sin(math.radians(i * 360 / k)))}', f, .08) for i in range(k))
    return circ(0, 0, .93, 'none', f'stroke="{f}" stroke-width=".12"') + sp + circ(0, 0, .2, f)
def c_lotus(f, a):
    pet = lambda r, s=1: grp(path('M0 .7C.3 .3 .3 -.2 0 -.75C-.3 -.2 -.3 .3 0 .7Z', f), 0, 0, s, r)
    return grp(pet(0), 0, -.05, 1) if False else pet(-62) + pet(62) + pet(-32) + pet(32) + pet(0) + path('M-.95 .7Q0 .98 .95 .7Q0 .85 -.95 .7Z', f)
def c_mon(f, a, k=16):
    pet = ''.join(grp(path('M0 -.35C.18 -.55 .18 -.85 0 -1C-.18 -.85 -.18 -.55 0 -.35Z', f), rot=i * 360 / k) for i in range(k))
    return pet + circ(0, 0, .36, f) + circ(0, 0, .2, a)
def c_tomoe(f, a):
    one = lambda r: grp(path('M0 -.55A.55 .55 0 1 1 -.55 0A.28 .28 0 0 0 -.3 -.3A.2 .2 0 0 1 0 -.55Z', f).replace('A.55 .55 0 1 1 -.55 0', 'A.55 .55 0 0 1 .55 0A.55 .55 0 0 1 0 .55A.55 .55 0 0 1 -.4 .38A.4 .4 0 0 0 .1 -.05'), rot=r)
    return circ(0, 0, 1, f, '') + ''.join(grp(path('M0 -.75C.55 -.75 .6 -.1 .2 .12C.4 -.2 .2 -.5 -.2 -.45C-.1 -.6 -.1 -.7 0 -.75Z', a), rot=i * 120) for i in range(3))
def c_dragon(f, a):
    body = line('M-.9 .35C-.55 -.55 -.1 .75 .25 -.15C.45 -.55 .7 -.5 .8 -.3', f, .2)
    spines = ''.join(poly([(x - .06, y), (x, y - .2), (x + .06, y)], f) for x, y in ((-.62, -.05), (-.28, .15), (.05, .2), (.36, -.4)))
    head = path('M.72 -.5L1.02 -.55L.98 -.32L.72 -.2Z', f) + circ(.84, -.44, .035, a)
    return body + spines + head
def c_serpent(f, a):
    return line('M-.8 .6C-.9 .0 -.2 .3 -.1 -.05C0 -.4 -.65 -.4 -.45 -.7C-.3 -.9 .5 -.85 .6 -.5', f, .22) + circ(.62, -.46, .18, f) + circ(.66, -.5, .035, a)
def c_triskele(f, a):
    arm = lambda r: grp(line('M0 0C.1 -.45 .55 -.55 .6 -.2C.62 .1 .3 .15 .24 -.03', f, .13), rot=r)
    return arm(0) + arm(120) + arm(240) + circ(0, 0, .13, f)
def c_valknut(f, a):
    tri = lambda r: grp(poly([(0, -.95), (.82, .47), (-.82, .47)], 'none', f'stroke="{f}" stroke-width=".11" stroke-linejoin="round"'), 0, 0, .8, r)
    return tri(0) + grp(tri(60), 0, 0, 1)
def c_knot(f, a):
    return ''.join(circ(.34 * math.cos(math.radians(r)), .34 * math.sin(math.radians(r)), .5, 'none', f'stroke="{f}" stroke-width=".12"') for r in (90, 210, 330))
def c_spiral(f, a):
    d = 'M0 0'; pts = []
    for i in range(0, 120):
        t = i / 119 * 3.4 * math.pi; r = .06 + .9 * (i / 119)
        pts.append((r * math.cos(t + 1.2), r * math.sin(t + 1.2)))
    return line('M' + 'L'.join(f'{n(x)} {n(y)}' for x, y in pts), f, .12)
def c_koru(f, a):
    d = 'M-.1 .9C-.55 .5 -.55 -.5 .05 -.7C.55 -.85 .85 -.25 .55 .1C.3 .35 .0 .15 .12 -.1'
    return line(d, f, .2) + circ(.14, -.12, .1, f)
def c_concentric(f, a):
    return ''.join(circ(0, 0, r, 'none', f'stroke="{f if i % 2 == 0 else a}" stroke-width=".13"') for i, r in enumerate((.9, .65, .4))) + circ(0, 0, .16, f) + \
        ''.join(circ(.78 * math.cos(math.radians(i * 30)), .78 * math.sin(math.radians(i * 30)), .035, f) for i in range(12) if False)
def c_dots_ring(f, a):
    return ''.join(circ(.9 * math.cos(math.radians(i * 22.5)), .9 * math.sin(math.radians(i * 22.5)), .07, f) for i in range(16)) + c_concentric(f, a).replace('0.9', '0.5')
def c_boomerang(f, a):
    return path('M-.95 -.15C-.5 -.62 .5 -.62 .95 -.15L.88 .1C.4 -.28 -.4 -.28 -.88 .1Z', f)
def c_chakana(f, a):
    r = rect(-.33, -1, .66, 2, f) + rect(-1, -.33, 2, .66, f) + rect(-.66, -.66, 1.32, 1.32, f)
    return r + circ(0, 0, .2, a) + ''.join(rect(x - .09, y - .09, .18, .18, a) for x, y in ((-.5, -.5), (.5, -.5), (-.5, .5), (.5, .5)) if False)
def c_stair_diamond(f, a):
    out = ''
    for i, hw in enumerate((.95, .75, .55, .35)):
        out += rect(-hw, -.95 + i * .0, 0, 0, f) if False else ''
    rows = ''.join(rect(-w, y, 2 * w, .24, f if i % 2 == 0 else a) for i, (w, y) in enumerate(((.18, -.95), (.42, -.71), (.66, -.47), (.9, -.23), (.9, .01), (.66, .25), (.42, .49), (.18, .73))))
    return rows
def c_medicine_wheel(f, a):
    q = lambda k, col: path(f'M0 0L0 -.88A.88 .88 0 0 1 .88 0Z', col, f'transform="rotate({k * 90})"')
    cols = [RED, YEL, BLACK, WHITE]
    return ''.join(q(k, cols[k]) for k in range(4)) + circ(0, 0, .88, 'none', f'stroke="{f}" stroke-width=".07"') + line('M0 -.88V.88M-.88 0H.88', f, .05)
def c_feather(f, a, rot=0):
    return grp(path('M0 -1C.35 -.6 .3 .3 0 .85C-.3 .3 -.35 -.6 0 -1Z', f) + line('M0 -.9V1', a, .05), rot=rot)
def c_feathers(f, a):
    return ''.join(grp(c_feather(f, a), 0, .15, .9, r) for r in (-35, 0, 35))
def c_arrow(f, a):
    return line('M-.95 .95L.8 -.8', f, .08) + poly([(.72, -.98), (1.0, -1.0), (.98, -.72)], f) + poly([(-.95, .95), (-.75, .75), (-.9, .62)], f)
def c_arrows_cross(f, a): return grp(c_arrow(f, a), rot=0) + grp(c_arrow(f, a), rot=90)
def c_thunderbird(f, a):
    wing = poly([(.14, -.1), (.55, -.55), (.62, -.2), (1.0, -.5), (.95, 0), (.62, .12), (.78, .38), (.4, .32), (.2, .15)], f)
    return wing + grp(wing, mirror=True) + poly([(-.14, -.3), (.14, -.3), (.18, .5), (0, .95), (-.18, .5)], f) + circ(0, -.5, .2, f) + poly([(-.06, -.52), (.06, -.52), (0, -.3)], a) + poly([(-.14, -.8), (0, -.62), (.14, -.8), (0, -1)], f)
def c_turtle(f, a):
    legs = ''.join(circ(x * .62, y * .5, .22, f) for x in (-1, 1) for y in (-1, 1)) + circ(0, -.82, .2, f) + poly([(-.1, .7), (.1, .7), (0, 1.0)], f)
    shell = f'<ellipse cx="0" cy="0" rx=".66" ry=".78" fill="{f}"/>'
    pat = poly(star_pts(6, .9, .28, 0), a, 'opacity=".75"') + ''.join(line(f'M{n(.28 * math.cos(math.radians(r)))} {n(.28 * math.sin(math.radians(r)))}L{n(.62 * math.cos(math.radians(r)))} {n(.7 * math.sin(math.radians(r)))}', a, .045) for r in range(0, 360, 60))
    return legs + shell + pat
def c_paw(f, a):
    return f'<ellipse cx="0" cy=".3" rx=".52" ry=".45" fill="{f}"/>' + ''.join(f'<ellipse cx="{n(x)}" cy="{n(y)}" rx=".17" ry=".24" fill="{f}" transform="rotate({n(r)} {n(x)} {n(y)})"/>' for x, y, r in ((-.7, -.15, -25), (-.25, -.55, -8), (.25, -.55, 8), (.7, -.15, 25)))
def c_hand(f, a):
    fing = lambda x, y, h, r: f'<rect x="{n(x - .1)}" y="{n(y - h)}" width=".2" height="{n(h)}" rx=".1" fill="{f}" transform="rotate({r} {n(x)} {n(y)})"/>'
    return rect(-.42, -.1, .84, .85, f, 'rx=".2"') + fing(-.34, -.05, .7, -8) + fing(-.12, -.1, .95, -2) + fing(.12, -.1, 1.0, 2) + fing(.34, -.05, .85, 8) + fing(-.46, .3, .55, -62)
def c_wolf(f, a):
    head = poly([(-.55, -.2), (-.62, -.95), (-.28, -.55), (.28, -.55), (.62, -.95), (.55, -.2), (.3, .35), (.12, .9), (-.12, .9), (-.3, .35)], f)
    return head + poly([(-.3, -.1), (-.12, 0), (-.28, .08)], a) + poly([(.3, -.1), (.12, 0), (.28, .08)], a) + poly([(-.1, .78), (.1, .78), (0, .9)], a)
def c_stag(f, a):
    ant = lambda s: grp(line('M.2 -.3C.3 -.5 .5 -.55 .62 -.9M.42 -.58C.55 -.5 .75 -.6 .9 -.5M.5 -.7C.6 -.78 .62 -.95 .55 -1.0M.28 -.42C.42 -.2 .7 -.25 .88 -.1', f, .08), mirror=(s < 0))
    head = poly([(-.2, -.35), (.2, -.35), (.28, -.05), (.12, .7), (0, .85), (-.12, .7), (-.28, -.05)], f)
    return ant(1) + ant(-1) + head + poly([(-.35, -.2), (-.18, -.05), (-.4, .0)], f) + poly([(.35, -.2), (.18, -.05), (.4, .0)], f)
def c_bull(f, a):
    return path('M-.95 -.55C-.7 -.05 -.45 -.1 -.35 -.1H.35C.45 -.1 .7 -.05 .95 -.55C.8 .1 .6 .25 .38 .25L.22 .9H-.22L-.38 .25C-.6 .25 -.8 .1 -.95 -.55Z', f) + circ(-.2, .2, .05, a) + circ(.2, .2, .05, a)
def c_fish(f, a):
    return f'<ellipse cx="-.1" cy="0" rx=".72" ry=".38" fill="{f}"/>' + poly([(.55, 0), (1.0, -.38), (1.0, .38)], f) + circ(-.5, -.08, .07, a) + line('M-.05 -.3Q.1 0 -.05 .3', a, .05)
def c_whale(f, a):
    return path('M-.1 .9C-.1 .3 -.2 .0 -.85 -.55C-.55 -.45 -.3 -.4 -.05 -.15C.2 -.4 .5 -.45 .85 -.55C.2 .0 .1 .3 .1 .9Z', f)
def c_inuksuk(f, a):
    return rect(-.2, -.95, .4, .28, f, 'rx=".08"') + rect(-.65, -.62, 1.3, .2, f, 'rx=".08"') + rect(-.28, -.42, .56, .26, f, 'rx=".08"') + rect(-.4, -.16, .8, .26, f, 'rx=".08"') + rect(-.5, .1, .38, .85, f, 'rx=".08"') + rect(.12, .1, .38, .85, f, 'rx=".08"')
def c_pot(f, a):
    body = path('M-.4 -.8H.4C.4 -.6 .8 -.4 .8 .1C.8 .65 .45 .9 0 .9C-.45 .9 -.8 .65 -.8 .1C-.8 -.4 -.4 -.6 -.4 -.8Z', f)
    bands = line('M-.78 -.05H.78M-.7 .38H.7', a, .07) + ''.join(poly([(x - .1, .05), (x + .1, .05), (x, .3)], a) for x in (-.5, -.17, .17, .5))
    return body + bands
def c_beaker(f, a):
    body = path('M-.55 -.9C-.6 -.4 -.8 -.1 -.5 .3C-.4 .55 -.5 .85 -.4 .95H.4C.5 .85 .4 .55 .5 .3C.8 -.1 .6 -.4 .55 -.9Z', f)
    return body + ''.join(line(f'M{n(-.6 + .0)} {y}H.6', a, .05) for y in (-.5, -.15, .25)) + ''.join(poly([(x - .09, -.15), (x + .09, -.15), (x, .1)], a) for x in (-.4, -.1, .2, .5)[:3])
def c_mound(f, a):
    return path('M-1 .7C-.6 .7 -.6 -.5 0 -.5C.6 -.5 .6 .7 1 .7Z', f) + rect(-1, .7, 2, .12, f) + ''.join(line(f'M{x} .45Q{x + .15} .25 {x + .3} .45', a, .05) for x in (-.4, .05, -.1)[:2])
def c_earthwork(f, a):
    oct_ = poly(star_pts(8, 1, .6, -67.5, -.42, 0), 'none', f'stroke="{f}" stroke-width=".09" stroke-linejoin="round"')
    return oct_ + circ(.55, 0, .42, 'none', f'stroke="{f}" stroke-width=".09"') + circ(-.42, 0, .1, f)
def c_cross_ring(f, a): return circ(0, 0, .85, 'none', f'stroke="{f}" stroke-width=".12"') + c_cross_greek(f, a, .22)
def c_rose(f, a):
    p = lambda r: grp(f'<ellipse cx="0" cy="-.6" rx=".34" ry=".42" fill="{f}"/>', rot=r)
    return ''.join(p(i * 72) for i in range(5)) + circ(0, 0, .28, a)
def c_wheat(f, a):
    ear = lambda r: grp(''.join(f'<ellipse cx="{n(x)}" cy="{n(y)}" rx=".11" ry=".2" fill="{f}" transform="rotate({n(ang)} {n(x)} {n(y)})"/>' for x, y, ang in ((-.17, -.55, -30), (.17, -.55, 30), (-.18, -.2, -30), (.18, -.2, 30), (-.18, .15, -30), (.18, .15, 30), (0, -.82, 0))) + line('M0 -.7V.95', f, .06), rot=r)
    return ear(0) + ear(-28) + ear(28)
def c_palm(f, a):
    fronds = ''.join(line(f'M0 -.5Q{n(.5 * s)} {n(-.95)} {n(.95 * s)} {n(-.35 + k)}', f, .1) for s in (-1, 1) for k in (0, .25)) + line('M0 -.5Q.2 -1 .3 -.95M0 -.5Q-.2 -1 -.3 -.95', f, .1)
    return line('M.05 .95Q-.1 .2 0 -.5', f, .17) + fronds
def c_tree(f, a):
    return line('M0 .95V-.1', f, .16) + circ(0, -.42, .55, f) + line('M0 .3L.3 .05M0 .5L-.3 .22', f, .08) + ''.join(circ(x, y, .05, a) for x, y in ((-.2, -.5), (.18, -.3), (.05, -.7), (-.3, -.25), (.32, -.55)))
def c_mountains(f, a):
    return poly([(-1, .7), (-.35, -.6), (.1, .7)], f) + poly([(-.2, .7), (.45, -.85), (1, .7)], f) + poly([(.45, -.85), (.3, -.55), (.45, -.62), (.58, -.52)], a) + poly([(-.35, -.6), (-.45, -.38), (-.35, -.43), (-.25, -.36)], a)
def c_waves(f, a):
    return ''.join(line(f'M-1 {y}Q-.75 {y - .22} -.5 {y}T0 {y}T.5 {y}T1 {y}', f, .12) for y in (-.45, -.05, .35))
def c_key(f, a):
    return circ(-.45, 0, .38, 'none', f'stroke="{f}" stroke-width=".16"') + line('M-.07 0H.95M.6 0V.3M.82 0V.25', f, .15)
def c_stool(f, a):
    return path('M-.9 -.3C-.9 -.55 -.55 -.55 -.45 -.3H.45C.55 -.55 .9 -.55 .9 -.3C.9 -.1 .6 -.05 .45 -.1H-.45C-.6 -.05 -.9 -.1 -.9 -.3Z', f) + rect(-.18, -.1, .36, .75, f) + path('M-.7 .65H.7L.82 .95H-.82Z', f)
def c_stele(f, a):
    return poly([(-.2, .95), (-.2, -.7), (-.05, -.95), (.05, -.95), (.2, -.7), (.2, .95)], f) + ''.join(rect(-.2, y, .4, .06, a) for y in (-.5, -.25, 0, .25, .5)) + rect(-.55, .75, 1.1, .2, f)
def c_pyramid(f, a):
    rows = ''.join(rect(-(.9 - i * .17), -.7 + i * .22, 2 * (.9 - i * .17), .22, f if i % 2 == 0 else mix(f, a, .35)) for i in range(5))
    return rows + rect(-.28, -.9, .56, .2, f)
def c_drum(f, a):
    return f'<ellipse cx="0" cy="0" rx=".95" ry=".95" fill="{f}"/>' + circ(0, 0, .78, a) + c_sun(f, a, 8).replace('<polygon', '<polygon', 1).join(['<g transform="scale(.55)">', '</g>'])
def c_bow(f, a):
    return line('M-.55 -.95Q.95 0 -.55 .95', f, .12) + line('M-.55 -.95V.95', a, .04)
def c_eagle(f, a, heads=1):
    wing = poly([(.14, -.3), (.5, -.72), (.95, -.8), (.9, -.55), (1.0, -.5), (.9, -.28), (.98, -.2), (.82, -.02), (.9, .1), (.66, .15), (.62, .3), (.38, .22), (.14, .3)], f)
    tail = poly([(-.26, .38), (.26, .38), (.36, .95), (.18, .85), (0, 1.0), (-.18, .85), (-.36, .95)], f)
    body = path('M0 -.55C.28 -.45 .3 .0 .22 .42H-.22C-.3 .0 -.28 -.45 0 -.55Z', f)
    legs = rect(-.2, .38, .09, .25, a) + rect(.11, .38, .09, .25, a)
    if heads == 2:
        h = ''.join(circ(s * .26, -.66, .14, f) + poly([(s * .26, -.72), (s * (.26 + .22), -.64), (s * .26, -.58)], a) for s in (-1, 1)) + path('M-.12 -.55L-.26 -.62M.12 -.55L.26 -.62', f, 'stroke="%s" stroke-width=".12"' % f)
    else:
        h = circ(0, -.68, .16, f) + poly([(.08, -.72), (.3, -.64), (.08, -.58)], a)
    return wing + grp(wing, mirror=True) + tail + body + legs + h
def c_eagle2(f, a): return c_eagle(f, a, 2)
def c_lion_head(f, a):
    mane = poly(star_pts(14, .78, 1, -90), f)
    face = circ(0, .05, .56, mix(f, a, .45))
    return mane + face + circ(-.2, -.1, .07, a) + circ(.2, -.1, .07, a) + poly([(-.1, .08), (.1, .08), (0, .2)], a) + line('M0 .2V.32M-.15 .38Q0 .5 .15 .38', a, .05)
def c_horsetail(f, a):  # sulde / tug: spear with a tuft of hair
    hair = ''.join(line(f'M0 -.35C{n(.2 * k)} -.1 {n(.45 * k)} .1 {n(.55 * k)} .55', f, .1) for k in (-1.0, -.6, -.2, .2, .6, 1.0))
    return line('M0 -.7V.95', f, .08) + poly([(-.18, -.7), (0, -1.0), (.18, -.7)], f) + circ(0, -.4, .2, f) + hair
def c_trigram(f, a):
    return ''.join(rect(-.8, y, 1.6, .22, f) for y in (-.8, -.4, 0, .4, .8 - .0)[:4])
def c_horn(f, a):
    return path('M-.9 .5C-.9 -.6 .0 -.95 .85 -.7C.1 -.55 -.3 -.2 -.3 .5Z', f) + circ(.0, .75, .0, f)
def c_wave_sun(f, a):
    return c_sun_half(f, a) + ''.join(line(f'M-1 {y}Q-.75 {y - .13} -.5 {y}T0 {y}T.5 {y}T1 {y}', a, .07) for y in (.62, .86))
def c_star_cluster(f, a):  # Southern Cross
    return ''.join(grp(poly(star_pts(5 if k < 4 else 5, .42), f), x, y, s) for k, (x, y, s) in enumerate(((0, -.72, .26), (0, .72, .3), (-.68, 0, .24), (.68, -.05, .26), (.3, .22, .14))))
def c_stars_ring(f, a, k=7):
    return ''.join(grp(poly(star_pts(5, .42), f), .75 * math.cos(math.radians(-90 + i * 360 / k)), .75 * math.sin(math.radians(-90 + i * 360 / k)), .22) for i in range(k)) + poly(star_pts(5, .42), f, 'transform="scale(.3)"')
def c_rings(f, a):
    return ''.join(circ(x, y, .38, 'none', f'stroke="{f}" stroke-width=".11"') for x, y in ((-.62, -.3), (0, -.3), (.62, -.3), (-.31, .22), (.31, .22)))
def c_hexagram(f, a): return poly([(0, -1), (.87, .5), (-.87, .5)], 'none', f'stroke="{f}" stroke-width=".13" stroke-linejoin="round"') + poly([(0, 1), (.87, -.5), (-.87, -.5)], 'none', f'stroke="{f}" stroke-width=".13" stroke-linejoin="round"') + poly(star_pts(3, 1, 1, 90), 'none', f'stroke="{f}" stroke-width=".13" stroke-linejoin="round"')
def c_feather_crown(f, a):
    return ''.join(grp(path('M0 0C.12 -.35 .08 -.8 0 -1C-.08 -.8 -.12 -.35 0 0Z', f if i % 2 == 0 else a), 0, .5, 1, -70 + i * 140 / 6) for i in range(7)) + rect(-.7, .45, 1.4, .25, f)
def c_kiosk(f, a): return c_cross_ring(f, a)
def c_bell(f, a): return c_beaker(f, a)
def c_flame(f, a): return path('M0 -1C.5 -.4 .75 -.1 .6 .4C.5 .8 .1 .95 -.1 .9C-.6 .85 -.75 .4 -.55 0C-.4 .3 -.25 .3 -.2 .1C-.1 -.2 -.3 -.6 0 -1Z', f)
def c_hex_shield(f, a): return c_shield(f, a)
def c_book(f, a): return path('M0 -.55C-.4 -.75 -.75 -.7 -.95 -.6V.6C-.75 .5 -.4 .45 0 .65C.4 .45 .75 .5 .95 .6V-.6C.75 -.7 .4 -.75 0 -.55Z', f) + line('M0 -.55V.65', a, .05)
def c_castle(f, a): return c_tower(f, a)
def c_bridge(f, a): return rect(-1, -.1, 2, .22, f) + ''.join(path(f'M{x - .3} .12A.3 .3 0 0 0 {x + .3} .12', f, f'stroke="{f}" stroke-width=".12" fill="none"') for x in (-.6, 0, .6))
def c_cornucopia(f, a): return c_horn(f, a)
def c_grid_wipha(f, a): return ''


# ---- revised / added charges (later definitions win)
def c_axe(f, a):
    blade = lambda sx: grp(path('M.05 -.78L.95 -.98Q.66 -.4 .95 .22L.05 .0Z', f), mirror=(sx < 0))
    return rect(-.05, -1, .1, 2, f) + blade(1) + blade(-1) + circ(0, -.4, .1, a)
def c_cross_jerusalem(f, a):
    return c_cross_greek(f, a, .3) + ''.join(grp(c_cross_greek(f, a, .38), x * .6, y * .6, .2) for x in (-1, 1) for y in (-1, 1))
def c_hexagram(f, a): return poly([(0, -1), (.87, .5), (-.87, .5)], 'none', f'stroke="{f}" stroke-width=".13" stroke-linejoin="round"') + poly([(0, 1), (.87, -.5), (-.87, -.5)], 'none', f'stroke="{f}" stroke-width=".13" stroke-linejoin="round"')
def c_valknut(f, a):
    tri = lambda ang: grp(poly([(0, -.62), (.54, .31), (-.54, .31)], 'none', f'stroke="{f}" stroke-width=".13" stroke-linejoin="round"'), .0, 0, 1, ang)
    return grp(tri(0), 0, -.28, 1) + grp(tri(0), -.3, .22, 1) .replace('translate(-.3 .22)', 'translate(-.32 .26)') + grp(tri(0), .32, .26, 1)
def c_lotus(f, a):
    pet = lambda ang, s: f'<g transform="translate(0 .62) rotate({ang}) scale({s})">' + path('M0 0C.3 -.28 .3 -.8 0 -1.3C-.3 -.8 -.3 -.28 0 0Z', f) + '</g>'
    return pet(-64, .62) + pet(64, .62) + pet(-34, .8) + pet(34, .8) + pet(0, .95) + path('M-.95 .72Q0 1.0 .95 .72Q0 .86 -.95 .72Z', f)
def c_mound(f, a):
    return path('M-1 .72C-.65 .72 -.55 -.5 0 -.5C.55 -.5 .65 .72 1 .72Z', f) + ''.join(line(f'M{x} .55L{x + .26} .0', a, .06) for x in (-.45, -.1, .25))
def c_whale(f, a):
    return path('M0 .95V.25C-.08 -.02 -.3 -.2 -.95 -.3C-.75 -.7 -.3 -.72 0 -.18C.3 -.72 .75 -.7 .95 -.3C.3 -.2 .08 -.02 0 .25Z', f)
def c_wheat(f, a):
    stalk = lambda ang: f'<g transform="rotate({ang})">' + line('M0 .95V-.7', f, .07) + ''.join(
        f'<ellipse cx="{n(sx * .17)}" cy="{n(y)}" rx=".08" ry=".21" fill="{f}" transform="rotate({sx * 38} {n(sx * .17)} {n(y)})"/>' for y in (-.55, -.28, -.01) for sx in (-1, 1)) + '<ellipse cx="0" cy="-.85" rx=".08" ry=".22" fill="%s"/>' % f + '</g>'
    return stalk(-22) + stalk(22) + stalk(0)
def c_feathers(f, a):
    fe = lambda ang, col: f'<g transform="translate(0 .85) rotate({ang})">' + path('M0 0C.22 -.3 .24 -1.1 0 -1.75C-.24 -1.1 -.22 -.3 0 0Z', col) + line('M0 -.1V-1.5', a, .04) + '</g>'
    return fe(-40, a if False else f) .replace('M0 0', 'M0 0') + fe(40, f) + fe(-20, light(f, .25)) + fe(20, light(f, .25)) + fe(0, f)
def c_rings3(f, a): return ''.join(circ(x, y, .4, 'none', f'stroke="{f}" stroke-width=".15"') for x, y in ((-.5, .38), (.5, .38), (0, -.5)))
def c_bird(f, a):
    return f'<ellipse cx="-.05" cy=".1" rx=".55" ry=".4" fill="{f}" transform="rotate(-14)"/>' + circ(.5, -.45, .22, f) + poly([(.66, -.5), (.98, -.4), (.66, -.34)], a) + poly([(-.5, .1), (-1.0, .45), (-.95, .6), (-.4, .35)], f) + rect(-.12, .45, .07, .4, f) + rect(.1, .42, .07, .4, f) + circ(.55, -.5, .04, a)
def c_ermine(f, a):
    return line('M0 -.85V.1', f, .24) + poly([(-.25, -.1), (0, .1), (.25, -.1), (.0, .85)], f) .replace('.0,.85', '0,.85') if False else poly([(0, -.9), (.18, -.2), (.55, .0), (.18, .1), (.2, .55), (0, .2), (-.2, .55), (-.18, .1), (-.55, 0), (-.18, -.2)], f)
def c_angkor(f, a):
    tower = lambda x, w, h: poly([(x - w, .75), (x - w, .75 - h * .35), (x - w * .75, .75 - h * .35), (x - w * .75, .75 - h * .6), (x - w * .45, .75 - h * .6), (x - w * .45, .75 - h * .8), (x, .75 - h), (x + w * .45, .75 - h * .8), (x + w * .45, .75 - h * .6), (x + w * .75, .75 - h * .6), (x + w * .75, .75 - h * .35), (x + w, .75 - h * .35), (x + w, .75)], f)
    return tower(0, .38, 1.55) + tower(-.62, .27, 1.1) + tower(.62, .27, 1.1) + rect(-.95, .75, 1.9, .16, f)
def c_winged_lion(f, a):
    wing = poly([(.1, -.1), (.5, -.75), (.95, -.9), (.8, -.45), (.95, -.35), (.7, -.1), (.8, .05), (.4, .1)], f)
    return wing + grp(wing, mirror=True) + c_lion_head(f, a).replace('<polygon', '<polygon', 1) if False else grp(c_lion_head(f, a), 0, .3, .62) + wing + grp(wing, mirror=True)
for _k in ('kiosk', 'bell', 'hex_shield', 'cornucopia', 'grid_wipha', 'bridge', 'trigram', 'moon_orb', 'kiosk'): globals().pop('c_' + _k, None)

CH = {k[2:]: v for k, v in list(globals().items()) if k.startswith('c_') and callable(v)}

# ---------------------------------------------------------------- fields.  each returns (svg, colour under the centre, centre x, y)
def f_solid(c, r): return rect(0, 0, W, H, c[0]), c[0]
def f_hbands(c, r, k=3):
    cols = [c[i % len(c)] for i in range(k)] if k <= len(c) else [c[i % len(c)] for i in range(k)]
    if k == 3 and len(c) >= 3: cols = [c[0], c[1], c[2]]
    h = H / k; return ''.join(rect(0, i * h, W, h + .5, cols[i]) for i in range(k)), cols[k // 2]
def f_h121(c, r): return rect(0, 0, W, H, c[0]) + rect(0, 50, W, 100, c[1]) + rect(0, 0, W, 0, c[0]), c[1]
def f_hstripes(c, r, k=7): return ''.join(rect(0, i * H / k, W, H / k + .5, c[i % 2]) for i in range(k)), c[(k // 2) % 2]
def f_vbands(c, r, k=3): return ''.join(rect(i * W / k, 0, W / k + .5, H, c[i % len(c)] if k > 2 else c[[0, 1, 2][i] if len(c) > 2 else i % 2]) for i in range(k)), c[(k // 2) % len(c)] if k > 2 else c[0]
def f_pale(c, r): return rect(0, 0, W, H, c[0]) + rect(W / 2 - 50, 0, 100, H, c[1]) + rect(W / 2 - 50, 0, 8, H, c[2]) + rect(W / 2 + 42, 0, 8, H, c[2]), c[1]
def f_fesse(c, r): return rect(0, 0, W, H, c[0]) + rect(0, 70, W, 60, c[1]) + rect(0, 62, W, 8, c[2]) + rect(0, 130, W, 8, c[2]), c[1]
def f_diag(c, r): return rect(0, 0, W, H, c[0]) + poly([(0, 0), (W, 0), (0, H)], c[1]), c[0]
def f_diag2(c, r): return rect(0, 0, W, H, c[0]) + poly([(W, 0), (W, H), (0, H)], c[1]), c[0]
def f_saltire(c, r): return rect(0, 0, W, H, c[0]) + poly([(0, 0), (40, 0), (W, H - 27), (W, H), (W - 40, H), (0, 27)], c[1]) + poly([(W, 0), (W - 40, 0), (0, H - 27), (0, H), (40, H), (W, 27)], c[1]), c[0]
def f_cross(c, r): return rect(0, 0, W, H, c[0]) + rect(0, 78, W, 44, c[1]) + rect(128, 0, 44, H, c[1]), c[1]
def f_nordic(c, r): return rect(0, 0, W, H, c[0]) + rect(0, 78, W, 44, c[1]) + rect(86, 0, 44, H, c[1]) + rect(0, 90, W, 20, c[2]) + rect(98, 0, 20, H, c[2]), c[0]
def f_triangle(c, r): return rect(0, 0, W, H / 2, c[0]) + rect(0, H / 2, W, H / 2, c[1]) + poly([(0, 0), (130, H / 2), (0, H)], c[2]), c[0]
def f_chevron(c, r): return rect(0, 0, W, H, c[0]) + poly([(0, 0), (150, 100), (0, H), (0, H - 55), (82, 100), (0, 55)], c[1]), c[0]
def f_quarter(c, r): return rect(0, 0, W, H, c[0]) + rect(W / 2, 0, W / 2, H / 2, c[1]) + rect(0, H / 2, W / 2, H / 2, c[1]), c[0]
def f_quarter4(c, r): return rect(0, 0, W / 2, H / 2, c[0]) + rect(W / 2, 0, W / 2, H / 2, c[1]) + rect(0, H / 2, W / 2, H / 2, c[2]) + rect(W / 2, H / 2, W / 2, H / 2, c[0]), c[0]
def f_checky(c, r, cols=8, rows=5):
    cw, ch = W / cols, H / rows
    return rect(0, 0, W, H, c[0]) + ''.join(rect(i * cw, j * ch, cw + .3, ch + .3, c[1]) for i in range(cols) for j in range(rows) if (i + j) % 2 == 0), c[0]
def f_bend(c, r): return rect(0, 0, W, H, c[0]) + poly([(0, 0), (60, 0), (W, H - 40), (W, H), (W - 60, H), (0, 40)], c[1]) , c[0]
def f_bend_fim(c, r): return rect(0, 0, W, H, c[0]) + poly([(0, 0), (80, 0), (W, H - 53), (W, H), (W - 80, H), (0, 53)], c[2]) + poly([(0, 14), (50, 0), (W, H - 36), (W, H - 14), (W - 50, H), (0, 38)], c[1]), c[1]
def f_canton(c, r): return rect(0, 0, W, H, c[0]) + rect(0, 0, 120, 88, c[1]), c[0]
def f_chief(c, r): return rect(0, 0, W, H, c[0]) + rect(0, 0, W, 70, c[1]) + rect(0, 70, W, 7, c[2]), c[0]
def f_sunburst(c, r, k=16):
    out = rect(0, 0, W, H, c[0])
    for i in range(k):
        if i % 2: continue
        a0, a1 = math.radians(i * 360 / k), math.radians((i + 1) * 360 / k)
        out += poly([(150, 100), (150 + 400 * math.cos(a0), 100 + 400 * math.sin(a0)), (150 + 400 * math.cos(a1), 100 + 400 * math.sin(a1))], c[1])
    return out, c[0]
def f_border(c, r): return rect(0, 0, W, H, c[1]) + rect(16, 16, W - 32, H - 32, c[0]) + rect(26, 26, W - 52, H - 52, 'none', f'stroke="{c[2]}" stroke-width="3"'), c[0]
def f_lozenge(c, r): return rect(0, 0, W, H, c[0]) + poly([(150, 12), (W - 22, 100), (150, H - 12), (22, 100)], c[1]), c[1]
def f_gyronny(c, r):
    out = rect(0, 0, W, H, c[0]); pts = [(0, 0), (150, 0), (W, 0), (W, 100), (W, H), (150, H), (0, H), (0, 100)]
    for i in range(0, 8, 2): out += poly([(150, 100), pts[i], pts[(i + 1) % 8]], c[1])
    return out, c[0]
def f_wavy(c, r):
    d = 'M0 100' + ''.join(f'Q{12.5 + 25 * i} {(80 if i % 2 == 0 else 120)} {25 + 25 * i} 100' for i in range(12)) + f'V{H}H0Z'
    return rect(0, 0, W, H, c[0]) + path(d, c[1]), c[0]
def f_wave_bands(c, r):
    out = rect(0, 0, W, H, c[0])
    for j in range(3):
        y = 100 + j * 30 - 15
        d = f'M0 {y}' + ''.join(f'Q{12.5 + 25 * i} {y + (-9 if i % 2 == 0 else 9)} {25 + 25 * i} {y}' for i in range(12)) + f'V{H}H0Z'
        out += path(d, c[1 + j % 2] if j < 2 else c[1], 'opacity="%s"' % (1 if j == 0 else .8))
    return out, c[0]
def f_pall(c, r): return rect(0, 0, W, H, c[0]) + poly([(0, 0), (30, 0), (110, 100), (110, H / 2 + 0), (0, 40 + 0)], c[1]) if False else rect(0, 0, W, H, c[0]) + poly([(0, 0), (34, 0), (122, 84), (W, 84), (W, 116), (122, 116), (34, H), (0, H), (0, H - 28), (86, 100), (0, 28)], c[1]) + poly([(0, 0), (34, 0), (122, 84), (86, 100), (0, 28)], c[2]), c[0]
def f_zigzag(c, r):
    out = rect(0, 0, W, H, c[0]); k = 12; w = W / k
    top = 'M0 0' + ''.join(f'L{i * w + w / 2} 34L{(i + 1) * w} 0' for i in range(k)) + 'Z'
    bot = f'M0 {H}' + ''.join(f'L{i * w + w / 2} {H - 34}L{(i + 1) * w} {H}' for i in range(k)) + 'Z'
    return out + path(top, c[1]) + path(bot, c[1]) + rect(0, 40, W, 6, c[1], 'opacity=".0"'), c[0]
def f_fret_band(c, r):
    out = rect(0, 0, W, H, c[0]) + rect(0, 28, W, 18, c[1]) + rect(0, H - 46, W, 18, c[1])
    k = 15; w = W / k
    for y0 in (6, H - 24):
        out += path('M0 %s' % y0 + ''.join(f'h{w / 2}v6h{w / 2}' if False else f'h{w / 2}v12h{w / 2}v-12' for i in range(k)) + f'V{y0 + 18}H0Z', c[1], 'opacity="0"')
    out += ''.join(rect(i * w, 8, w / 2, 10, c[1]) + rect(i * w, H - 18, w / 2, 10, c[1]) for i in range(k))
    return out, c[0]
def f_stepped(c, r):
    out = rect(0, 0, W, H, c[0]) + rect(0, 70, W, 60, c[1])
    k = 15; w = W / k
    for i in range(k):
        x = i * w; out += poly([(x, 70), (x + w, 70), (x + w / 2, 52)], c[1]) + poly([(x, 130), (x + w, 130), (x + w / 2, 148)], c[1])
    return out + rect(0, 76, W, 4, c[2]) + rect(0, 120, W, 4, c[2]), c[1]
def f_vstripes_thin(c, r, k=9): return ''.join(rect(i * W / k, 0, W / k + .5, H, c[i % 2]) for i in range(k)), c[(k // 2) % 2]
def f_diamonds(c, r):
    out = rect(0, 0, W, H, c[0]); s = 50
    for i in range(-1, 7):
        for j in range(-1, 5):
            cx, cy = i * s + (s / 2 if j % 2 else 0), j * s / 2 * 1
            out += poly([(cx, cy - s / 2), (cx + s / 2, cy), (cx, cy + s / 2), (cx - s / 2, cy)], c[1], 'opacity=".0"')
    for j in range(0, 5):
        for i in range(-1, 7):
            cx, cy = i * 60 + (30 if j % 2 else 0), j * 50
            out += poly([(cx, cy - 22), (cx + 22, cy), (cx, cy + 22), (cx - 22, cy)], c[1])
    return out, c[0]
def f_semy(c, r, charge='star'):
    out = rect(0, 0, W, H, c[0]); fn = CH[charge]
    for j in range(5):
        for i in range(7):
            x = 20 + i * 43 + (21 if j % 2 else 0); y = 14 + j * 43
            if x < W + 10: out += grp(fn(c[1], c[0]), x, y, 11)
    return out, c[0]
def f_rays_corner(c, r):
    out = rect(0, 0, W, H, c[0])
    for i in range(0, 12, 2):
        a0, a1 = math.radians(i * 90 / 12), math.radians((i + 1) * 90 / 12)
        out += poly([(0, 0), (500 * math.cos(a0), 500 * math.sin(a0)), (500 * math.cos(a1), 500 * math.sin(a1))], c[1])
    return out, c[0]
def f_mantle(c, r): return rect(0, 0, W, H, c[0]) + poly([(0, 0), (W, 0), (W / 2, H * .62)], c[1], 'opacity="0"') + rect(0, 0, W, H / 2, c[1]) + poly([(0, H / 2), (W / 2, H), (W, H / 2)], c[1]), c[0]
def f_stripes_fim(c, r): return rect(0, 0, W, H, c[0]) + rect(0, 40, W, 120, c[1]) + rect(0, 75, W, 50, c[0]) + rect(0, 40, W, 6, c[2]) + rect(0, 154, W, 6, c[2]), c[0]
def f_dusk(c, r): return f'<defs><linearGradient id="gg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c[0]}"/><stop offset=".62" stop-color="{c[1]}"/><stop offset="1" stop-color="{c[2]}"/></linearGradient></defs>' + rect(0, 0, W, H, 'url(#gg)'), c[1]
def f_aurora(c, r):
    out = rect(0, 0, W, H, c[0])
    for i, (col, y, a) in enumerate(((c[1], 40, .55), (c[2], 76, .45), (c[1], 112, .35))):
        out += path(f'M0 {y}C80 {y - 50} 160 {y + 40} 300 {y - 20}V{y + 36}C160 {y + 100} 90 {y - 12} 0 {y + 50}Z', col, f'opacity="{a}"')
    return out, c[0]


FIELDS = {k[2:]: v for k, v in list(globals().items()) if k.startswith('f_')}
FIELDS['h2'] = lambda c, r: f_hbands(c, r, 2)
FIELDS['h3'] = lambda c, r: f_hbands(c, r, 3)
FIELDS['h5'] = lambda c, r: f_hbands(c, r, 5)
FIELDS['v2'] = lambda c, r: f_vbands(c, r, 2)
FIELDS['v3'] = lambda c, r: f_vbands(c, r, 3)
FIELDS['v4'] = lambda c, r: f_vbands(c, r, 4)


# ---------------------------------------------------------------- finishing
def medallion(kind, bg, rim, x, y, r):
    if kind == 'disc': return circ(x, y, r, bg) + circ(x, y, r - 6, 'none', f'stroke="{rim}" stroke-width="2.5"')
    if kind == 'ring': return circ(x, y, r, bg) + circ(x, y, r, 'none', f'stroke="{rim}" stroke-width="5"') + circ(x, y, r - 9, 'none', f'stroke="{rim}" stroke-width="1.5" stroke-dasharray="2 5"')
    if kind == 'lozenge': return poly([(x, y - r * 1.15), (x + r * 1.15, y), (x, y + r * 1.15), (x - r * 1.15, y)], bg) + poly([(x, y - r * 1.15 + 6), (x + r * 1.15 - 6, y), (x, y + r * 1.15 - 6), (x - r * 1.15 + 6, y)], 'none', f'stroke="{rim}" stroke-width="2"')
    if kind == 'shield':
        return grp(path('M-.78 -.9H.78V.1C.78 .62 .34 .9 0 1.1C-.34 .9 -.78 .62 -.78 .1Z', bg, f'stroke="{rim}" stroke-width=".06"'), x, y, r * 1.05)
    if kind == 'octa': return poly(star_pts(8, 1, r * 1.08, -67.5, x, y), bg) + poly(star_pts(8, 1, r * 1.08 - 6, -67.5, x, y), 'none', f'stroke="{rim}" stroke-width="2"')
    return ''


def edge(kind, c, rim, r):
    if kind == 'hem': return rect(0, 0, W, H, 'none', f'stroke="{rim}" stroke-width="10" opacity=".9"') + rect(10, 10, W - 20, H - 20, 'none', f'stroke="{dark(rim, .35)}" stroke-width="2" opacity=".55"')
    if kind == 'inline': return rect(10, 10, W - 20, H - 20, 'none', f'stroke="{rim}" stroke-width="3.5" opacity=".85"')
    if kind == 'double': return rect(9, 9, W - 18, H - 18, 'none', f'stroke="{rim}" stroke-width="3"') + rect(17, 17, W - 34, H - 34, 'none', f'stroke="{rim}" stroke-width="1.2"')
    if kind == 'dots':
        out = ''
        for i in range(18): out += circ(9 + i * (W - 18) / 17, 10, 3, rim) + circ(9 + i * (W - 18) / 17, H - 10, 3, rim)
        for j in range(1, 11): out += circ(10, 10 + j * (H - 20) / 11, 3, rim) + circ(W - 10, 10 + j * (H - 20) / 11, 3, rim)
        return out
    if kind == 'tri':
        out = ''
        for i in range(15): out += poly([(i * 20, 0), (i * 20 + 20, 0), (i * 20 + 10, 12)], rim) + poly([(i * 20, H), (i * 20 + 20, H), (i * 20 + 10, H - 12)], rim)
        return out
    return ''


def cloth(uid):
    return (f'<defs><linearGradient id="s{uid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".16"/><stop offset=".45" stop-color="#fff" stop-opacity="0"/>'
            f'<stop offset="1" stop-color="#000" stop-opacity=".22"/></linearGradient></defs>' + rect(0, 0, W, H, f'url(#s{uid})'))


# ---------------------------------------------------------------- culture recipes
import special as _sp
FORCE = _sp.FORCE; SEMY_CHARGE = _sp.SEMY_CHARGE
SPECIAL = {k: (None if v is None else (v[0], [globals()[c] for c in v[1].split()], v[2], globals()[v[3]] if v[3] else None, v[4], v[5])) for k, v in _sp.SPECIAL.items()}


def has(name, *words): s = name.lower(); return any(w in s for w in words)


PAL = {
    'euro': [RED, BLUE, NAVY, GREEN, GOLD, WHITE, BLACK, PURP, CRIM],
    'islamic': [GREEN, FOREST, WHITE, BLACK, RED, GOLD, TEAL, CRIM],
    'steppe': [SKY, BLUE, WHITE, RED, YEL, BLACK, GREEN, ORNG, PURP],
    'africa': [GREEN, GOLD, RED, BLACK, YEL, WHITE, ORNG, BLUE, PURP],
    'india': [SAFF, MAR, GREEN, GOLD, WHITE, BLUE, RED, PURP, IND],
    'east': [RED, YEL, WHITE, BLACK, BLUE, GREEN, PURP, CRIM],
    'sea': [RED, YEL, BLUE, WHITE, GREEN, PURP, GOLD, TEAL],
    'native': [TERRA, TURQ, OCHRE, BLACK, WHITE, RED, BROWN, SAND, FOREST],
    'andes': [RED, TURQ, GOLD, BLACK, OCHRE, GREEN, PURP, ORNG, WHITE, MAR],
    'oceania': [RED, BLACK, WHITE, BLUE, TEAL, OCHRE, ORNG, TURQ],
    'aborig': [OCHRE, RED, BLACK, WHITE, TERRA, YEL],
    'earth': [BROWN, OCHRE, SAND, TERRA, OLIVE, BLACK, STONE, CLAY],
    'arctic': [BLUE, WHITE, RED, BLACK, TEAL, SKY, NAVY],
    'latam': [BLUE, WHITE, RED, YEL, GREEN, SKY, NAVY],
    'baltic': [RED, WHITE, GREEN, BLACK, GOLD, BLUE, OCHRE],
}

# culture of every id (ids not listed fall back to keyword rules in classify())
CULT = {}
def _c(cul, ids):
    for i in ids.split(): CULT[i] = cul
_c('euro', 'albania aragon arago_n austria_hungary austrian_empire batavian_republic bosnia britany burgandy byzantine_empire castile castilla castille corsica croatia cyprus czechoslovakia dardania denmark denmark_norway dutch_republic dutchy_of_benevento england england_and_ireland english_territory france german_empire germany grand_duchy_of_moscow helvetic_republic holy_roman_empire hungary icelandic_commonwealth imperial_hungary italy kalmar_union kievan_rus kingdom_of_the_two_sicilies leo_n lithuania luxembourg macedon_and_hellenic_league moldova montenegro navarre netherlands norsemen norway novgorod papal_states poland poland_lithuania polish_lithuanian_commonwealth portugal principality_of_polotsk principality_of_wallachia prussia pskov ras_ka romania rome roman_empire russia russian_empire ryazan sardinia sardinia_piedmont saxony scotland scottalnd scottland serbia sicily spain spanish_habsburg swabia sweden sweden_norway swiss_confederation switzerland teutonic_knights trebizond tsardom_of_muscovy tuscany ussr venice yugoslavia pergamon ptolemaic_kingdom seleucid_kingdom carthage mauretania kingdom_of_syphax heruli celtic_kingdoms celts boihaenum georgia kingdom_of_georgia kakheti_hereti armenia artsakh syunik tashir shirvan arran sambian_nothangian_culture curonians prussians')
_c('islamic', 'almoravid_dynasty fatimid_caliphate ghaznavid_emirate seljuk_caliphate seljuk_empire mamluke_sultanate hafsid_caliphate zayyanid_caliphate wattasid_caliphate safavid_empire ottoman_empire mughal_empire arabia arabia_nejd arabs oman muscat maskat yemen qatar hadramaut nejd saudi_arabia mahra nabatean_kingdom persia iran afghanistan granada beylik_of_aydin emirate_of_the_white_sheep_turks islamic_city_states islamic_states trucial_oman egypt libya morocco sokoto_caliphate tukular_caliphate soomra_emirate karkhanids bokhara_khanate khiva_khanate parthia parthian_empire suren_kingdom ilkhanate maan gharra himyarite_kingdom saba qataban sindh')
_c('steppe', 'xiongnu scythians alans saka_kingdom yuezhi oirat_confederation nogai_horde cuman_kipchak_confederation turcik_tribes oghuz volga_bulgars bulgar_khanate mongol_empire mongols mongolia chagatai_khanate golden_horde khanate_of_the_golden_horde white_horde khanate_of_sibir central_asian_khanates quazaq_khanate karakalpaks timurid_emirates timurid_empire tungus')
_c('east', 'han han_empire ming_chinese_empire qing_empire song_empire liao xixia manchu_empire nan_chao nan_yue min_yue chinese_warlords post_ming_warlords koguryo paekche silla korea japan imperial_japan imperial_japan_fujiwara shogun_japan_kamakura tokugawa_shogunate hainan taiwan tibet zhangzhung_kingdom xinjiang')
_c('sea', 'a_i_vie_t annam cochin_china champa khmer_empire cambodia laos lan_na laotian_states thai kingdom_of_sukhotai sukhothai ayutthaya rattanakosin_kingdom burma burmese_kingdoms pagan ava pegu pyu_state mon_state mon_khmer shan_states arakan arakan_indian_princely_state srivijaya_empire malacca malaya malays malaysian_islamic_states brunei aceh east_java kediri dutch_east_indies philippines')
_c('india', 'ahmadnagar bengal bhutan bundelkhand ceylon chandellas chauhans chola cholas circars golkonda hindu_kingdoms kalinga kashmir_and_ladakh magadha maratha_confederacy mauryan_empire minor_hindu_and_buddhist_kingdoms minor_hindu_and_buddhist_states minor_hindu_kingdoms mysore nepal nizam_s_dominions palas pandya_state pratiharas rajastan rajputs satavahanihara senas sikhs simhala sinhalese_kingdom sinhalese_kingdoms solankis sultanate_of_delhi vijayanagara western_chalukyas')
_c('africa', 'abyssinia adal akan alwa asante ato_trading_confederacy awsa axum bagirmi bantou barotse benin borgu_states bornu_kanem buganda bunyoro burundi calabar congo cotonou dahomey darfur dendi_kingdom ethiopia expansionist_kingdom_of_merina funj futa_jalon futa_toro ghana great_zimbabwe hausa_states ibadan imerina ivory_coast kaarta kanem kanem_bornu khoiasan khundzi kingdom_of_gala kong_empire kuba liberia lozi luba lunda madagascar makkura malawi mali mbailundu meroe mirambo_unyanyembe_ukimbu mossi_states mwenemutapa ndebele nguni ngwato obiwa oromo ovimbundu oyo rabih_az_zubayr rift_valley_states rozwi rwanda saharan_pastoral_nomads segu shoa shona sierra_leone songhai sotho sudan sultanate_of_damagaram sultanate_of_utetera sultinate_of_zanzibar swaziland takrur teke transvaal union_of_south_africa orange_free_state wadai wadai_empire wassoulou_empire xhosa yeke zanzibar zulu gambia_the wawula dumonii yankontai')
_c('native', 'apache athabascan athabaskan beothuk boethuk cherookee comanche cree delaware gros_ventre hopi illinnois iowa iroquois kiowa mescalero mi_kma_ki natchez navajo northern_paiute osage pawnee pomo potawatomi quapaw shawnee shoshoni teton ute yavapai yokuts t_atsaot_ine plain_bison_hunters calusa copena adena_culture hopewell_culture marksville_culture swift_creek_culture goodall_focus laurel_complex')
_c('andes', 'andean_states_and_chiefdoms aymara_kingdoms chavin chimu_empire huari_empire inca_empire moche nazca paracas tiahuanaco_empire chorrera shuar')
_c('meso', 'aztec_empire maya_chiefdoms_and_states maya_city_states mesoamerican_city_states_and_chiefdoms mixtec_empire monte_alba_n teotihuaca_n toltec_empire zapotec_empire')
_c('carib', 'arawaks taino kalinago guanahatabeyes caribbean_hunter_gatherers essequibo')
_c('latam', 'argentina bolivia brazil kingdom_of_brazil chile colombia costa_rica ecuador el_salvador guatemala guyana haiti honduras mexico nicaragua paraguay peru uruguay venezuela viceroyalty_of_the_ri_o_de_la_plata belize jamaica barbados dominica dominican_republic bahamas saint_lucia trinidad canada united_states united_states_of_america')
_c('oceania', 'm_ori maori samoa tu_i_tonga_empire papous papua_new_guinea papuan')
_c('aborig', 'aboriginal_tasmanians australian_aboriginal_hunter_gatherers iningai kokatha tasmanian_hunter_gatherers warumungu wiradjuri')
_c('arctic', 'arctic_marine_mammal_hunters paleo_inuit chukchi koryaks paleo_siberian_hunter_gatherers siberians sa_mi saami samis subarctic_forest_hunter_gatherers finno_ugric_taiga_hunter_gatherers ainu ainus patagonian_shellfish_and_marine_mammal_hunters antarctica air')
_c('earth', 'amazon_hunter_gatherers andean_hunter_gatherers bell_shaped_burials_culture brushed_pottery_culture desert_hunter_gatherers eastern_masurian_culture eastern_north_amercian_hunter_gatherers iron_age_chieftainships maize_farmers manioc_farmers milograd_culture pampas_cultures plain_pottery_culture plateau_fichers_and_hunter_gatherers pomeranian_culture savanna_hunter_gatherers shellfish_gatherers west_african_cereal_farmers western_masurian_culture minor_states')

ALIAS = {'scottalnd': 'scotland', 'scottland': 'scotland', 'castilla': 'castile', 'castille': 'castile', 'leo_n': 'castile', 'arabia_nejd': 'nejd', 'maskat': 'muscat', 'wadai_empire': 'wadai',
         'han_empire': 'han', 'ainus': 'ainu', 'athabaskan': 'athabascan', 'boethuk': 'beothuk', 'cholas': 'chola', 'saami': 'sa_mi', 'samis': 'sa_mi', 'kanem': 'kanem_bornu', 'bornu_kanem': 'kanem_bornu',
         'khanate_of_the_golden_horde': 'golden_horde', 'parthian_empire': 'parthia', 'kingdom_of_sukhotai': 'sukhothai', 'sultinate_of_zanzibar': 'zanzibar', 'sinhalese_kingdom': 'simhala',
         'sinhalese_kingdoms': 'simhala', 'timurid_emirates': 'timurid_empire', 'united_states_of_america': 'united_states', 'm_ori': 'maori', 'maya_chiefdoms_and_states': 'maya_city_states',
         'minor_hindu_and_buddhist_kingdoms': 'minor_hindu_kingdoms', 'minor_hindu_and_buddhist_states': 'minor_hindu_kingdoms', 'poland_lithuania': 'polish_lithuanian_commonwealth',
         'imperial_japan_fujiwara': 'imperial_japan', 'kingdom_of_georgia': 'georgia', 'swiss_confederation': 'switzerland', 'austria_hungary': 'austrian_empire', 'seljuk_caliphate': 'seljuk_empire',
         'arakan_indian_princely_state': 'arakan', 'burmese_kingdoms': 'burma', 'england_and_ireland': 'england', 'sweden_norway': 'sweden', 'imperial_hungary': 'hungary', 'denmark_norway': 'denmark',
         'laotian_states': 'laos', 'thai': 'sukhothai', 'tuscany': 'tuscany', 'cyprus': 'cyprus', 'principality_of_wallachia': 'principality_of_wallachia', 'mixtec_empire': 'zapotec_empire',
         'mon_khmer': 'mon_state', 'syunik': 'artsakh', 'tashir': 'artsakh', 'celtic_kingdoms': 'celts'}


def classify(nid, name):
    if nid in CULT: return CULT[nid]
    nm = name.lower()
    for kw, cul in (('khanate', 'steppe'), ('horde', 'steppe'), ('caliphate', 'islamic'), ('sultan', 'islamic'), ('emirate', 'islamic'), ('hunter', 'earth'), ('culture', 'earth'), ('kingdom', 'euro'), ('empire', 'euro')):
        if kw in nm: return cul
    return 'euro'


def pick_cols(rng, pal, k=3, first=None):
    pal = list(pal); rng.shuffle(pal)
    c0 = first or pal[0]
    c1 = next((p for p in pal if p != c0 and cr(c0, p) >= 2.2), None) or (WHITE if lum(c0) < .3 else BLACK)
    c2 = next((p for p in pal if p not in (c0, c1) and (cr(c1, p) >= 1.5 or cr(c0, p) >= 1.5)), None) or (GOLD if lum(c0) < .3 else NAVY)
    return [c0, c1, c2]


def charge_col(centre, pal, rng):
    cands = [p for p in pal + [GOLD, WHITE, BLACK] if cr(centre, p) >= 3.6]
    if not cands: cands = [WHITE if lum(centre) < .3 else BLACK]
    return rng.choice(cands[:4]) if rng.random() < .5 else max(cands, key=lambda p: cr(centre, p) if p not in (WHITE, BLACK) else cr(centre, p) - 2)


def seed_of(s): return random.Random(int(hashlib.md5(s.encode()).hexdigest(), 16))


# ---------------------------------------------------------------- procedural emblems that are unique per nation
def tamga(rng, f):
    """a steppe clan mark: 2-3 strokes picked from a kit, so every khanate gets its own"""
    d = []; k = rng.randrange(8)
    if k == 0: d += ['M0 -.9V.9', 'M-.55 -.55Q-.55 .1 0 .1Q.55 .1 .55 -.55']                              # trident / lyre
    elif k == 1: d += ['M-.5 -.9Q.9 0 -.5 .9', 'M-.9 0H.9']                                            # bow and arrow
    elif k == 2: d += ['M0 -.9V.9', 'M-.6 -.3H.6', 'M-.45 .45H.45']                                    # ladder
    elif k == 3: d += ['M-.7 .8L0 -.8L.7 .8', 'M-.4 .2H.4']                                           # peak
    elif k == 4: d += ['M-.8 -.7C-.1 -.7 -.1 .0 -.8 .0', 'M.8 .7C.1 .7 .1 .0 .8 .0', 'M-.8 .0H.8']      # S hooks
    elif k == 5: d += ['M0 .9V-.2', 'M0 -.2L-.6 -.8', 'M0 -.2L.6 -.8', 'M-.5 .5H.5']                   # fork
    elif k == 6: d += ['M-.8 -.8L.8 .8', 'M.8 -.8L-.8 .8', 'M0 -.9V.9']                                 # star of strokes
    else: d += ['M-.7 -.5H.7', 'M-.7 .5H.7', 'M0 -.5V.5', 'M-.7 -.5V-.9M.7 -.5V-.9']                    # gate
    out = ''.join(line(x, f, .17) for x in d)
    extra = rng.randrange(4)
    if extra == 0: out += circ(0, -.95, .13, f)
    elif extra == 1: out += circ(0, 0, .26, 'none', f'stroke="{f}" stroke-width=".13"')
    elif extra == 2: out += circ(-.75, .8, .1, f) + circ(.75, .8, .1, f)
    return out


def maya_glyph(rng, f, a):
    v = rng.randrange(2, 19); bars, dots = v // 5, v % 5
    out = rect(-.92, -.92, 1.84, 1.84, 'none', f'rx=".32" stroke="{f}" stroke-width=".13"')
    y = -.55
    if dots: out += ''.join(circ((i - (dots - 1) / 2) * .42, y, .15, f) for i in range(dots)); y += .38
    for _ in range(bars): out += rect(-.55, y - .08, 1.1, .2, f, 'rx=".09"'); y += .3
    for sx in (-1, 1): out += circ(sx * .65, .68, .1, f)
    return out + line('M-.5 .72Q0 .95 .5 .72', f, .08) 


def weave_band(y, h, c1, c2, rng, kind=None):
    kind = kind or rng.choice(['zig', 'dia', 'step', 'tri'])
    k = 15; w = W / k; out = ''
    if kind == 'zig':
        out += path('M0 %s' % (y + h) + ''.join(f'L{i * w + w / 2} {y}L{(i + 1) * w} {y + h}' for i in range(k)) + 'Z', c1)
    elif kind == 'dia':
        out += ''.join(poly([(i * w + w / 2, y), (i * w + w, y + h / 2), (i * w + w / 2, y + h), (i * w, y + h / 2)], c1) for i in range(k))
        out += ''.join(circ(i * w + w / 2, y + h / 2, h * .09, c2) for i in range(k))
    elif kind == 'step':
        for i in range(k):
            x = i * w
            out += rect(x, y + h * .66, w, h * .34, c1) + rect(x + w * .17, y + h * .33, w * .66, h * .34, c1) + rect(x + w * .33, y, w * .34, h * .33, c1)
    else:
        out += ''.join(poly([(i * w, y), (i * w + w, y), (i * w + w / 2, y + h)], c1 if i % 2 == 0 else c2) for i in range(k))
    return out


def wiphala(rng):
    cols = ['#d52b1e', '#f39c12', '#f6d633', '#ffffff', '#3aa655', '#2f6fd1', '#7e3fa8']
    out = ''; s = 300 / 7
    for j in range(7):
        for i in range(7):
            out += rect(i * s, j * 200 / 7, s + .5, 200 / 7 + .5, cols[(i + j) % 7])
    out += ''.join(poly([(i * s, (j + 1) * 200 / 7), ((i + 1) * s, j * 200 / 7), ((i + 1) * s, (j + 1) * 200 / 7)], cols[(i + j + 3) % 7], 'opacity=".0"') for i in range(0) for j in range(0))
    return out


def wampum(c):
    out = rect(0, 0, W, H, c[0]) + rect(0, 0, W, 14, c[1]) + rect(0, H - 14, W, 14, c[1])
    out += poly([(100, 68), (150, 40), (200, 68), (200, 132), (150, 160), (100, 132)], c[1], 'opacity="0"')
    # tree of peace between two squares
    out += rect(104, 44, 92, 112, c[1]) + rect(112, 52, 76, 96, c[0]) 
    out += rect(138, 84, 24, 64, c[1]) + poly([(150, 52), (176, 92), (124, 92)], c[1])
    for x in (30, 70, 230, 270): out += poly([(x, 100 - 22), (x + 22, 100), (x, 100 + 22), (x - 22, 100)], c[1])
    return out


def compose(nid, name, eras=None):
    nid_d = ALIAS.get(nid, nid)
    rng = seed_of(nid_d + '|flag-v1')
    cul = classify(nid_d, name)
    uid = hashlib.md5(nid_d.encode()).hexdigest()[:6]
    body = ''; centre = None
    pal = PAL.get({'meso': 'andes', 'carib': 'native'}.get(cul, cul), PAL['euro'])
    cx, cy = 150, 100
    chg = None; ch_r = 56; med = None; edge_kind = None; ccol = None

    def fld(kind, cols):
        return FIELDS[kind](cols, rng)

    # --------- per culture field + charge families
    if cul == 'euro':
        fk = rng.choice(['h2', 'h3', 'v3', 'cross', 'nordic', 'saltire', 'quarter', 'canton', 'chief', 'pale', 'fesse', 'checky', 'diag', 'chevron', 'border', 'lozenge', 'semy', 'bend_fim'])
        cols = pick_cols(rng, pal)
        if fk == 'semy': body, ctr = f_semy(cols, rng, rng.choice(['fleur', 'star', 'cross_patee', 'rose']))
        else: body, ctr = fld(fk, cols)
        chg = rng.choice(['eagle', 'eagle2', 'crown', 'tower', 'swords', 'lion_head', 'winged_lion', 'shield', 'cross_patee', 'star', 'rose', 'key', 'axe', 'anchor', 'fleur', 'cross_jerusalem'])
        if has(name, 'republic', 'commonwealth', 'confederation', 'union'): chg = rng.choice(['star', 'stars_ring', 'rings', 'tower', 'key', 'cross_ring'])
        if has(name, 'kingdom', 'empire', 'holy', 'grand duchy', 'principality', 'duchy', 'tsardom'): chg = rng.choice(['crown', 'eagle', 'eagle2', 'lion_head', 'shield'])
        if has(name, 'knights', 'papal'): chg = rng.choice(['cross_patee', 'key', 'swords'])
        if has(name, 'norse', 'iceland', 'kalmar', 'denmark', 'norway', 'sweden'): chg = rng.choice(['longship', 'valknut', 'wolf'])
        edge_kind = rng.choice([None, 'inline', 'double', 'inline'])
    elif cul == 'islamic':
        fk = rng.choice(['h3', 'v3', 'h2', 'triangle', 'chevron', 'border', 'quarter', 'diamonds', 'pale', 'stripes_fim', 'solid', 'sunburst'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['crescent_star', 'star8', 'crescent', 'mosque', 'swords', 'sun', 'star', 'key', 'tower'])
        if has(name, 'city'): chg = rng.choice(['mosque', 'tower', 'key'])
        edge_kind = rng.choice([None, 'inline', 'dots', 'double'])
    elif cul == 'steppe':
        fk = rng.choice(['solid', 'h2', 'v3', 'h3', 'border', 'bend', 'fesse', 'pale', 'chief', 'sunburst', 'quarter'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['tamga', 'tamga', 'tamga', 'horsetail', 'wolf', 'stag', 'bow', 'crescent', 'sun', 'bull'])
        edge_kind = rng.choice([None, 'tri', 'inline'])
    elif cul == 'east':
        fk = rng.choice(['solid', 'h2', 'border', 'bend', 'lozenge', 'v3', 'pale', 'chief', 'sunburst'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['dragon', 'mon', 'tomoe', 'sun', 'cloud' if False else 'wheel', 'swords', 'tower', 'star', 'lotus', 'crane' if False else 'mountains', 'wave_sun'])
        edge_kind = rng.choice([None, 'inline', 'hem'])
    elif cul == 'sea':
        fk = rng.choice(['h3', 'h2', 'chevron', 'triangle', 'h121', 'stripes_fim', 'border', 'v3', 'quarter', 'wave_bands'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['lotus', 'wheel', 'tower', 'ship', 'sun', 'star', 'crescent_star', 'serpent', 'palm', 'mountains', 'wave_sun', 'dragon', 'bull', 'angkor'])
        edge_kind = rng.choice([None, 'inline', 'dots'])
    elif cul == 'india':
        fk = rng.choice(['h3', 'h2', 'v3', 'solid', 'border', 'triangle', 'canton', 'sunburst', 'checky', 'chief'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['wheel', 'lotus', 'sun', 'sun_face', 'trident', 'bull', 'swords', 'tower', 'star8', 'tree', 'cross_ring', 'lion_head'])
        edge_kind = rng.choice([None, 'dots', 'inline', 'tri'])
    elif cul == 'africa':
        fk = rng.choice(['h3', 'v3', 'h2', 'pale', 'triangle', 'zigzag', 'quarter', 'stripes_fim', 'solid', 'chevron', 'sunburst', 'pall'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['spears_shield', 'spears_shield', 'sun', 'star', 'stool', 'mud_mosque', 'bow', 'tree', 'drum', 'crescent_star', 'stele', 'lion_head', 'wheat', 'bird'])
        edge_kind = rng.choice([None, 'tri', 'dots', 'inline'])
    elif cul in ('native',):
        fk = rng.choice(['solid', 'h3', 'zigzag', 'stepped', 'fret_band', 'quarter', 'sunburst', 'stripes_fim', 'diamonds', 'v3'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['medicine_wheel', 'thunderbird', 'turtle', 'paw', 'feathers', 'arrows_cross', 'sun_half', 'stair_diamond', 'sun', 'wolf', 'bow', 'feather_crown', 'bull'])
        edge_kind = rng.choice([None, 'tri', 'dots'])
    elif cul in ('andes', 'meso'):
        fk = rng.choice(['zigzag', 'stepped', 'fret_band', 'diamonds', 'h3', 'solid', 'quarter4', 'sunburst', 'checky'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['chakana', 'sun_face', 'serpent', 'stair_diamond', 'pyramid', 'puma' if False else 'wolf', 'bull', 'thunderbird', 'sun', 'maya'] if cul == 'meso' else ['chakana', 'sun_face', 'serpent', 'stair_diamond', 'fish', 'thunderbird', 'turtle', 'sun', 'pyramid'])
        edge_kind = rng.choice([None, 'tri', 'dots'])
    elif cul == 'carib':
        fk = rng.choice(['wavy', 'wave_bands', 'h3', 'sunburst', 'diag', 'solid'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['sun', 'spiral', 'palm', 'fish', 'turtle', 'paw', 'longship', 'concentric'])
    elif cul == 'latam':
        fk = rng.choice(['h3', 'h3', 'h2', 'v3', 'h121', 'triangle', 'chevron', 'canton', 'sunburst', 'h5'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['star', 'sun', 'tree', 'mountains', 'palm', 'cross_greek', 'shield', 'star', 'tower', 'stars_ring'])
    elif cul == 'oceania':
        fk = rng.choice(['h3', 'wave_bands', 'wavy', 'fret_band', 'h2', 'solid', 'zigzag', 'quarter'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['koru', 'star_cluster', 'turtle', 'spiral', 'sun_half', 'fish', 'longship', 'stars_ring', 'trident', 'wave_sun'])
        edge_kind = rng.choice([None, 'tri'])
    elif cul == 'aborig':
        fk = rng.choice(['h3', 'stripes_fim', 'solid', 'h121', 'quarter', 'stepped', 'fesse'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['concentric', 'dots_ring', 'boomerang', 'sun', 'concentric', 'spiral', 'dots_ring'])
        edge_kind = rng.choice([None, 'dots'])
    elif cul == 'arctic':
        fk = rng.choice(['aurora', 'dusk', 'h2', 'solid', 'v3', 'wavy', 'chief', 'cross'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['inuksuk', 'whale', 'stag', 'sun_half', 'paw', 'drum', 'fish', 'star', 'feather'])
        if has(name, 'ainu'): chg = rng.choice(['spiral', 'bear' if False else 'paw', 'mon'])
        if has(name, 'sami', 'sámi', 'saami'): chg = 'drum'
        edge_kind = rng.choice([None, 'inline', 'tri'])
    elif cul == 'earth':
        fk = rng.choice(['solid', 'h3', 'zigzag', 'stepped', 'fret_band', 'stripes_fim', 'diamonds', 'v3', 'quarter', 'border'])
        cols = pick_cols(rng, pal); body, ctr = fld(fk, cols)
        chg = rng.choice(['pot', 'beaker', 'hand', 'mound', 'earthwork', 'axe', 'spears_shield', 'stag', 'fish', 'wheat', 'bow', 'sun', 'tree', 'feathers'])
        if has(name, 'hunter', 'gatherer'): chg = rng.choice(['hand', 'bow', 'fish', 'stag', 'paw', 'feather', 'spears_shield'])
        if has(name, 'farmer', 'cereal'): chg = rng.choice(['wheat', 'tree', 'sun'])
        if has(name, 'pottery'): chg = 'pot'
        if has(name, 'bell'): chg = 'beaker'
        edge_kind = rng.choice([None, 'tri', 'dots'])
    else:
        fk = 'h3'; cols = pick_cols(rng, pal); body, ctr = fld(fk, cols); chg = 'star'

    forced_cc = forced_med = None
    if nid_d in FORCE: chg = FORCE[nid_d]
    sp = SPECIAL.get(nid_d)
    if sp:
        fk, cols, chg, forced_cc, forced_med, edge_kind = sp
        cols = list(cols)
        body, ctr = f_semy(cols, rng, SEMY_CHARGE[nid_d]) if fk == 'semy' else FIELDS[fk](cols, rng)
        if edge_kind == 'knotband': edge_kind = 'dots'
    # --------- the cultural signatures that beat the dice
    if nid_d == 'inca_empire' or (cul == 'andes' and has(name, 'inca')): body, ctr, chg = wiphala(rng), WHITE, None
    if nid_d == 'iroquois': body, ctr, chg, cols = wampum([PURP, WHITE]), PURP, None, [PURP, WHITE, PURP]
    # --------- medallion so the charge is always readable
    pool = pal
    if chg:
        if chg in ('maya', 'tamga'): pass
        under = {'solid': [0], 'border': [0], 'lozenge': [1], 'pale': [1], 'fesse': [1], 'sunburst': [0, 1], 'h121': [1], 'wavy': [0, 1], 'wave_bands': [0, 1],
                 'aurora': [0, 1], 'dusk': [1], 'cross': [1], 'nordic': [0, 1], 'saltire': [0, 1], 'semy': [0], 'stepped': [1], 'fret_band': [0, 1], 'zigzag': [0, 1]}.get(fk, [0, 1, 2])
        ucols = [cols[i] for i in under if i < len(cols)]
        good = [c for c in pool + [GOLD, WHITE, BLACK, YEL] if c not in ucols and min(cr(c, u) for u in ucols) >= 2.6]
        ccol = forced_cc or (rng.choice(good[:6]) if good else charge_col(ctr, pool, rng))
        want_med = (not good and not forced_cc) or (fk in ('quarter', 'quarter4', 'diag', 'diag2', 'checky', 'diamonds', 'gyronny', 'triangle', 'chevron', 'bend', 'bend_fim', 'canton', 'chief', 'semy') and rng.random() < .6)
        if forced_med:
            cand = [c for c in cols + [BLACK, NAVY, dark(cols[0], .4), WHITE] if cr(c, ccol) >= 3.5 and cr(c, ctr) >= 1.25]
            mbg = cand[0] if cand else (BLACK if lum(ccol) > .3 else WHITE)
            med = medallion(forced_med, mbg, ccol, cx, cy, 70); ctr = mbg
        elif want_med:
            mk = rng.choice(['disc', 'ring', 'shield', 'lozenge', 'octa'])
            mbg = rng.choice([c for c in (cols[0], cols[1], dark(cols[0], .25), WHITE if lum(cols[0]) < .5 else BLACK)])
            ccol = max([GOLD, WHITE, BLACK, cols[1], cols[2], cols[0], YEL, SKY], key=lambda p: cr(mbg, p) if p != mbg else 0)
            if cr(mbg, ccol) < 3.2: mbg = BLACK if lum(ccol) > .4 else WHITE
            med = medallion(mk, mbg, ccol if rng.random() < .6 else GOLD if cr(mbg, GOLD) > 3 else ccol, cx, cy, 70)
            ctr = mbg
        acc = body and (cols[0] if cr(ccol, cols[0]) > 1.6 else (BLACK if lum(ccol) > .3 else WHITE))
        if chg == 'tamga': frag = tamga(rng, ccol); sc = 54
        elif chg == 'maya': frag = maya_glyph(rng, ccol, acc); sc = 58
        else: frag = CH[chg](ccol, acc); sc = ch_r
        if chg in ('longship', 'ship', 'mountains', 'waves', 'wave_sun', 'sun_half', 'earthwork', 'eagle', 'eagle2', 'winged_lion'): sc = 64
        if chg in ('bow', 'dragon', 'serpent', 'trident', 'anchor', 'palm', 'key', 'horsetail', 'stele', 'tree', 'arrow', 'arrows_cross', 'stag', 'feather', 'feathers', 'spiral', 'koru', 'inuksuk', 'whale', 'wheat'): sc = 70
        body += (med or '') + grp(frag, cx, cy, sc)
    if edge_kind:
        rim = cols[1] if cr(cols[0], cols[1]) > 1.8 else GOLD
        body += edge(edge_kind, cols, rim, 0)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}"><g>{body}</g>{cloth(uid)}</svg>'), dict(culture=cul, field=fk, charge=chg)


def all_nations():
    names = {}; eras = {}
    d = os.path.join(ROOT, 'godot/data/eras')
    for f in sorted(os.listdir(d)):
        if not f.endswith('.json'): continue
        e = json.load(open(os.path.join(d, f)))
        for nn in e['nations']:
            names.setdefault(nn['id'], nn['name']); eras.setdefault(nn['id'], []).append(e['id'])
    return names, eras


def needed_ids():
    """nations that show an authored flag in at least one era: map entry without a Commons file in flags/src"""
    slug = lambda t: re.sub(r'^_|_$', '', re.sub(r'[^A-Za-z0-9]+', '_', t[:-4])).lower()
    need = set(); here = os.path.join(ROOT, 'tools/flags')
    for f in os.listdir(here):
        if not f.endswith('_map.json'): continue
        for nat, v in json.load(open(os.path.join(here, f))).items():
            t = v.get('title') if isinstance(v, dict) else None
            if not (t and os.path.exists(os.path.join(ROOT, 'flags/src', slug(t) + '.svg'))): need.add(nat)
    return need


if __name__ == '__main__':
    names, eras = all_nations()
    ids = sys.argv[1:] or sorted(needed_ids())
    out = os.path.join(ROOT, 'flags/authored')
    sig = {}
    for i in ids:
        svg, info = compose(i, names.get(i, i.replace('_', ' ').title()))
        open(os.path.join(out, i + '.svg'), 'w').write(svg)
        sig.setdefault(hashlib.md5(svg.encode()).hexdigest(), []).append(i)
    json.dump(names, open(os.path.join(ROOT, 'tools/flags/names.json'), 'w'), ensure_ascii=False)     # id -> name, read by sheet.mjs
    dup = [v for v in sig.values() if len(v) > 1]
    print('wrote', len(ids), 'flags;', len(dup), 'identical groups', dup[:8])
