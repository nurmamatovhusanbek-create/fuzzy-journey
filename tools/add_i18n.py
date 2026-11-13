#!/usr/bin/env python3
"""Adds translation keys to godot/data/i18n/{en,ru,uz}.json. Usage: python3 tools/add_i18n.py <<< '{"key": ["English", "Русский", "O'zbekcha"]}'  (existing keys are overwritten)."""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot', 'data', 'i18n')
add = json.load(sys.stdin)
def _uz(v):
    out = []
    for i, ch in enumerate(v):
        if ch in "'\u2018\u2019`\u00b4\u02bb\u02bc":
            pre = v[i - 1] if i > 0 else ''
            out.append('\u02bb' if (pre.lower() in ('o', 'g') and pre.isalpha()) else '\u02bc')
        else: out.append(ch)
    return ''.join(out)
for i, lang in enumerate(['en', 'ru', 'uz']):
    p = os.path.join(root, lang + '.json')
    d = json.load(open(p))
    for k, v in add.items(): d[k] = _uz(v[i]) if lang == 'uz' else v[i]          # Uzbek apostrophes: oʻ gʻ = U+02BB, tutuq belgisi = U+02BC (tools/uz_normalize.py)
    json.dump(d, open(p, 'w'), ensure_ascii=False, separators=(',', ':'))
print('added', len(add), 'keys')
