# Flag attribution

The flags shipped in `flags_manifest.json` are **original, simplified renditions**
created for Terra Bellum — not copied from third-party assets. They evoke each nation's
historical colours/devices in a low-detail style consistent with the game's UI.

- Pre-modern entries (Rome, Parthia, Han, Byzantium, HRE, Mughal, Qing/Manchu, Kalmar
  Union) are marked `"emblem": true` — they are **representative banners**, since these
  states had no flag in the modern sense.
- Nations without a manifest entry fall back to a procedurally generated banner
  (nation colour + initial) via `flagFor()` in `index.html`.

If exact historical flags are wanted later, public-domain SVGs from Wikimedia Commons
(`Category:SVG historical flags`) can be dropped into a `flags/<slug>.svg` file and
referenced from the manifest with `{ "file": "<slug>.svg" }` (or date-ranged `variants`).
See `roadmap-historical-flags.md`.
