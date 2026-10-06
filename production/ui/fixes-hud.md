# HUD / command card / touch fixes (ui-programmer, branch fix-hud)

Files: hud.gd, hud_parts.gd, alert_ticker.gd, cmd_card.gd, province_panel.gd, main.gd (wiring only), i18n (tk_round_seat, cc_break_ask, al_no_general copy),
tests/ui_hud_layout.gd (new: overlap / off-screen / 48 u hit-area asserts, run from tools/test_ui.sh), tests/hud_shots.gd.

| ID | Status | Note |
|---|---|---|
| ux B-02 | FIXED | Card sits in `hud.card_band()` (right of rail, 16 u left of the End Turn seal + chip). Asserted at 800x360, 900x415, 1280x720, 1920x1080, 2340x1080 (and 150/200 % text). Declare War cannot touch End Turn. |
| art A-4 / ux M-01 | FIXED | Circular seal drawn with `TBFrame.seal` (80 u, 72 compact/portrait), chevrons + caption inside when it fits, else caption moves to the wrapping `SealNote` chip above it. States idle / hint (ring runs down) / busy sweep / MP waiting / hot-seat "Pass to Pn" / over (40 %). Wide plate code deleted. Portrait no longer squeezes it. |
| ux M-03 / M-04 | FIXED | Portrait bottom bar = 4 screens + More (48 u+ cells; More lists Annals, Goals, Save, Options, Map lens). Top bar reserves the "..." width; if chips still do not fit the bar wraps to 2 rows (hud.md 10.2). |
| ux M-10 | PARTIAL | Handle 48 u hit, Details/close 48 u hit, share cells >= 48 on L/P, cost line wraps (own row in P), no ellipsis on verbs (shrink to 12 then wrap). NOT DONE: 3-snap live-drag sheet (still card/drawer toggle). |
| ux M-11 | FIXED | L strip: chips fit the header row, lowest-priority chips hide; at >= 140 % text the header splits into two rows. |
| ux m-03 / a11y TXT-002 | FIXED | `fs()` floors at 12 in HUD and card; hotkey badge 12 (hidden at >= 150 %). |
| ux m-06 | FIXED | Ticker 4 rows + pill; the info toast is stacked below the pill. Rows are 48 u (wrap to 2 lines instead of ellipsis). |
| ux m-09 / M-12 | FIXED | "Round n · Pk/N" in the realm sheet and in the End Turn chip (all profiles). Curtain itself is the modals agent's. |
| a11y TCH-001 | FIXED | `Hit` base: 48 x 48 (56 large) hit rect on both axes, no platform gating; popover rows, ticker rows, inline offer buttons, `btn()` 48; lens buttons 48 wide. `large_targets`/`touch_large` read defensively via `P.touch()`. |
| a11y TXT-001/002 | FIXED | `P.sync_settings()` / `CC.sync_settings()` read `K.text_scale`; `hud.set_text_scale()` called from `_apply_a11y`. Verified 150 % and 200 % at 540x960 and 800x360 (no clip / off-screen; rail turns into the menu button when it no longer fits). |
| a11y MOT-001/002 | FIXED | `P.reduced_motion()` = `K.reduce_motion` or TB_NOANIM: rolling numbers, seal pulse (static ring) / sweep (static arc), ticker tweens, card rise; card shake removed (120 ms outline flash only). |
| a11y SR-003 / COG-005 | FIXED (HUD side) | Every toast, report line, alert goes to `hud.feed`; `hud.feed_lines(n)`. Annals (modals) must merge it. |
| a11y SR-004 hook | FIXED | `hud.announce(text, critical=true)`; speaks via `DisplayServer.tts_speak` when `cfg["tts"]` (bool or off/critical/all) is on; also used for new alert chips and toasts. |
| a11y COG-004 | PARTIAL | `confirm_mode` (cfg `confirm_mode` or `hud.confirm_mode`): declare war and break pact (new confirm row on the card) ask in smart/always, not in never. No disband control exists in the UI. |
| art A-11 (HUD part) | FIXED | No raw `Color(...)`/`Color.BLACK` left in my files (legend ramps use data hex colours). |

## APIs for other agents
- `hud.announce(text, critical=true)`, `hud.feed`, `hud.feed_lines(n)`, `hud.set_text_scale(f)` (called by main `_apply_a11y`), `hud.end_turn_rect()`, `hud.card_band()`, `hud.bottom_reserve()`, signal `hud.layout_changed`.
- Settings read from the parent's `cfg`: `confirm_mode` ("smart"/"always"/"never"), `tts` (bool or "off"/"critical"/"all"). Kit: `K.text_scale`, `K.reduce_motion`, `K.large_targets` or `K.touch_large`.
- `panel.band_fn / reserve_fn / confirm_fn` are wired in main.gd; `resized` now lays out the HUD before the card.
- i18n added: `tk_round_seat`, `cc_break_ask`.

## Concerns
- Portrait: Lens moved from the bottom bar into More (2 taps); KEY_L still opens it.
- order_flow's preview chip (not mine) can still overlap the card header on 800x360.
