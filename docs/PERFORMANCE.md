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

Ideas not done yet: layout in a worker thread (compute on a snapshot, draw the result), moving the autosave off the main thread, lazy-loading the era flag sets.
