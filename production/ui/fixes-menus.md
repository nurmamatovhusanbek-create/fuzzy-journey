# Fixes: title, modals, new game, pick flow (branch fix-menus)

Scope: `modals.gd`, `menu_parts.gd`, `newgame.gd`, `pick_flow.gd`, `panel.gd`, `nations_screen.gd`, `chronicle.gd` (glyph helper), `data/events/*.json` icon fields, i18n (6 new keys + 3 copy fixes), and in `main.gd` only `show_menu`, `_start_game` (one call), `show_events` / `_defer_event` (Decide later). Tests: `tests/ui_modals.gd` gained layout assertions (answers and primaries on screen, title entries disjoint) and `TB_DEBUG_W=<scene>` (widest min-size controls).

## Findings

| ID | Status | Note |
|---|---|---|
| ux B-01 / art A-8 title | FIXED | Bezel disc alpha 0.55; entries are plain outlined text rows on the globe (cream, brass only on the primary / hovered row, 3 px brass bar under the primary); tools row = small text buttons; language = EN \| RU \| UZ text (selected = underline, no brass); zero brass fills. Ring is sized to clear the tools row; centre column scrolls (never covers anything); wordmark fits at every size / text scale; tagline + ornament dropped below 480u. Checked EN 1280x720, 1920x1080, 900x415, 800x360, 540x960; RU 1280x720, 540x960. |
| ux M-06 portrait wordmark | FIXED | size computed from width and text scale |
| ux B-03 pick card | FIXED | card clamped to the viewport, body scrolls, "Play as X" pinned; compact 3-row card on portrait / short; portrait card sits between slip and rail (Back / Nations never covered, ux m-11) |
| ux M-05 nation highlight | FIXED (wiring) | `map.highlight_nation(n)` on choose, `map.clear_highlight()` on close / leave, guarded by `has_method`; falls back to `map.select(cap)` until the map agent lands it |
| ux B-04 event / ultimatum at 800x360 | FIXED | `TBPanel.open(... split)`: narrative scrolls, choice cards pinned (beside it wide, beneath it single column); hero chrome compacted below 480u |
| ux M-07 Decide later | FIXED | non-ultimatum events / proposals: tertiary "Decide later"; calls `hud.defer_event(uid)` if present, else toast + re-prompt after End Turn |
| ux m-08 Yield chip | FIXED | "−1 province: <place>" with down glyph |
| ux M-02 wide panels at < 480u | FIXED | `TBPanel.stacked/is_short`: PANEL and DRAWER become full-screen pages (Back arrow, tabs merged into the header, actions in the header, no footer); Nations / New game stack list then detail; Budget sliders 2 columns |
| ux m-01 Nations actions first | FIXED | Diplomacy / Intel above the facts |
| ux m-02 stale copy | FIXED | "command card" wording (EN / RU / UZ), rail + tab naming (`dk_advisor` = Council, tab `council_advice`), "Central Asian khanates" in era data and RU names |
| ux m-07 game-over chip | FIXED | below the top bar |
| ux m-10 briefing | FIXED | three figures as one chip row, advice moved to the left column |
| ux M-08 first-turn | FIXED | tutorial and briefing kept; Skip on the tutorial (or Esc / X) skips both (`TBModals.first_turn`) |
| art A-1 | PARTIAL | at most one primary per container (verified); luminance carrier on the primary button style belongs to the kit agent |
| art A-2 | FIXED (own screens) | `TBPanel.seg` (40 high, paper-2 + 3 px oxblood bar + bold) and new `ChipBtn`, pick rail chips, tier segmented; kit `K.segmented` still used by `menu_hub.gd` settings (not mine) |
| art A-3 | FIXED | glyph = sign, tone = meaning (`TBModals.delta_tone`, `true_minus`); infamy +4 is up / negative; comparison chips use warning / check / diamond; rating chips use check / diamond / warning |
| art A-9 (partial) | PARTIAL | portrait removed from the pick card and the briefing; still in the Nation card |
| art A-12 | FIXED | event `icon` fields are glyph ids; `TBChron.glyph()` maps old emoji; Annals / toast text carries no emoji. Engine fallbacks in `engine/events.gd`, `diplomacy.gd`, `decisions.gd` still hold emoji (not mine; mapped at render) |
| art A-11 (menus) | FIXED | no `Color(` literals left in the six files |
| a11y KBD-001 | FIXED | title, New game, Nations, Council, hub, pick: initial focus on a cold start (`TBPanel.wants_focus`), Up / Down / Tab / Enter / Space, Esc via `_on_back`; opener focus restored through a weak reference |
| a11y TXT-003 | PARTIAL | 150 %: only the Goals chip row was off screen before, 0 findings now at 540x960 / 800x360 for title, modals, confirm, pick; 200 %: title, New game, Nations, pick list, Council, confirm clean; remaining: Menu hub settings rows (kit agent's), Nations count label at 800x360 / 200 % |

## APIs other agents must call or provide
- Map agent: `map.highlight_nation(n: int)` and `map.clear_highlight()` (called with `has_method`).
- HUD agent: `hud.defer_event(uid: int)` (turns the pending event into an Event chip; falls back to toast).
- Everyone: `TBPanel.stacked(vs)`, `TBPanel.is_short(vs)`, `TBPanel.seg(items, cur, cb)`, `TBPanel.section(text)`, `TBPanel.wants_focus()`, `Handle.clear_actions()`; `TBPanel.open` options `split`, `split_wide`; `TBModals.event_prompt(parent, e, on_choose, g, on_defer)`, `TBModals.first_turn(parent, g, show_tutorial)`.

## Concerns
- `main.gd`: small edits outside the strict title / pick / back set: `_start_game` tail (one call) and `show_events` + new `_defer_event`.
- Shared `/tmp` and `user://` with other agents: use unique output directories for the matrix.
