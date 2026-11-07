#!/usr/bin/env python3
"""Rewrites the table list of godot/tests/const_race.gd from the engine sources (every top-level Array / Dictionary table of a class_name script)."""
import re, glob, os
root = os.path.join(os.path.dirname(__file__), '..', 'godot')
refs = []
for f in sorted(glob.glob(os.path.join(root, 'src/engine/**/*.gd'), recursive=True)):
    s = open(f).read()
    m = re.search(r'^class_name (\w+)', s, re.M)
    if not m: continue
    for c in re.finditer(r'^(?:const|static var) ([A-Z][A-Z0-9_]*)\s*(?::=|:\s*(?:Array|Dictionary)[^=\n]*=)\s*([\[{])', s, re.M):
        refs.append((m.group(1), c.group(1)))
p = os.path.join(root, 'tests/const_race.gd')
t = open(p).read()
body = "\n".join("\t_touch(%s.%s)" % r for r in refs)
snap = "\n".join("\tout.append(str(%s.%s).hash())" % r for r in refs)
t = re.sub(r'(func _all\(\) -> void:\n).*?(\nfunc _snap)', lambda m: m.group(1) + body + m.group(2), t, flags=re.S)
t = re.sub(r'(var out: Array = \[\]\n).*?(\n\treturn out)', lambda m: m.group(1) + snap + m.group(2), t, flags=re.S)
t = re.sub(r'(func _one\(\) -> void:\n\tmatch only:\n).*?(\t\t_: _all\(\))', lambda m: m.group(1) + "".join("\t\t%d: _touch(%s.%s)\n" % (i, a, b) for i, (a, b) in enumerate(refs)) + m.group(2), t, flags=re.S)
open(p, 'w').write(t)
print(len(refs), "tables")
