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
  while dragging). Findings: (1) the corner ring of the selected province redrew its ~100 arcs and strings **every frame** for as long as anything was selected: now it redraws
  only when it can look different (anchor, hover, pop-in; the armed medallion's turning dots at 15 fps); a still screen draws no frame at all (low-processor mode),
  checked by the test. (2) `map_view` re-rendered the whole map shader every frame while a province was selected, for a dash animation the shader never used: removed.
  (3) Camera moves on the slow tiers (`lod_motion`: low and medium) now render the map at half resolution with the cheapest shader path and the half-size id texture, hide the
  labels and route lines, skip the hover / selection fades, and draw once in full when the camera has been still for 160 ms: 120 -> 44 ms a frame while dragging (llvmpipe).
  (4) Tiers 0 and 1 run `globe_lite.gdshader` (generated from `globe.gdshader` by `tools/make_lite_shader.py`; `tests/lite_shader.gd` proves it draws the same pixels): 30 % less
  code for the Direct3D shader compiler, and the 9-sample close-zoom smoothing (which only the high tier uses) is never compiled. (5) The title globe turns at 15 steps a second on
  the slow tiers (same speed).

Ideas not done yet: layout in a worker thread (compute on a snapshot, draw the result), moving the autosave off the main thread, lazy-loading the era flag sets.
