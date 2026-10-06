# UI modals, menu hub, title and pick flow: report

Scope: panel.gd (new container system), nations_screen.gd, menu_hub.gd, newgame.gd, pick_flow.gd (new), modals.gd, menu_parts.gd, stat_chart.gd (rewritten), main.gd (localised edits), i18n (129 keys x 3 languages), tests.

## Container system (panel.gd, `TBPanel`)
One factory `TBPanel.open(parent, Kind.DIALOG | DRAWER | PANEL, title, glyph, opts)` returning a `Handle` (body, footer, set_chip, set_tabs, actions(secondary, primary)).
Presentation resolved from the viewport: Dialog (centred, wide dialog 700 on landscape), Drawer (landscape right rail, non-modal) / Sheet (portrait, snap 56 / 92 %, handle, blocks map above 60 %), Wide panel (clamp(0.9 vw, 640, 960) x min(0.88 vh, 600)) / Page (portrait, header Back arrow).
Anatomy: header (glyph, title, context chip, X), tab row (scrolls sideways when it overflows), scrolling body, pinned footer (secondary left, primary right, no Back button). Plain panels have no ornament; only `hero` dialogs use the hero sheet.
Pop-stack: `TBPanel.pop(overlay)` returns none / back / closed / locked. X, Esc and Android Back all call it; `locked` = unanswered event / game over / pass-device. Tab and arrows trapped in modal kinds, `[` `]` and Ctrl+Tab switch tabs, focus restored to the opener, one panel at a time (a new panel replaces the old one), at most one dialog above it.
Shared widgets: Card (command-card look with effect or cost chips), ChipBtn (selected = fill + check), Entry (flat wrapping row), ToggleRow (P-14), confirm (L1/L2, default focus Cancel), flag_tag, empty_state, facts_grid.
Drawer geometry constants (`DRAWER_TOP`, `DRAWER_BOTTOM`, `SHEET_BOTTOM`) are at the top of panel.gd for the HUD agent to tune.

## Screens
- Nations (`TBModals.nations_screen`): master-detail; search, filters (All, Neighbours, At war, Allies), sort, all rows (no cap; "Showing x of y" when filtered), nation card (ruler, facts grid with ranks, allies / enemies as flag buttons that jump, Diplomacy cards with dp cost chips and disabled reasons, red Declare war with confirm, Intel cards). Tab 2 Rankings: metric segmented, chart / table toggle, legend chips toggle series, dash patterns and end labels. Portrait: list page, then detail page with Back arrow. Pick mode: tier filters and "Play as X" footer.
- Council (`council`): drawer, tabs Advice (sorted by severity, shape glyphs, whole row jumps) and Goals (top 3, "All goals", realms over 25 %).
- Menu hub (`menu_hub`): tabs Saves (Save / Load, 5 slots + autosave, overwrite and load confirm, unreadable-slot delete), Settings (Display, Interface incl. text size 100/125/150, Language, Audio, Accessibility: high contrast, reduced motion, large targets, readable fonts; Advanced), How to play (Codex master-detail + tutorial replay), Honours (filters, how-to-earn, progress meters). In a running game the footer is [Main menu] (L2 confirm with "Save and exit") and [Resume game].
- New Game page (`new_game`): chronology rail, era detail with great powers as flag chips, difficulty, Players 1-4 (hot-seat folded in; title Hot-seat entry removed), footer "Pick a nation". Page on portrait (list, then detail).
- Pick (`TBPickFlow`): Back, instruction slip with three step pips, List, tier segmented + shortlist rail (Random first), non-modal confirm card (ruler, size rank, army, tech, government, start-difficulty chip with reason, "Play as X", 300 ms tap guard), hot-seat seat badges and "taken" state, `R` = random.
- Title: bezel ring kept (flat dark disc, alpha 0.78), light-on-dark text on the globe, plates (Continue with subline, New Game, Load "n saves" / disabled "No saves yet", Multiplayer), tools row (Honours n/19, Settings, How to play, EN | RU | UZ live), version. Panels over the title stop the spin and dim the ring to 35 %.
- Event / ultimatum: hero sheet, narrative left, neutral choice cards with effect chips (arrow glyph + colour, infamy inverted), ultimatum strength chips and "War with X"; Game over: hero sheet with the wax stamp, key numbers, top 5 + You, [View final map] (hides, chip brings it back), [Main menu]. Briefing and Tutorial kept (dialogs). Pass-device curtain: opaque, swallows Back.
- Budget (drawer / sheet): net chip with delta, four sliders with -/+ 5 steppers and effect lines, presets, [Revert] [Done]. Decisions: doctrine left, Active / Available / Unavailable right, cost chips, locked reasons. Annals: filter chips, rows grouped by turn, whole row jumps, "Show older" instead of a silent cap.

## main.gd (localised)
Entry points (marked block "UI ENTRY POINTS"): `_open_nations(select := -1, filter := "", tab := "")`, `_open_nation(n)`, `_open_council(tab)`, `_open_budget()`, `_open_decisions()`, `_open_annals()`, `_open_menu_hub(tab)` (tabs saves | settings | howto | honours), `_open_settings()` (alias). The nine dock `connect` lines in `_ready` now call these one-liners.
Also changed: cfg defaults (era, players, text_scale, readable, reduce_motion, touch_large, contrast), `_apply_a11y()` after `_load_cfg`, `show_menu`, `_open_era_picker`, `_begin_pick`, `_show_pick`, `_open_pick_list`, `_confirm_pick`, `_pick_nation_from_list`, pick branch of `_on_pick`, the curtain in `_hot_switch`, `_on_back`, `_unhandled_key_input` (Esc = `_on_back`).
`_on_back` order: top panel / dialog (locked ones toast "Choose an option") -> legacy multiplayer dialog -> optional `_cancel_order_back() -> bool` hook (define it in the order code to take step 2 of P-20) -> mode: title arms "Press Back again to exit" (2 s), pick closes the card then goes back to New Game, game deselects then opens the menu hub.

## Tests
`tests/ui_modals.gd` (screenshot matrix of 25 screens, overflow walker, args: outdir, lang, sizes, `scale=1.5`, `only=`). `tests/ui_back.gd` (Back stack) added to `tools/test_ui.sh`; ui_hotseat checks the curtain swallows Back. Removed obsolete one-off screenshot scripts that called deleted APIs (ui_sheet, ui_lint, pick_list, ui_shots*).
Captured and inspected: EN at 1280x720, 1920x1080, 800x360, 540x960; RU at 1280x720, 540x960 and RU at 150 % text on 540x960 / 1280x720.

## Known gaps
- Nation tint / dimming of the rest of the map on pick and the tap magnet need map_view changes (not owned here).
- Tutorial stays a dialog (CD decision), not coach marks.
- Save slots use the file modified time for the date and a glyph tile instead of the flag (meta lacks code / colour; engine untouched).
- K.modal is still used by mp_controller (multiplayer lobby dialogs); `_on_back` handles it as a legacy container.
