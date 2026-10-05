# Terra Bellum — Rebuild Plan

Decisions (confirmed with the owner):

1. **One unified province engine.** v1 "country mode" disappears as a separate engine. A country is just a nation owning provinces. The v1 AI, espionage, trade, generals, events and victory systems are ported onto the province engine. v2 currently has *no* AI wars at all — the rebuild fixes that.
2. **Pre-baked map + light canvas renderer.** No per-frame polygon projection, no d3 at runtime, no WebGL requirement.
3. **Multiplayer:** redesigned as deterministic lockstep (commands + seed + state hash). Server lives in this repo (`server/`) and is deployed to Render via the connector.
4. **Modular ES modules, no framework, esbuild bundle.** Simulation runs in a Web Worker.

Legacy game is preserved untouched in `legacy/index.html` until feature parity.

## 1. What is wrong today (measured from the code)

| Problem | Where | Effect |
|---|---|---|
| 1.5 MB single file, 19.7k lines, 280 KB d3 + 107 KB inline v1 topojson parsed on load | `index.html` | slow load, huge parse/GC |
| `d3.geoPath` re-projects + clips ~1,800 polygons (34k arcs) every frame while dragging; `shadowBlur`, per-feature gradients | `drawGlobe` | main cause of lag |
| Hit test = `d3.geoContains` over *every* province per click | `attachGlobeInteraction` | O(N·vertices) per tap |
| State is nested objects (`S.provinces[id]`, `S.nations[id]`) with string ids; `Object.keys`/`Object.values` scans every turn | engine | GC churn, slow turns |
| `S.features` (all geometry) lives inside `S`; MP host `JSON.stringify`s whole `S` and broadcasts it every turn | `mpSerialiseS` | multi-MB per turn |
| Simulation, AI (v1 `aiTurn`, 30-nation batches) and rendering share the main thread | `endTurn` | UI freezes at end of turn |
| ~50 `backdrop-filter`, ~60 `box-shadow`, many `innerHTML` full re-renders | CSS/UI | repaint cost on weak GPUs |
| Two engines (v1 `S.countries/players`, v2 `S.provinces/nations`) with `if (S.v2)` forks | everywhere | duplicate code, v2 AI missing |

## 2. Target architecture

```
src/
  data/        bake output loaders (world.bin, era packs, events, i18n)
  engine/      PURE deterministic sim (no DOM). Runs in worker.
    state.js     struct-of-arrays state (Int32/Uint16/Float32 arrays by province/nation index)
    rng.js       seeded mulberry32 (lockstep-safe)
    commands.js  the ONLY way state changes: move, recruit, build, declare, peace, ...
    turn.js      end-of-turn pipeline (income, growth, unrest, events)
    combat.js  diplomacy.js  economy.js  tech.js  events.js  victory.js
    ai/          budgeted AI: each nation re-plans every N turns, frontier lists only
  render/      canvas renderer: baked equirect bitmap, globe sampler, pick buffer, lenses
  ui/          vanilla DOM panels, event delegation, virtual lists, tooltips
  net/         lockstep client (commands, hash check, resync snapshot)
  i18n/        EN/RU tables (extracted from legacy)
  main.js      boot, worker wiring
tools/bake.mjs  topojson/era json  ->  public/data/*.bin   (build-time only)
server/        Node ws relay for lockstep (Render)
```

### Data model (SoA)
Provinces get dense int ids `0..P-1` (P≈1,800). Parallel typed arrays: `owner:Uint16`, `army:Uint16`, `pop:Uint16`, `dev:Uint8`, `stab:Uint8`, `building:Uint8`, `flags:Uint8`, plus static `lat/lon/neighbors(CSR)`. Nations `0..N-1` with typed fields and small arrays for relations (`N×N Uint8` matrix: war/peace/nap/ally/vassal). No object per province, no strings in hot paths. Per-nation province lists maintained incrementally (CSR + dirty flag).

### Renderer
- **Bake (build time):** rasterize provinces into a 2048×1024 equirectangular **ID buffer** (`Uint16`) + per-province span lists (run-length rows) + simplified borders. Shipped as one compressed binary.
- **Runtime base layer:** offscreen 2048×1024 bitmap painted from the ID buffer using a nation/lens colour LUT. An ownership change repaints only that province's spans (microseconds), not the map.
- **Globe:** custom orthographic inverse sampler into the base bitmap at an adaptive internal resolution (e.g. 384² on weak devices, lower while dragging, upscaled by the canvas). No polygon projection at all. Flat map = pan/zoom blit of the same bitmap.
- **Hit test:** inverse projection → equirect pixel → ID buffer lookup. O(1).
- Overlays (selection outline, war fronts, army chips, labels) drawn only for visible provinces, from precomputed centroids; zoom-gated; no shadow blur.
- Quality tiers auto-selected by a first-run frame-time probe (Low / Medium / High); user override in settings.

### Simulation / AI
- Worker owns the state; main thread sends **commands**, receives **compact diffs** (changed province ids + values) — never full state.
- End-of-turn is time-sliced and incremental; AI is budgeted: each nation plans every k turns (staggered by index), reads only its frontier provinces, scores via small integer formulas. Ported personalities/grudges/war-likelihood/war goals/ultimatums from v1.
- Deterministic (seeded RNG, no `Math.random`, no iteration over object keys) so the same engine powers lockstep MP and replays/tests.

### Multiplayer
Lockstep: server relays signed command batches per turn; every client runs the same worker; clients exchange a state hash each turn; mismatch → host snapshot resync. Payload per turn = a few hundred bytes instead of the whole state. Host-migration is trivial because nobody is authoritative. Server: `server/` (Node `ws`), room codes, lobby, chat, reconnect, timers — same feature set as the current client expects.

### Save/Load
Typed arrays → one binary blob (+ small JSON meta) → IndexedDB slots + autosave. Versioned.

## 3. Phases

| # | Deliverable | Exit criteria |
|---|---|---|
| 0 | This plan, repo scaffolding, esbuild, legacy preserved | `npm run build` works |
| 1 | `tools/bake.mjs`: world + 12 era packs → binary; ID raster, CSR neighbors, centroids, borders | bake <1 min; data size ≤ ~1/3 of current |
| 2 | Engine core + tests: state, RNG, commands, economy, combat, turn loop | deterministic test: same seed+commands ⇒ same hash |
| 3 | Renderer: globe + flat + pick + lenses + quality tiers | 60 fps drag on throttled CPU; 1-frame ownership repaint |
| 4 | UI shell + single-player playable (pick nation, move/attack/recruit/build, end turn) | full SP loop without lag |
| 5 | AI + diplomacy + war goals/peace/ultimatums/coalitions/vassals | AI nations expand, ally, war, make peace |
| 6 | Port remaining systems: tech/eras, trade, espionage, generals, events (14 packs), victory, tutorial, flags, i18n EN/RU | parity checklist (below) |
| 7 | Lockstep MP + server on Render | 4-player test, hash stays equal, reconnect |
| 8 | Perf budget CI (Playwright, CPU throttle 6×), save/load, polish, retire legacy | budgets met |

## 4. Performance budgets (6× CPU throttle in headless Chromium)
- Cold load to menu: < 2 s on 3G-fast; JS < 250 KB gz, data < 1.2 MB gz.
- Drag/zoom: ≥ 45 fps. Click-to-select: < 16 ms.
- End turn (250 nations): < 150 ms main-thread blocking (worker does the rest); UI never freezes.
- Memory: < 120 MB heap.

## 5. Feature parity checklist (from legacy audit)
Province map + 12 era scenarios, historical nation names/flags · economy (tax/production/admin distance, budget sliders) · population/dev/happiness/stability · regimes (9) & change · buildings (9, levels, queue) · tech/eras · armies move/recruit/reduce · combat + terrain/def · war score from occupation · peace deals, tribute, vassalage, ultimatums, war goals · NAP/alliance/marriage/coalitions · espionage · trade routes · colonization/discovery · rebels · formable nations · random + historical + scheduled events · generals · victory/endgame/leaderboard · lenses (political, diplomatic, economic, military, wars, stability, population, buildings, governments, terrain, spikes) · themes · search · tutorial/tooltips · EN/RU · difficulty · save/load/autosave · MP (rooms, timer, chat, reconnect).

## 6. Open items needing owner input later
- Render connector access (to deploy `server/`).
- Whether to keep the parchment theme and data-spike lens at launch (default: keep, Medium+ tiers only).
