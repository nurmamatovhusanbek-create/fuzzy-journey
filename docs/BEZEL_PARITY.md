# Bezel parity — the game UI must be the Bezel demo, not "inspired by" it

**Goal (user, verbatim):** "imply the bezel exactly as is into the game: colors, functions, dimming, details. The game has to have the exact UI and
interface as Bezel, not even slightly different. Keep polishing till you get there."

The reference is the HTML demo `docs/ui_variants/bezel_demo.html`, built from `docs/ui_variants/src/b_demo.html` + `bezel.css` + `bezel_kit.js` +
`common.js` (`node docs/ui_variants/build.mjs` regenerates the html; always edit `src/`). Everything in the demo — every number in its CSS and in its JS
template strings — is the spec. Read the demo source for the thing you are porting and copy its values (sizes, paddings, radii, colours, opacities,
letter-spacing, font weights, gradients, shadows, hover/active/disabled states, animation timings). Do not "improve" or re-interpret.

## Units
The demo is a **stage 1180 units tall** (desktop) or **390 units tall** (phone landscape: css height < 560 and width < 1300), scaled to the window
(`sc = innerHeight / stage height`). The game now does the same: `main.gd::_update_ui_scale` sets the window's `content_scale_size` so that **one logical
Godot unit = one demo design unit**. A 46 unit medallion is `46.0` in GDScript. At a 1280x720 window one unit is 0.61 px; at 1920x1080, 0.915 px.
cfg `ui` small/normal/large = the demo's L/M/S stage sizes (1.18 / 1 / 0.86 of the base height).

Old Godot code was written for a 720 unit stage with its own numbers (`64 px rail`, `13 px text`...). Those numbers are **wrong now**. Replace them with the
demo's. Do not scale old numbers; port the demo's.

## Fonts / colours
Fonts shipped in `godot/assets/fonts` are the demo's (Cinzel 500/700, Alegreya 400/500/700/400i, Inter, Barlow Condensed, JetBrains Mono). Colour tokens are
in `godot/src/ui/ui_tokens.gd` and must equal the demo's `:root` vars and literals (`--bg #0A0D12 --panel #17130F --brass #C9A24B --hi #E5C77A --lo #7F6A33
--ivory #EFE6CF --dim #A89C80 --dim2 #7d735c --good #69B3A2 --bad #D2603F --info #7FA8E8 --warn #E4A94B`). Prefer a token; if the demo uses a literal that has no token, add one.

## Hard rules
* **The End Turn dial must not change** (user: "Do not change the end turn"). Do not touch `Seal` or its drawing.
* Circle borders are thin everywhere except End Turn; HUD gauges keep their colour with thin arcs; buttons are notched plates; notices are an instrument
  medallion on a notched plate; the title / main menu are unchanged. (All of this is already what the demo does — keep it.)
* Keep all behaviour, signals, i18n keys, accessibility hooks (`K.a11y`, focus, text scale, high contrast, reduced motion) and the engine untouched.
  The demo's wording where it differs from a game string (e.g. "Treasury / People / Host / Envoys" vs "Gold / Manpower / Move Points / Diplomacy Points")
  is the demo's: change the English string in `reference/i18n/en.js` (run `node tools/i18n.mjs`) and keep ru/uz meaningful.
* Real game data replaces demo placeholders; layout, type and ornament are identical.
* Don't break tests: `tools/test_all.sh` (headless) and `tools/test_ui.sh` (xvfb). Layout tests that hard-code old unit sizes may be updated to the new stage.

## How to compare (do this constantly)
`tools/parity.sh <outdir> [w=1280] [h=720] [states]` renders the demo (Playwright/Chromium) and the game (`godot/tests/parity.gd`) in the same states at the same
window size and writes `cmp_<state>.png` (demo | game | difference) plus a mean-difference number per state. States: map nations budget decrees council annals
goals menu select (game) / event war tip2 lens move preview (demo only so far — add them to `tests/parity.gd` when you port that screen).
Look at the sheets (Read the PNG) — the number only tells you something moved; your eyes tell you what. Crop and zoom with PIL for details.
The map content differs (the demo shows one hand-made Europe; the game shows real data) — judge the *chrome*: fonts, sizes, spacing, colours, strokes,
shadows, dimming, hover states. For map styling compare palette, borders, sea, graticule, coast glow, labels.

Iterate until a side-by-side is indistinguishable apart from data. Then do it at 1920x1080 and at a phone size (the demo's phone layout, `?` height 390: run
`tools/parity.sh out 844 390`).
