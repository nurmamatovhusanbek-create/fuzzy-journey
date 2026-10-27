# Performance notes (low-end laptops)

Measured headless / under xvfb on a fast CPU (a low-end laptop is ~3-5x slower):

| what | cost |
|---|---|
| `TBWorld.load_from("res://data")` (1788 provinces) | 34 ms |
| `TBGame.new` (95 nations) | 26 ms |
| one `end_turn()` (AI included, worker thread) | ~28 ms |
| `TBSave.to_dict` + stringify | 20 ms (375 KB) |
| 95 flag textures / medals | 27 / 17 ms |
| loading `main.tscn` (parsing ~1.8 MB of GDScript, **editor / dev run only**) | ~2 s |
| map label layout, one full pass (before this round) | 30-47 ms |

Findings and what was done:
* **Map labels were the CPU hot spot.** Every `_push_view()` (the hover fade and the selection fade call it every frame for ~0.1 s after each mouse move) asked for a complete
  relayout of nation names, army markers and province names. Now the map asks for a relayout only when something that moves the labels changed (camera, size, selection,
  quality, language, high contrast...; the hovered province only at the middle zoom tier), and while the camera moves a relayout waits for ~3x its own cost (labels trail the
  map by a few frames on a slow CPU instead of halving the frame rate). Text widths are cached, the marker collision test uses a grid, the nation-core signature is a native hash.
* **Routes** (`TBMapRoutes`) redrew every frame forever once one existed; now only while a line grows in or a trade load travels. (They also did not appear until the camera
  moved: fixed.)
* **First-run quality** is guessed from the hardware (software renderer: low; integrated GPU or <= 4 threads: medium; else high); the auto tier still steps down when frames
  stay slow.
* **Start-up in the editor** is dominated by compiling the GDScript sources and by the first import of the 21 MB of flag PNGs. An exported build uses compressed binary tokens
  (`script_export_mode=2` in export_presets.cfg) and the pre-built import cache: use **Project > Export** (Windows Desktop) and run the exe for the real feel.
* End Turn: the AI turn runs on a worker thread; the rest of the hitch is the main-thread tail (repaint, HUD refresh, the autosave).

* **Round 4 (a 2011 Intel HD 2000 laptop read 4 fps in the in-game diagnostics).** Measured with `tests/perf_idle.gd` (frames actually drawn with the screen still, ms per frame
  while dragging). Kept, because they change nothing you can see: (1) the corner ring of the selected province redrew its ~100 arcs and strings **every frame** for as long as
  anything was selected: it now redraws only when it can look different (anchor, hover, pop-in; the armed medallion's turning dots at 15 fps); a still screen draws no frame at
  all (low-processor mode), checked by the test. (2) `map_view` re-rendered the whole map shader every frame while a province was selected, for a dash animation the shader
  never used: removed. Tried and **reverted** because they cost picture quality: half-resolution / cheaper-shader frames while the camera moves, no highlight fades, a
  trimmed shader for the low tiers, a slower title globe. The map must look the same at every moment; speed comes from doing less work, not from drawing less.

* **Round 5: speeding the map up without touching what it looks like.** Method: `tests/shader_bench.gd` times the map shader with one part removed at a time (median of 24 renders),
  `tests/shader_compare.gd` draws a view with two versions of the shader and counts the pixels that differ, `tests/hover_bench.gd` counts partial / full redraws. What the research
  found (software GL stands in for a weak GPU; relative sizes only): the sea is ~70 % of the pixels and the coastal glow was the biggest single piece (8 + up to 40 id-texture reads
  per sea pixel); the two extra `unproject()` calls per pixel (to learn how many texels a pixel covers) came second; borders, palette reads, the graticule and the sea gradient are
  3-8 % each. What was done, all pixel-equivalent: (1) the glow reads a **distance field** (data/coast.bin.gz, exact Euclidean distance to the nearest land at half the id
  resolution, float16, built by `tools/gen_coast.sh` with an EDT in C) instead of probing the id texture: one read; the glow edge is now anti-aliased instead of stair-stepped
  (the one visible difference: smoother). The approach is the one grand-strategy map makers describe (a distance field built from the province id map, rebuilt only when the
  ids change). (2) `tex_deriv()` gives the texels-per-pixel vectors in closed form (the Jacobian of the sphere / Mercator projection): 0.005 % of pixels differ from the
  finite-difference version, and only at the globe's rim. Together ~20 % less shader time per render. (3) **Partial redraws:** a hover brightens one nation and a selection washes
  one province, so those redraw only the screen rectangle they touch (a scissor on the map viewport; the rest of the picture is kept); the camera, palette, lens, targets,
  quality or size still redraw everything, and a change that shows nothing now redraws nothing. The rectangle comes from province bounding boxes (data/prov_bbox.bin.gz), with
  a generous margin and a fallback to a full redraw whenever it cannot be bounded (a province half behind the globe's rim, a nation filling most of the screen).
  `tests/map_partial.gd` checks random hovers and selections both ways and demands identical pixels. About half of the hovers at the usual zoom qualify.
  Not done, and why: a pre-rendered world texture mapped onto the sphere (borders would no longer be a constant screen width, the look would change); half-resolution frames
  while the camera moves (tried and reverted: visibly softer).

* **Round 6: what a frame costs besides the map shader, and a cache that changes no pixel.** `tests/frame_cost.gd` (a camera drag, parts switched off one at a time) and the
  engine's own counters (`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, deterministic, unlike timings) showed that the interface was most of what was
  left: **12,400 canvas commands and 830 draw calls per redrawn frame, 94 % of them the HUD** (every glyph is a command: the End Turn dial is 2,300 commands, the lens bar 1,200,
  a rail tab 470, a medallion 390). Godot replays every command of every visible item whenever the screen redraws, so even a hover that touches one province paid for the
  whole HUD (about 8 ms of CPU on a fast machine here, two to three times that on an old laptop with ANGLE, whose draw calls are dear). `src/ui/bake.gd` (`TBBake`) fixes this:
  a HUD piece that has not drawn for 18 frames is rendered once into a small transparent viewport (it shares the root's 2D world and renders only that piece's own
  canvas layer) and shown as ONE textured quad aligned to whole screen pixels with premultiplied blending; the moment the piece draws again (hover, a new figure, a resize)
  it goes back to drawing itself. The map labels and the route lines are cached the same way while the map is still. Result: **idle redraw 12,400 commands / 830 draw calls ->
  1,350 / 38** (at zoom 3.2). `tests/bake.gd` renders six states (flat, selected, lens, alerts, globe, globe zoomed in) with the cache on and with every piece drawing
  itself and compares the screenshots: 1 pixel differs, by 4 levels of 255; it also checks hovering. Gotchas found on the way: Godot culls a branch by its layer, so every
  ancestor must carry the bake layers; the cached picture must be a sibling, not a child, of a piece on the hidden layer; every bake in flight needs its own layer (a full-screen
  piece otherwise photographs the small ones); the viewport texture is premultiplied, so it is drawn with the premultiplied blend mode. `TB_NOBAKE=1` switches the cache off.
  Also: the map shader's per-pixel `sin(lat0)`, `cos(lat0)` and the flat map's `log(tan())` of a uniform are now uniforms worked out once on the CPU (`slat0`, `clat0`,
  `merc0`): zero pixels differ (`tests/shader_compare.gd`), and they matter most where transcendental functions are slow (Intel HD 2000). Measured (software GL, camera
  drag, medium tier, 1280 x 720): 143 ms -> 117 ms per frame; the shader is the rest.

Ideas not done yet: layout in a worker thread (compute on a snapshot, draw the result), moving the autosave off the main thread, lazy-loading the era flag sets.
