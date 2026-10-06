# Kit, settings, accessibility systems: fix report

Branch `fix-kit`. Verified: `tests/ui_contrast.gd` (222 pairs over NORMAL / HC light / HC dark, greyscale primary gap), `tests/ui_lint_tokens.gd`,
`tools/test_ui.sh` UI PASS, `tools/test_all.sh` ALL PASS (includes `tools/test_mp.sh` MP OK). Kit specimen boards viewed normal, greyscale, HC light/dark, 200 % text.

## APIs for the other streams
- `K.reduce_motion`, `K.motion_ok()` (also false under TB_NOANIM), `K.motion_factor()` (1/0, for shader uniform and pulse amplitude), `K.spin_ok()` (title spin), `K.dur(s)`, `K.tween(node, prop, to, s)`, `K.roll_number`, `K.shake` (no-op by design).
- `K.text_scale` (1.0/1.25/1.5/2.0), `K.fs(px)`, `K.large_targets`/`K.touch_large`, `K.touch()` (48 / 56), `K.MIN_TOUCH` = 48.
- `TBTokens.mode`: 0 normal, 1 HC light, 2 HC dark. Test HC with `TBTokens.is_hc()`, never `== 1`. `TBTokens.is_dark_hc()`, `TBTokens.with_a(col, a)`, `TBTokens.dict(mode)`. New tokens: `act`, `act_hover`, `act_press`, `act_rim`, `on_act` (primary slab), `on_brass` (text on brass / amber fills; use instead of `ink_0` there, because `ink_0` is white in HC dark).
- `cfg`: `hc` off/light/dark (old `contrast` bool migrates), `cvd` off/deuter/protan/tritan, `tts`, `confirm` off/risky/all, `mirror`, `vis_alerts`, `vol_master/music/sfx/ui`, `comfort_seen`, `theme` now also "hc" (map.map_theme = 2). Statics mirrored on the kit: `K.cvd`, `K.tts_on`, `K.confirm`, `K.mirror`, `K.vis_alerts`, `K.sound_muted`; `K.need_confirm(risky)`.
- `K.apply_settings(cfg) -> Theme` (sets all statics, rebuilds the theme, emits `K.settings_changed(cfg)`; main does `theme = K.apply_settings(cfg)`). Screens that cache styles connect to `K.settings_changed`.
- `K.announce(text)`, `K.tts_test()`, `K.tts_warning`, `K.a11y_text(ctrl)`, `K.alert_strip(text, kind)` (A11Y-AUD-006 strip; the HUD places it when `K.vis_alerts or K.sound_muted`).
- `K.toggle(text, value, cb)`, `K.slider_row(label, min, max, step, value, cb)` (-/+ steppers), `K.segmented(items, cur, cb, compact=false)`, `TBAudio.apply_volumes(cfg)`, `TBMenuHub.comfort(parent, cfg, on_change)`.
- `TBPortrait.new().setup(g, n, px)` snaps px to 32 / 48 / 72 (larger values keep the 72 detail).

## Findings
| ID | Status | Note |
|---|---|---|
| A11Y-TXT-001/002 | FIXED (kit) | 4 steps in Settings and first-run page; `K.fs` everywhere in the kit; verified at 200 %. HUD / cmd_card / map labels private `fs` statics belong to the other streams (they should call `K.fs`). |
| A11Y-TXT-003 | PARTIAL | Kit controls grow in height and wrap (segmented grid, toggle rows, list rows); modal/panel header truncation at 200 % in `panel.gd` and screen layouts are not mine. |
| A11Y-TCH-001..003 | FIXED (kit) | `MIN_TOUCH` 48 unconditional, large = 56; rows, cells, icon hit, sliders >= touch. Callers gating 48 on mobile (`nations_screen`, `menu_parts`, `panel.gd` chips) are other streams. |
| A11Y-TCH-004 | FIXED | `K.slider_row` with 48 px steppers, used for all four volume sliders. |
| A11Y-TCH-005 | FIXED | already release-activated; unchanged. |
| A11Y-MOT-001/002 | PARTIAL | kit honours it (modal, helpers, title spin hook applied in main.gd `_process`); other streams must switch their `TBMapView.animate` reads to `K.motion_ok()`. `shake` is a no-op. |
| A11Y-CON-005 | FIXED | HC light and dark variants, live switch, 3 px focus ring in HC, tests cover all three. |
| A11Y-CON-007 | NOT DONE | map shader theme 2 belongs to the map stream; Settings offers "High contrast" map style, main maps it to `map_theme = 2`. |
| A-1 | FIXED | primary = ink slab with brass text and 2 px brass edge (measured: act vs paper-1 >= 3:1, text >= 7:1); disabled primary drops to the locked secondary look. Greyscale viewed. |
| A-2 | FIXED | selected segment = paper-2 + 3 px oxblood underline + filled check (check omitted only when the cell is too narrow) + ink text; HC adds a 2 px outline; `compact=true` added; cells wrap into a grid. |
| A-9 | FIXED | flat paper-1 tile, ink bust, token colours only, variants 32/48/72. |
| A-11 | FIXED | no raw numeric `Color(` in src/ui outside `ui_tokens.gd`/`flags.gd`; lint `tests/ui_lint_tokens.gd` in `tools/test_ui.sh` (derived `Color(c.r, ...)` and `Color()` are allowed). Legacy `K.GOLD*` aliases still exist (about 90 call sites). |
| A11Y-CVD-003 / settings IA | FIXED (settings) | Display / Accessibility / Audio / Advanced groups on one page with jump chips (Settings = 1 tap, any setting = 2), all keys persisted and applied live, reset behind a confirm. CVD palettes themselves are the map stream. |
| A11Y-AUD-001/003/006 | FIXED (systems) | Music / SFX / UI buses plus Master limiter, sliders, mute-all; visual strip option plus `K.alert_strip` (HUD must place it). |
| A11Y-TIM-002 | PARTIAL | host timer Off (default) / 120 / 240 / 360 s in the multiplayer dialog, persisted; server treats 0 as no clock (authoritative); clock hidden when off. Per-player x1.5 / x2 / x3 and the persistent 25 % warning are not built. |
| A11Y-SR-003 | NOT DONE | Annals mirror is a modals stream item. |
| A11Y-SR-004 | PARTIAL | `K.announce`, focus speaker, Esc stop, test voice with no-voice warning, `cfg.tts`; hot-seat / new-Annals-line speech calls are for the HUD stream. |
| A11Y-SR-001 | FIXED (kit) | every kit control sets name / role (buttons, icon buttons, rows, tabs, segmented cells, toggles, sliders, steppers). |
| SET-002 first run | FIXED | `TBMenuHub.comfort` offered once from main (skipped in `-s` script runs unless `TB_COMFORT=1`). |

## Concerns
- i18n blocks sit just before `ev_worldwide:` in en/ru/uz.js, so merges with the other streams' inserts there will conflict textually (keep both blocks).
- `main.gd` edits: cfg defaults, `_load_cfg` migration, `_apply_a11y`, `_on_setting_changed` arms, title-spin gate, first-run offer, battle floater colours.
- Panel dialog header at 200 % on 540 wide truncates the title ("Comfort an...") and the hub tab row scrolls: `panel.gd` territory.
- `settings.cfg` left by earlier test runs (sound=false, readable=true) shows up in screenshots; delete `~/.local/share/godot/app_userdata/Terra Bellum/settings.cfg` before judging defaults.
