# UI foundation layer report

Scope: frame.gd, paper.gd, ui_kit.gd, glyphs.gd, ui_tokens.gd, tests/ui_contrast.gd, tests/ui_kit_sheet.gd, one line in tools/test_all.sh.

## TBFrame (frame.gd)
Kinds PLATE, SHEET (hero), BAR, SEAL, FOCUS. Polygons cached per size, whole-pixel strokes, HC = flat, 2 px borders, no shadow/texture.
- `TBFrame.plate(fill, border, cut=4, elev=0, pad_x=16, pad_y=12, pressed_shift=false, border_px=1, mask=ALL)`; fields `accent`/`accent_w` (3 px left bar).
- `TBFrame.hero(pad_x=28, pad_y=24, tint=)`, `TBFrame.bar(pad_x, pad_y, alpha=0.94, rule_edge=SIDE_BOTTOM)`, `TBFrame.seal(pressed, hot, disabled)` (cached), `TBFrame.focus(on_bar=false, cut=4, inset=0)` (cached).
- Shims kept: make / sheet (= panel plate) / chit (= secondary plate) / wax (= flat danger plate) / leather (= bar). `TBFrame.PAPER/INK/BRASS` remain.
- `TBFrame.kbd_nav` is true only after key/pad input (focus ring drawn only then); `TBFrame.ensure_watch()` installs the input watcher (called by K.theme() and K.modal()).

## TBKit (ui_kit.gd)
- Old colour names are static aliases of tokens; `K.sync_palette()`/`K.theme()` refresh them after `TBTokens.mode` changes. No raw Color literals.
- Settings statics: `text_scale`, `readable_fonts`, `reduce_motion`, `touch_large`, `dp_scale`; helpers `fs(px)`, `dp(n)`, `touch()`, `motion_ok()`, `a11y(ctrl,name,role,desc)`, `disable(btn, reason)`, `contrast(a,b)`.
- Fonts: `display()` = Cinzel 700 (500 retired), `wordmark()` = Cinzel 900, `mono_b()` figures, `delta(text,col)` Mono 400 12, `caps()` Alegreya 700 12 floor, `tracked()` cached.
- Controls: `button(text, cb, primary)`, `danger(text, cb, glyph="swords")`, `icon_button(glyph, cb, px)` / `K.IconBtn.new(glyph, cb, px, on_bar)` (`active`), `list_row(l, r, cb, col)` (`selected`, `right_col`), `segmented(items, cur, cb)`, `tabs(items, cur, cb)`, `slider(min,max,step,value,cb)`, `meter_row(caption, value, col=auto)`, `K.Meter`, `K.Pips`, `glyph(id, px, col, filled)`, `hair()`, `signed(v)`, `fmt(v)` (U+2212).
- New: `command_card(glyph, title, consequence, cost_text, cb, disabled_reason="", recommended=false, armed=false, unaffordable=false)`; `chip(text, glyph="", tone="neutral|pos|neg|warn|info|own", on_bar=false, height=28)`.
- `modal(parent, title, width, glyph, hero=false)` still returns `[back, body, footer]`; header bar with 48 px close, scrim 72 %, 180 ms enter (no scale, respects motion), landscape up to 920, portrait bottom sheet <= 92 %, pinned footer, Esc closes top modal (titleless decision modals are not Esc-dismissable), Tab/arrows trapped inside, focus restored to opener. Exit animation (120 ms) not implemented: callers free the node.
- Slider thumb and check boxes are self-drawing Texture2D (`VecTex`), no Image/bead_tex.
- `preview_state` ("hover"/"pressed"/"focus") on ListRow/IconBtn/CommandCard freezes a state for specimen sheets.

## Glyphs (glyphs.gd)
Const-data glyphs, square caps, stroke ladder 1.5/2/2.5 by size, `TBGlyph.draw` unchanged, new `draw_filled(ci, id, c, size, col, knock)`. Added ids: warning, info, link, lock, check, filter, supply, revolt, capital, general_star (always brass), tri_up, tri_down, arrowhead (points right), plus diamond.

## Tests
`tests/ui_contrast.gd` (132 pair checks, NORMAL and HC, from `TBTokens.PAIRS`), in `tools/test_all.sh`. `tests/ui_kit_sheet.gd` writes /tmp/ui_foundation/*.png.

## Open points
- HC text on paper-1 for semantic hues uses minimum 6.8 (art bible 4.7 itself states 6.84).
- Stepper (-/+) slider helper (A11Y-TCH-004) and toggle factory not built; other agents can compose from K.button/K.slider and CheckBox (themed).
- TBPaper.LEATHER/VELLUM removed (unused elsewhere).
