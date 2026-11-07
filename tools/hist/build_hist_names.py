#!/usr/bin/env python3
"""Builds godot/data/hist_names.json (province id -> {era code: english name}) and godot/data/i18n/hist_ru.json / hist_uz.json (english name -> localised name)
from the tables in part*.py, and checks them: every province must exist, scripts must not be mixed, one english name has one translation.
Run from tools/hist:  python3 build_hist_names.py"""
import glob, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common
for f in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "part*.py"))):
    exec(open(f, encoding="utf-8").read(), {"__name__": "part"} | {k: getattr(common, k) for k in dir(common) if not k.startswith("_")})
root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "godot"))
w = json.load(open(os.path.join(root, "data", "world.json"), encoding="utf-8"))
by = {}
for i, (pid, nm) in enumerate(zip(w["id"], w["name"])):
    by.setdefault((pid.split("_")[0], nm), []).append(pid)
LAT = re.compile(r"^[A-Za-zÀ-ÿĀ-ž‘’'’ʻʼ0-9 ()\-.,/&]+$")
CYR = re.compile(r"^[А-Яа-яЁё0-9 ()\-.,/&’']+$")
out = {}; ru = {}; uz = {}; bad = 0; miss = set()
for cc, modern, codes, en, r, u in common.RULES:
    if not en: continue
    ids = by.get((cc, modern))
    if not ids:
        miss.add((cc, modern)); continue
    if not LAT.match(en): print("BAD en:", cc, modern, en); bad += 1
    if not CYR.match(r): print("BAD ru:", cc, modern, r); bad += 1
    if not LAT.match(u): print("BAD uz:", cc, modern, u); bad += 1
    for pid in ids:
        d = out.setdefault(pid, {})
        for c in codes:
            if c in d and d[c] != en: print("note: later rule wins for", pid, c, ":", d[c], "->", en)
            d[c] = en
    for table, val, lang in ((ru, r, "ru"), (uz, u, "uz")):
        if en in table and table[en] != val: print("TRANSLATION CONFLICT", lang, en, table[en], val); bad += 1
        table[en] = val
if miss: print("NO SUCH PROVINCE:", sorted(miss)); bad += len(miss)
json.dump(out, open(os.path.join(root, "data", "hist_names.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"), sort_keys=True)
json.dump(ru, open(os.path.join(root, "data", "i18n", "hist_ru.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"), sort_keys=True)
json.dump(uz, open(os.path.join(root, "data", "i18n", "hist_uz.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"), sort_keys=True)
print("provinces with historical names:", len(out), "rules:", len(common.RULES), "names:", len(ru), "problems:", bad)
sys.exit(1 if bad else 0)
