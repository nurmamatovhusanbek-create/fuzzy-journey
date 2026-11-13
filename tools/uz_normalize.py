"""Uzbek (Latin) apostrophes, one way: oʻ and gʻ use U+02BB, the tutuq belgisi (maʼno, eʼlon, qalʼa) uses U+02BC. Any of ' ‘ ’ ` ´ ʻ ʼ in godot/data/i18n/uz.json is rewritten by that rule.
Usage: python3 tools/uz_normalize.py [--check]   (--check only reports; exit 1 when something would change)"""
import json, re, sys
P = 'godot/data/i18n/uz.json'
Q = "'‘’`´ʻʼ"
def fix(v: str) -> str:
    out = []
    for i, ch in enumerate(v):
        if ch in Q:
            pre = v[i - 1] if i > 0 else ''
            out.append('ʻ' if (pre.lower() in ('o', 'g') and pre.isalpha()) else 'ʼ')
        else: out.append(ch)
    return ''.join(out)
d = json.load(open(P, encoding='utf-8'))
chg = {k: fix(v) for k, v in d.items() if fix(v) != v}
print(len(chg), 'strings change')
if '--check' in sys.argv: sys.exit(1 if chg else 0)
for k, v in chg.items(): d[k] = v
raw = open(P, encoding='utf-8').read()
json.dump(d, open(P, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
