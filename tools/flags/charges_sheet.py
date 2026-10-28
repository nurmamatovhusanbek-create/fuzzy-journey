"""python3 tools/flags/charges_sheet.py out.html : every charge on a dark and a light tile (review aid)"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import author as A
cells = ''
for k, fn in sorted(A.CH.items()):
    try: g = A.grp(fn(A.GOLD, A.BLACK), 60, 60, 46)
    except Exception as e: g = f'<text x="10" y="60" fill="red" font-size="9">{e}</text>'
    try: g2 = A.grp(fn(A.BLACK, A.WHITE), 60, 60, 46)
    except Exception: g2 = ''
    cells += f'<div class=c><svg viewBox="0 0 120 120" width="120"><rect width="120" height="120" fill="#2a3550"/>{g}</svg><svg viewBox="0 0 120 120" width="120"><rect width="120" height="120" fill="#ddd2b8"/>{g2}</svg><span>{k}</span></div>'
open(sys.argv[1], 'w').write(f'<style>body{{margin:0;background:#111;color:#aaa;font:11px sans-serif}}.g{{display:flex;flex-wrap:wrap;gap:8px;padding:8px}}.c{{display:flex;flex-direction:column;align-items:center}}</style><div class=g>{cells}</div>')
