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
* Within engine: `rng`, `data` (tables) → `game` (state/ownership/economy/combat/commands) → `turn` → `ai`. Each file is < ~600 lines and does one thing.
* render reads engine arrays and writes only GPU textures.
* `tools/check_layers.mjs` (run in tests) fails the build when a forbidden dependency appears.
* Tests: `godot/tests/` run with `godot --headless -s tests/run_all.gd`.
