#!/usr/bin/env python3
"""Adds translation keys to godot/data/i18n/{en,ru,uz}.json. Usage: python3 tools/add_i18n.py <<< '{"key": ["English", "Русский", "O'zbekcha"]}'  (existing keys are overwritten)."""
import json, sys, os
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot', 'data', 'i18n')
add = json.load(sys.stdin)
for i, lang in enumerate(['en', 'ru', 'uz']):
    p = os.path.join(root, lang + '.json')
    d = json.load(open(p))
    for k, v in add.items(): d[k] = v[i]
    json.dump(d, open(p, 'w'), ensure_ascii=False, separators=(',', ':'))
print('added', len(add), 'keys')
