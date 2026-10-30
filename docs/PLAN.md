# Plan: what has the most impact now, why, and how each item is checked

Written 2026-10-30 after a round of playtests, profiling, sims and screenshot sweeps (`docs/PLAYTEST.md`, `docs/MODEL.md` section 9).
Rule for every item: **evidence, then decision, then work, then proof** (engine suite, UI suite, screenshots read by eye), then commit. Between items: an overflow / alignment / error check on the screens the item touched.

## What the research found

| Area | Evidence | Verdict |
|---|---|---|
| Rules 3 logic (alliances, trade, endings, terrain) | 39-game AI sims, 5 playtests: no errors, no `can()`/`apply()` mismatches, worlds stay lively (20 to 40 % of nations change size in 100 turns) | Done. Keep the sims as a gate. |
| Speed | AI turn 116 ms to 45 to 70 ms, income loop 31 to 22 ms, whole turn 44 to 80 ms in most eras (phone about 3 to 4 times that, on a worker thread) | Done. Native core only if a real phone shows the need. |
| Translations | 1601 keys in en / ru / uz, none missing, only 12 identical to English in uz (loanwords, proper nouns) | Complete. No work. |
| High contrast "light" mode | User report plus reproduction: event dialog, province card, war face-off, goals, nation list had ivory or pale gold text on cream paper; HUD words unreadable over a pale map | Fixed on the dialogs checked; **not yet swept on every screen** (item 1). |
| Ruler names | One global pool of 52 names (`rn_0..51`) for every nation without a historical ruler: "President Hiroshi III" governs Russia, "President Akbar II" too | Visible, cheap, safe to fix (item 2). |
| Content depth per era | Scheduled historical events per era: 8 (modern), 12 to 15 (all others); 25 random events and 7 global ones | Modern era is the thinnest (item 3). |
| Capitals in the modern world | Found while testing item 2: modern nations use ISO codes (AFG, RUS...) and `data/capitals.json` was keyed by era ids, so no modern nation had its real capital (China: Tibet, France: Ariège, Russia: Karelia) | **Fixed** (197 ISO entries, reach 1300 km, test). |
| Release path | itch.io (Windows + Android APK) is ready. Google Play needs target API 35, 16 KB page alignment and AAB, which Godot 4.4.1 cannot produce; Godot 4.5 can. GitHub release downloads are reachable from here | Trial the upgrade on this machine without changing the project (item 4). |
| First minutes of play | Tutorial and "How to play" exist; never reviewed on screen at phone size since the HUD and dialog redesigns | Review (item 5). |

## The items, in order

1. **High contrast light and dark on every screen.** Extend `tests/light_shots.gd` from 12 to about 25 screens (title, nation pick, menu tabs, toasts and alerts, tooltips, battle report, game over, hot seat, trade and ally negotiation, province dossier, build picker). Fix each wrong colour pair at its source (`TBTokens.ink_for`, `paper_or`, surfaces) and keep the check in the UI suite. Done when: zero `LOW CONTRAST`, every screenshot read by eye in light, dark and normal.
2. **Ruler names that fit the land.** Name spheres (Western Europe, Slavic, Greek-Balkan, Arab, Turkic-Persian, Indian, Chinese, Japanese-Korean, South-East Asian, African, Latin America) chosen from the capital's position and the era; about 60 new names with ru and uz forms; indices stay stable (`rn:idx`) so old saves load. Done when: a test shows Russia, Egypt, India, Japan and Brazil draw from their own spheres and a 100-turn game never gives a European throne a Japanese name.
3. **Modern era content.** Six to eight new scheduled events for 2024 onwards (energy crisis, semiconductor shortage, cyber attack, climate summit, migration wave, AI treaty, pandemic echo, sanctions) written without real persons, in en / ru / uz, with real effects through the existing event engine. Done when: the era has 14 or more scheduled events, `tests/events*` and `audit_links.py` pass, and a playtest shows them firing without errors.
4. **Godot 4.5 trial (Google Play path). BLOCKED: running the downloaded editor was refused by the permission system; needs the owner's permission.** Download the 4.5 editor, import the project in a copy, run the engine suite and the UI suite on it, compare screenshots, write what changed. The project file stays on 4.4.1 until the owner decides, because the Android build template and export templates must move together. Done when: a written report (`docs/GODOT45.md`) says pass or fail with the list of differences.
5. **First minutes review.** Play turns 1 to 5 with the tutorial on at phone size and desktop size; fix overlaps, dead ends and unreadable hints. Done when: the tutorial path has screenshots without overflow at 2340 x 1080 (S22), 1920 x 1080 and 1280 x 720.
6. **Notes and version.** Update `docs/RELEASE.md` and the changelog with everything since 1.0.0 (rules 3, alliances, terrain, light mode, ring, sinks); propose, not apply, version 1.1.0 / code 3.

## What is deliberately not in the plan

* A Rust rewrite (no speed problem; the UI is the expensive part). Revisit only with phone measurements.
* Real current heads of state in the modern era (a legal and taste risk; fictional rulers with fitting names instead).
* Multiplayer, until the owner turns it on.
