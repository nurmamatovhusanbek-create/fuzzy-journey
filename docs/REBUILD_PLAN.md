# Terra Bellum — Rebuild Plan (Godot 4)

## Decisions (confirmed with the owner)
1. **Leave HTML entirely → Godot 4.4 (Compatibility/GLES3 renderer), GDScript.** Targets: Android (low-end first), Windows, iOS. (Godot 4 C# cannot export to iOS, so GDScript.)
2. **One unified province engine.** v1 "country mode" disappears; a country is a nation owning provinces. v2 had *no* AI wars — the rebuild adds them.
3. **GPU map:** province-ID texture + palette texture + one fragment shader (globe/flat, borders, lenses). An ownership change = update a 1,788-pixel palette, never a repaint.
4. **Multiplayer: host-authoritative with delta snapshots** (Godot high-level multiplayer: ENet native / WebSocket). Not lockstep — floating-point `sin/asin` differ across ARM/x86, which would desync. Per-turn payload = changed provinces + nation table (a few KB) instead of the whole state.
5. **Chunked code**: strict layers with enforced dependency rules (see `docs/ARCHITECTURE.md`).

## Status (kept current)
| Area | State |
|---|---|
| Engine (GDScript; bit-exact vs JS oracle at `rules=0`, tuned game at `rules=1`) | done, tested (`tools/test_all.sh`) |
| GPU map: globe/flat, smoothed province IDs, borders, 10 lenses, selection, move-target highlight, occupation hatch, nation names, 3 quality tiers + render scale + **adaptive auto quality**, parchment theme | done |
| Single-player UI: menu, eras, nation pick, HUD, province panel, nation card (war score, diplomacy, covert ops), budget, goals, save/load, tutorial, game-over standings, flags, EN/RU, portrait + safe-area | done |
| Systems: economy, buildings, tech/eras, combat, war score, peace deals (white / land / **vassal**), NAP/alliance, rebels, colonization, mercenaries, **events** (12 random + 14 scheduled packs), **covert ops**, **5 victory paths**, AI (personalities, budget mgmt, spies, anti-hegemon) | done |
| Multiplayer: authoritative server (**deployed on Render**), lobby, delta sync, proposals, chat, turn timer, **auto-reconnect**, command validation + rate limit | done; tested with 2 clients + UI + reconnect |
| Perf work: bake-time sea links (new game 289 ms to 11 ms), render only on change + low-processor mode, half-res ID texture on Low tier | done |
| Android / iOS builds | presets + CI workflow written, **not run** (no Android SDK / Mac in the dev sandbox) |
| UX: **Chronicle** (filterable history), **Advisor** (alerts + tips, crisis toasts), richer log (occupation, annexation, bankruptcy, era) — from `docs/RESEARCH.md` item 1 | done |
| **Rulers** (item 2): named leaders with skills + traits, ageing, succession / crises / elections, ~140 historical rulers across 11 eras (`data/rulers.json`), era-appropriate starting governments (`engine/regimes.gd`) | done |
| **Casus belli, infamy, coalitions** (item 3): 5 casus belli (coalition / reclaim / revenge / defend ally / rebels), infamy from unjustified wars + conquest, coalition at 22 (ends at 12), AI weighs infamy + CB, shown on nation card, advisor and chronicle | done |
| **Decisions** (item 4): 8 national decisions (timed / permanent / instant), AI uses them as a gold sink, MP-safe command | done |
| Still to port from legacy | trade routes, generals, formable nations, ultimatums / war goals / marriage UI, data-spike lens, localized nation names |
| Perf on real low-end hardware | **unmeasured** — needs a physical phone |

Legacy `index.html` stays untouched until feature parity. The JS engine written earlier is kept in `reference/engine-js` as a **test oracle** for the GDScript port (same seed ⇒ comparable results).

## Why the old game lagged (measured from its code)
| Problem | Effect |
|---|---|
| 1.5 MB single file / 19.7k lines; d3 + topojson parsed on load | slow start, GC |
| `d3.geoPath` re-projects ~1,800 polygons (34k arcs) every frame; shadowBlur, gradients | main lag source |
| Click = `d3.geoContains` over every province | slow taps |
| State = nested objects with string ids; `Object.keys` scans each turn | GC churn |
| MP host `JSON.stringify`s the whole state (incl. geometry) every turn | multi-MB per turn |
| Sim + AI + render on one thread | end-turn freeze |
| v1 and v2 engines side by side (`if (S.v2)`) | duplicate code, v2 AI missing |

Prototype measurement (CPU per-pixel globe in a browser): 40–65 ms/frame — i.e. the CPU should not draw the globe at all. A fragment shader does it for ~free.

## Architecture (see docs/ARCHITECTURE.md)
```
tools/bake.mjs          topojson + era json  -> godot/data/*  (build-time, Node)
godot/
  project.godot  export_presets.cfg
  data/                 world.json, ids.bin.gz (u16 ID raster), eras/*.json
  src/
    engine/   pure simulation (RefCounted classes, typed arrays, no Nodes/UI)  <- ported from reference/engine-js
    render/   map_view.gd + globe.gdshader + lenses.gd (GPU map, picking, camera)
    ui/       scenes: menu, HUD, province panel, nations, budget, save/load
    net/      host-authoritative multiplayer (later phase)
    i18n/     translations (EN/RU from legacy)
  tests/      headless GDScript tests (determinism, golden vs reference)
reference/    engine-js (oracle), i18n source tables
```

## Phases
| # | Deliverable | Exit criteria |
|---|---|---|
| 0 | plan, repo restructure, Godot 4.4 installed | done |
| 1 | data bake → Godot data (ID raster, CSR neighbours, 12 era packs) | done (350 KB total) |
| 2 | **Engine port (GDScript)**: state, economy, combat, commands, turn, AI, save | headless tests pass; behaviour matches JS oracle |
| 3 | **GPU map**: globe+flat shader, borders, lenses, picking, camera, quality tiers | draws in headless smoke run; shader compiles |
| 4 | UI + playable single-player loop (pick nation → play → end turn) | full loop without errors |
| 5 | AI depth: personalities, war goals, ultimatums, coalitions, vassals, peace models | AI expands, allies, wars, peace |
| 6 | Remaining systems: tech/eras UI, trade, espionage, generals, events (14 packs), victory, tutorial, flags, i18n EN/RU | parity checklist |
| 7 | Multiplayer (host-authoritative, rooms, chat, reconnect); server = Godot headless dedicated or Render | 4-player test |
| 8 | Export: Android (APK/AAB), Windows, iOS project; perf pass on low-end profile | budgets met |

## Performance budgets (low-end Android, ~2 GB RAM)
Cold start < 3 s · map ≥ 30 fps on a 5-year-old budget phone (GPU shader, 1 draw call) · tap-to-select < 16 ms · end-turn < 100 ms (250 nations) · RAM < 250 MB · APK < 40 MB.

## Feature-parity checklist (from legacy audit)
Province map + 12 era scenarios, historical nations/flags · economy (tax/production/admin distance, budget sliders) · pop/dev/happiness/stability · 9 regimes + change · 9 buildings (levels, queue) · tech/eras · armies · combat + terrain/defence · occupation war score · peace deals, tribute, vassals, ultimatums, war goals · NAP/alliance/marriage/coalitions · espionage · trade · colonization/discovery · rebels · formables · random/historical/scheduled events · generals · victory/endgame · lenses (political, diplomatic, economic, military, wars, stability, population, buildings, governments, terrain) · themes · search · tutorial/tooltips · EN/RU · difficulty · save/load/autosave · MP.

## Open items needing owner input
- iOS: building/publishing needs a Mac + Apple Developer account (I can prepare the project/preset).
- Render connector: needed only if you want a hosted relay server for MP (a dedicated headless Godot server is the default).
