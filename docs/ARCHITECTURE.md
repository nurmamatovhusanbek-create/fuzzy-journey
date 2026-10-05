# Architecture & layering rules

Code is split into **chunks (layers)** so each can be changed and tested alone.

| Layer | Path | May depend on | Must NOT depend on |
|---|---|---|---|
| data | `godot/data`, `tools/bake.mjs` | — | everything |
| engine | `godot/src/engine` | data | render, ui, net, any `Node` |
| render | `godot/src/render` | engine (read-only) | ui, net |
| ui | `godot/src/ui` | engine, render | net internals |
| net | `godot/src/net` | engine | ui, render |
| i18n | `godot/src/i18n` | — | — |

* **engine** is headless: `RefCounted` classes + typed arrays. Mutations happen only through `Game.apply(command)` (one mutation API) so UI, AI and network share the same path and it is trivially testable.
* Within engine: `rng`, `data` (tables) → `game` (state/ownership/economy/combat) → `commands` (the validated mutation API behind `Game.apply`) → `turn` → `ai`, with rules>=1 systems in their own files (`rulers`, `diplomacy`, `decisions`, `trade`, `realms`, `generals`, `stats`, `advisor`, `regimes`). Each file is < ~600 lines and does one thing.
* render reads engine arrays and writes only GPU textures.
* `tools/check_layers.mjs` (run in tests) fails the build when a forbidden dependency appears.
* Tests: `godot/tests/` run with `godot --headless -s tests/run_all.gd`.


## UI design system ("war table")
Visual language: navy lacquer and brass rules, matching the original game (`--bg #060a14 / --gold #d4a017 / --ink #e8dccc`), with engraved capitals (Cinzel; Alegreya SC covers Cyrillic) and monospaced figures (JetBrains Mono). Fonts live in `godot/assets/fonts` (OFL).

| Piece | File | Notes |
|---|---|---|
| `TBFrame` | `ui/frame.gd` | StyleBox: chamfered, asymmetric notches, optional second hairline + registration ticks. No rounded corners anywhere. |
| `TBGlyph` | `ui/glyphs.gd` | ~30 engraved line icons drawn with primitives (no emoji/icon fonts: unreliable on phones). |
| `TBKit` | `ui/ui_kit.gd` | palette, fonts, theme, helpers: `title/num/caps`, `row` (dotted leaders), `meter_row`, `Pips`, `segmented` (underlined tabs), `list_row`, `choice_card`, `modal` (+ornament rule). |
| HUD parts | `ui/hud_parts.gd` | top ribbon, readouts, dock buttons, End-Turn seal (bezel sweeps while the turn resolves). |
| Title screen | `ui/menu_parts.gd` | bezel ring around the globe, typographic menu entries, era timeline rows. |

Rules: figures are mono, names/titles are Cinzel, body copy stays the engine default for legibility on small screens; boxes are only used where something is an object (modal card, event choice); lists are ledger lines, tabs are underlines, steps are diamonds. Landscape: dock on the left edge, seal bottom-right; portrait: dock along the bottom, toasts under the ribbon, province sheet lists actions before figures.
