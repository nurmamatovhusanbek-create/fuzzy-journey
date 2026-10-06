Accessibility: FAIL (10 blockers)

# Accessibility review, Phase 4 (/team-ui): Terra Bellum UI redo

Reviewer: accessibility-specialist (adversarial brief). Date: 2026-10-06. Branch `claude/ecstatic-gauss-f495v8`, HEAD `118c097`.
Governing document: `design/accessibility-requirements.md` (tier COMPREHENSIVE; 73 requirement IDs, 11 baseline defects D1-D11).
Scope: `godot/src/ui/*.gd`, `render/*.gd`, `globe.gdshader`, settings in `ui/main.gd` + `ui/menu_hub.gd`.

**Totals: 73 requirement IDs = 10 PASS / 32 FAIL / 19 NOT IMPLEMENTED / 12 NOT ASSESSED.** Of D1-D11: 3 closed, 3 partly closed, 5 open.
The redo fixed the token layer well (contrast, focus ring on every control, release-activation, semantic names, modal focus trap). It did not deliver the
Comfort/Comprehensive layer: there is no CVD mode, no 200 % text, no map high contrast, no map keyboard path, and the Reduce motion and Text size settings
do not reach the HUD or the map. The most serious defect is that the title screen cannot be operated by keyboard on a cold start.

## Evidence base (what was actually run or inspected)

| Evidence | Result |
|---|---|
| `tests/ui_contrast.gd` (headless) | 132 pairs (66 x NORMAL/HC), 0 failures, "UI CONTRAST PASS". Covers tokens only: no map labels, no translucent plates, no slider/legend swatches. |
| Screenshots `/tmp/claude-0/fin/en_1280x720_*.png` (25 screens) | Viewed title, nations, council, settings. |
| Regenerated at text scale 2.0 (540x960, 1920x1080) and 1.5 (540x960, 800x360) with `tests/ui_modals.gd`; harness overflow walker 48 findings at 200 %, 28 at 150 % | Viewed settings, confirm, title, nations. |
| `tests/hud_shots.sh` (5 viewports) and `tests/ui_cmdcard.gd` 1280x720 | Viewed lens/legend, alerts at 800x360, battle preview. |
| Scratch audit walk (my own script, not committed): every visible Control at 1280x720 and 540x960, text 100 %, plus HC at 1280x720 | Target sizes, focus_mode, names, font sizes. |
| Scratch keyboard run (Godot key events pushed into the viewport) on title, game (no overlay), settings modal, nations modal | Focus order and cold-start behaviour, see KBD-001. |
| Scratch name audit: 181 focusable controls across HUD, title, nations, settings, annals, council | 180 named, 1 plain `Control` unnamed. |
| Pixel sampler on `hud_sel_1280x720_s100_hc1.png` (97th-percentile text luminance vs 25th-percentile ground) | Indicative only, not the A11Y-CON-006 halo sampler. |
| Code inspection | text-size wiring, TBTokens.mode, reduce-motion consumers, tweens, InputMap/TTS grep, lenses, shader, MP timer, audio. |

Not run (and therefore NOT ASSESSED where they gate a criterion): RU/UZ and pseudo-locale matrices, device/notch/orientation tests, Machado CVD simulation, flash
analyser, loudness check, TTS (no TTS path exists), user testing (3 CVD / 2 low-vision / 2 motor / 1 screen-reader), 200-battle preview-vs-result check.

## Baseline defects D1-D11

| # | Status | Evidence |
|---|---|---|
| D1 toast contrast | CLOSED | Toasts use cream on `bar_0` (11.85:1); CON test green. "Alert" word still absent (minor). |
| D2 palette ratios | CLOSED | Tokens `ink_0/ink_1/oxblood/pos/neg/...` all pass in PAIRS; `brass_ink` text >= 5.7:1. |
| D3 focus | PARTLY | Rings exist on every control (theme `focus` stylebox + custom `_draw`); Tab works inside modals. But title has no focus entry (KBD-001), map has no keyboard path (KBD-004), Tab on the HUD is hijacked by army cycling. |
| D4 9-10 px text | PARTLY | Theme/Label fonts all >= 12 (walk found none < 12). Drawn text still 11 px: `map_labels.gd:504` "+n" army tab, `cmd_card.gd:257,260` hotkey badge, `main.gd:725` perf label. |
| D5 touch targets | PARTLY | Most plates now 48. Still short: see TCH-001. |
| D6 logical px != dp | PARTLY / NOT ASSESSED on device | `main.gd _px_per_unit` makes 1 u = dpi/160 on Android/iOS. `TBKit.dp_scale` is never set (always 1.0) and `ui: small` (k=1.18) shrinks text below 12 dp. No device or ruler test. |
| D7 ChoiceCard press-down | CLOSED | `panel.gd Card`: focusable, release-inside fires, Enter/Space via `ui_accept`. |
| D8 colour-only swatches | OPEN | Legend swatches, relation/war colours, owner fills still colour-only; no CVD palettes, no letters/patterns. |
| D9 sound / toast timing / `ui` size | OPEN | Sound is one on/off toggle; toasts replace each other with fixed 5-10 s; `ui` still a separate 3-step layout scale; text scale separate but 3 steps. |
| D10 theme-before-cfg / `animate` env var / ListRow clip | PARTLY | `_load_cfg` now runs before `_apply_a11y` (fixed). `TBMapView.animate` is still the env var `TB_NOANIM` and is what the HUD/map/ticker/panels consult (`hud_parts.gd:20`, `map_view.gd:24`). `panel.gd:488` still clips with `draw_string` width, no ellipsis. |
| D11 MP 120 s | OPEN | `mp_controller.gd:44` still passes `120`; no Off, no multiplier. |

## Requirement table

Gate: BLOCKING = fails a non-`[adv]` requirement (S2 per the standard). "(partial)" = some of the rule is met, the acceptance test still fails.

### Visual: text, contrast, colour vision

| ID | Status | Evidence |
|---|---|---|
| A11Y-TXT-001 | **FAIL** | (1) Settings offer 100/125/150 % only (`menu_hub.gd:189`); 200 % is unreachable from the UI although `main.gd:275` clamps to 2.0. (2) The HUD ignores the setting: `TBHudParts.text_scale` (`hud_parts.gd:9`) is only written by `hud.set_text_scale()` (`hud.gd:158`), which has no caller; likewise `TBCmdCard.text_scale` (`cmd_card.gd:8`) is never set. Screenshot at 200 % 1920x1080: modal text is huge while the ribbon, dock and alert chips are unchanged. (3) Map labels and army numerals use fixed 12/14 px (`map_labels.gd:151,186,498,548,604`). |
| A11Y-TXT-002 | **FAIL** | Theme fonts all >= 12 (walk). But 11 px drawn text remains (D4 row), HUD `P.fs()` has no floor, and `ui: small` makes everything about 10 dp. No `tools/a11y_audit.gd` min-font test exists. |
| A11Y-TXT-003 | **FAIL** | 540x960 (360x640 u) at 150 %: title wordmark, tagline and all four plates are wider than the screen (`ui_modals` findings, screenshot shows "TERRA BELL" cut off, buttons running off both edges); confirm dialog is wider than the viewport, Cancel and the primary button are clipped. At 200 % the same plus the Menu header, tabs row ("Saves Settings How to play H...") and every modal footer overflow horizontally. 800x360 at 150 %: title plates and pick card buttons off screen. Ribbon does not drop to 4 essentials; no `layout_for()` breakpoint keyed on text scale (only the `K.text_scale < 1.4` wide/narrow test). HUD alert chips and legend truncate with an ellipsis instead of wrapping ("Russian Empir...", `hud_parts.gd fit()`). |
| A11Y-TXT-004 | **FAIL (partial)** | `readable` toggle works for UI text (`K.display()` returns Alegreya Bold, `caps()` skips `to_upper`). But `map_labels.gd:105` caches a tracked display face (`_tracked`, spacing 2) and `hud_parts.gd f_nat()` caches one too, so nation names on the map stay tracked Cinzel after toggling; the wordmark never changes. Glyph coverage in EN/RU/UZ not tested (NOT ASSESSED). |
| A11Y-TXT-005 | **NOT ASSESSED** | Needs a 411x891 dp / 891x411 dp device or ruler shots. Code: `main.gd _px_per_unit()` implements 1 u = 1 dp from DPI on Android/iOS, but `TBKit.dp()` is unused and `dp_scale` is constant 1.0. The 2340x1080 `TB_UI_SCALE=2.6` emulation was not measured with a ruler. |
| A11Y-CON-001 | **PASS** | `tests/ui_contrast.gd`: all text pairs >= 4.5 (NORMAL) and >= 7 (HC); `ink_0` on paper 13.4:1. Caveat: the "screenshot sampling over translucent plates" half of the test is not built; map text is CON-006. |
| A11Y-CON-002 | **PASS** | PAIRS rows for control border (`rule` 4.06:1 on panel, 3.47:1 on control), focus ring, meter fills, markers all >= 3:1 / 4.5 HC. Slider rail is opaque `rule` border (`ui_kit.gd:281`). |
| A11Y-CON-003 | **FAIL** | Disabled text 4.00:1 / 3.41:1 passes the number, but there is no non-colour disabled cue (no hatch, no lock glyph; buttons fade by alpha, `ui_kit.gd:231`). A reason string exists for `Card` rows (inline) and `K.disable()`, not for every disabled control. |
| A11Y-CON-004 | **PASS** | Toasts, hover card, legend and alert chips are cream/brass on `bar_*` and tested; bad news carries a warning triangle + swords glyph. Minor: the word "Alert" is not shown on the toast (it is only in the feed text). |
| A11Y-CON-005 | **FAIL** | One HC switch (`contrast` bool, `TBTokens.mode`) is honoured by every UI screen I rendered (settings, HUD, province panel in HC are opaque, 2 px borders, no paper grain). Missing: the HC light + HC dark pair (only a light-paper/black-bar hybrid exists), the setting is a toggle not a 3-way theme, the map does not change at all (CON-007), 3-4 px focus ring in HC not implemented (same 2 px). |
| A11Y-CON-006 | **FAIL** | Visual: labels on pale fills are weak ("France" under gonfalons at 0.45 alpha, `map_labels.gd:140`; "Morocco", "Afghanistan"). Indicative sampler on the HC screenshot: "Afghanistan" 2.6:1, "Russian Empire" 3.2:1, "France" 3.9:1, "Morocco" 4.6:1 (a fixed cream + fixed `table` halo, not chosen from the underlying luminance). The acceptance sampler (10 lenses x 3 CVD x HC) does not exist. |
| A11Y-CON-007 | **NOT IMPLEMENTED** | `globe.gdshader` `theme` int is 0 standard / 1 parchment only; national border is a fixed 1.0-2.3 px dark line; `TBTokens.mode` never reaches the shader or `map_view._push_view()`. Turning on High contrast leaves the map pixel-identical. |
| A11Y-CVD-001 | **NOT IMPLEMENTED** | No `cvd` setting, no CVD palette arrays in `lenses.gd`; `STAB_RAMP` is still red-green (`lenses.gd:15`); `REL_COL` red/green/cyan; no `cvd_sim` tool. |
| A11Y-CVD-002 | **NOT IMPLEMENTED** | `refresh_nations()` is the historical colour + lerp only; no adjacency-aware palette. |
| A11Y-CVD-003 | **FAIL** | Present: nation names on the map, flag + name in the desktop hover card (`map_tip.gd`), flags on gonfalons, a searchable Nations list with "Show on map". Missing: border is a single dark 1 px line at far zoom (grows to 2.3 px only when zoomed in; the "light inner stroke" is a faint rim only at quality 2, `globe.gdshader:200-212`); greyscale and 10-province tests not run. |
| A11Y-CVD-004 | **NOT IMPLEMENTED** | No relation class channel, no ally/war/truce/rebel patterns or glyphs on territory. Only the occupied-land hatch and a red war border (colour-only) exist (`globe.gdshader:187,259`). Open Question 3 unresolved. |
| A11Y-CVD-005 | **NOT IMPLEMENTED** | `Legend` swatches (`hud_parts.gd:597-626`) have no letter/number/pattern; `_war_groups()` still hashed hue, no bloc letter. |
| A11Y-CVD-006 | **FAIL (partial)** | Present: net-gold arrows and signs, battle preview numerals + outcome sentence + triangle, alert chips with per-severity shapes and class glyphs, toast warning glyph, relation word + icon in the hover card. Missing: "You/Them" labels and win/lose icon on the bar, legend, meter low glyph, diplomatic chips, advisor badge shape vs count. Colour-as-only audit table still all "Not Started". |
| A11Y-CVD-007 | **FAIL** | Selection = tint + pulse (`globe.gdshader:189`, `sin(time*3)`); valid target = 12 % tint + 2 px outline, static; no dotted hatch/target glyph, no corner brackets. Focus ring (not colour-only) is fine. |
| A11Y-VIS-001 | **NOT IMPLEMENTED** | No "Show all labels" setting or tier factor in `map_labels.gd`. |
| A11Y-VIS-002 | **NOT ASSESSED** | Flash analyser not run. Code: pulses are 0.5 Hz / 0.25+0.45 s (compliant by inspection). The one-line pre-launch notice and Settings > Comfort retrieval do not exist. |

### Motor

| ID | Status | Evidence |
|---|---|---|
| A11Y-TCH-001 | **FAIL** | Walk at 1280x720 (hit area, logical units): nations list rows 316x40 (x94), era rows 292x38 (x13), Annals chips 37-84 x 40, ChipBtn/nation_button 40 (`panel.gd:594,623`), Segmented cells 46 (`ui_kit.gd:567`; budget presets, settings), top-right IconBtns 36x36 x5 with hit area 40 wide (`hud_parts.gd Hit._has_point` only widens x by 4; `hud.gd:126,230,233`), RowBtn 40/44 in lens/more popovers (`hud.gd:758,767`). Desktop/Windows touch gets 38-40 because `OS.has_feature("mobile")` gates the 48 (`nations_screen.gd:83`, `menu_parts.gd:173`). "Large targets" changes `K.touch()` only; the HUD (own sizes) ignores it. No `a11y_audit.gd`. |
| A11Y-TCH-002 | **NOT ASSESSED** | Sibling-gap audit not run. Confirm dialogs put Cancel (safe default) next to the danger button with a short gap, which is acceptable only because the dialog is the confirm step. |
| A11Y-TCH-003 | **FAIL** | `map_view.gd pick_at()` returns one province; no disambiguation sheet; gonfalon hit area not 48 dp (marker rects ~18 px, `map_labels.gd:340`). Tap slop 16 px on touch (not dp-based). |
| A11Y-TCH-004 | **PASS** | Budget modal has -/+ steppers (5 %) at 48 px beside each slider (`modals.gd:133,137`); completable with taps only. (No 1 % hold-repeat or numeric field: minor.) |
| A11Y-TCH-005 | **PASS** | Buttons use `ACTION_MODE_BUTTON_RELEASE`; `Card` and `Hit` fire on release inside the rect only; map pick on release with slop (`map_view.gd:418`). Right-click secondary pick fires on press (not a touch path). |
| A11Y-TCH-006 | **FAIL (minor)** | Tooltips on HUD readouts and the touch province peek exist only via hover or 450 ms long-press (`hud_parts.gd Hit._arm`, `map_view.gd _arm_peek`). No visible control for the peek on touch. |
| A11Y-GES-001 | **NOT IMPLEMENTED** | No pan pad, no +/- zoom buttons, no arrow/WASD pan, no `+`/`-` keys; `zoom_by` is only reached by pinch/wheel/magnify. Cannot zoom on a touch device without multi-touch. |
| A11Y-GES-002 | **NOT IMPLEMENTED** | No Provinces/Armies list, no next-army/next-alert buttons (Tab cycles armies only from the keyboard, `order_flow.cycle`). The Nations list exists. |
| A11Y-GES-003 | **FAIL** | Zoom needs pinch or wheel (GES-001), no `cfg.inertia` switch (flick is only suppressed by the env var). |
| A11Y-KBD-001 | **FAIL** | **Cold start: the title cannot be operated by keyboard or gamepad.** Test: fresh title, pushed Tab, Down, Enter, Space, Right, Esc: focus stays "none" after every key, no plate activates. Cause: Godot only moves focus from an existing focus owner, and `main.gd:224` focuses `plates[0]` only `if TBFrame.kbd_nav` (false until a key has already been pressed, and the menu is not rebuilt afterwards). Same pattern gates first focus in `pick_flow.gd:229`, `panel.gd:318`. In-game with no overlay, Tab is intercepted by `province_panel._input` to cycle armies, so dock, ribbon, seal and alert-chip buttons (all `FOCUS_ALL`) are not reachable by Tab; offer chips are also excluded from `A` (`hud.cycle_alert`). Modals are fine: Tab/Shift+Tab trap verified in Settings and Nations (30 presses wrap). Custom widgets implement `ui_accept`. No gamepad test. |
| A11Y-KBD-002 | **FAIL (partial)** | Modals: focus trap, Esc pops, opener refocus (`panel.gd:316`), primary or safe default (settings -> "Resume game", confirm -> Cancel) all verified. Failing: title and HUD focus order (KBD-001), and first focus is only set when the last input was the keyboard. |
| A11Y-KBD-003 | **FAIL (minor)** | Ring is drawn on all controls and is >= 3:1 (PAIRS), and shows only while navigating by keyboard (`TBFrame.kbd_nav`). But it is 2 px + 1 px contrast line (`frame.gd:282-293`, `hud_parts.focus_ring`), not >= 3 px / 4 px in HC, no corner-bracket shape, province panel/cmd card buttons draw 2 px inside the border (`province_panel.gd:392`). |
| A11Y-KBD-004 | **FAIL** | Implemented: Tab / Shift+Tab cycles own armies, then valid targets; Space selects; Enter confirms preview; Esc cancels; `1-4`, `[` `]` pick the send share; hotkeys M/R/H/G/B/C/D/U/W/P/T. Missing: arrow/D-pad province cursor, "Shift+Enter secondary", `,` `.` alerts, cursor marker. Consequence (SC 2.1.1): a province without an army (`g.army[p] > 1`) cannot be selected from the keyboard, so Recruit/Build/Colonize/Diplomacy on empty land and neutral provinces are unreachable. Arrow keys on the map: no effect (tested). |
| A11Y-KBD-005 | **FAIL** | Hotkeys exist (`hud.gd:971-1000`: F1-F6, L, A, N, B, D, Y; Enter = End Turn, Ctrl+Enter = force) but they deviate from the standard (Space/S/V/G/Home/F1 help absent, Alt+digits for lenses = chord), no `tb_*` InputMap actions (grep: none), no Controls page, hints not in every tooltip. |
| A11Y-KBD-006 | **NOT IMPLEMENTED** | No remapping UI, no `[keys]` persistence, no conflict handling. |
| A11Y-KBD-007 | **NOT IMPLEMENTED** | No `TBKit.prompt()`; hotkey badges are shown whenever `TBCmdCard.show_hotkeys`, not by input device. |
| A11Y-ONE-001 | **NOT ASSESSED** | Thumb-reach test needs a device. Observed: modal primary/back are in the pinned footer (`K.modal`, `panel.gd`), a close X is duplicated. The ribbon (read-only) is top; End Turn bottom-right. |
| A11Y-ONE-002 | **NOT IMPLEMENTED** | No handedness/dock-side, HUD scale, Simple HUD. |
| A11Y-HAP-001 | **NOT IMPLEMENTED** | No `Input.vibrate_handheld` anywhere. |

### Cognitive

| ID | Status | Evidence |
|---|---|---|
| A11Y-COG-001 | **NOT ASSESSED** | Anchors look consistent in the 5 HUD shots; no cross-language/orientation diff run. |
| A11Y-COG-002 | **NOT IMPLEMENTED** | Ribbon shows 7+ readouts at 1280 (nation, date, gold, manpower, wars, infamy, ...); no Simple HUD, no `hud` cfg key. |
| A11Y-COG-003 | **NOT IMPLEMENTED** | No `plain` setting, no `_plain` keys in `i18n.gd`. |
| A11Y-COG-004 | **FAIL** | Confirms exist for declare war, break pact, overwrite/delete/load save, leave to menu, End Turn with unspent orders (`hud.gd confirm_mode`), and name the consequence. Missing: undo (no command log; Open Question 2 still open), "Confirm all orders" setting, confirm for disband/raze and quit. |
| A11Y-COG-005 | **FAIL** | Every toast/alert/report is appended to `hud.feed` (`hud.gd:524`), but the feed is only shown as the last 8 lines in the "+n" drawer; the Annals modal (`TBModals.chronicle`) reads `g.log`, not the feed. Toasts do not queue (a new one replaces the old, `hud.gd:533`). Advisor badge persistence: yes (condition-driven). |
| A11Y-COG-006 | **FAIL (minor)** | Tutorial replay + Codex exist (`menu_hub _howto`, from the title and in-game). No per-screen "?" . |
| A11Y-COG-007 | **NOT ASSESSED** | 200-battle preview==result test not run; "advisor hints on/off" and "show consequences" settings absent. |

### Auditory

| ID | Status | Evidence |
|---|---|---|
| A11Y-AUD-001 | **NOT IMPLEMENTED** | One `sound` on/off bool, one `AudioStreamPlayer` pool on Master (`audio.gd:13`); no Music/SFX/UI buses or sliders. |
| A11Y-AUD-002 | **FAIL** | Twins exist for event (modal + chip + toast), war (chip + toast + red border), turn (toast); the Annals column of the twin table is not met (COG-005); no mute run performed. |
| A11Y-AUD-003 | **NOT ASSESSED** | No loudness measurement; no `AudioEffectLimiter` on Master (grep: none). `turn` is 1.1 s with exponential decay, `win` 0.5 s tail. |
| A11Y-AUD-004 | **PASS** | All partials in `_snd[]` are < 4 kHz (`tap` 1320/1980 Hz), and every cue has a visual twin as carrier. |
| A11Y-AUD-005 | **PASS** | `AudioStreamWAV.stereo = false`, no pan or spatial use. |
| A11Y-AUD-006 | **NOT IMPLEMENTED** | No "Visual alerts" strip/setting, not forced on when muted. |

### Motion, time

| ID | Status | Evidence |
|---|---|---|
| A11Y-MOT-001 | **FAIL** | The setting (`reduce_motion`) only sets `K.reduce_motion` (`main.gd:277`), which is consulted by `K.motion_ok()` in just three places: panel open/morph (`panel.gd:324,412`) and the sheet in `ui_kit.gd:926`. Everything else tests the env var `TBMapView.animate`: HUD seal pulse/busy bar/number counters (`hud_parts.gd:20,313,495,513,539`), ticker/info row tweens (`alert_ticker.gd:234-307`), province panel rise (`province_panel.gd:112`), map tip, map `fly_to`/`zoom_by`/hover-selection fades (`map_view.gd:225-296`), marching order dashes and label fades (`map_labels.gd:237,251,267,594`). Not honoured at all: title globe auto-spin (`main.gd:739`), flick inertia (`map_view.gd:286`), shader selection pulse `sin(time*3.0)` (`globe.gdshader:189`). Turning the setting on therefore changes almost nothing in the HUD or the map. |
| A11Y-MOT-002 | **FAIL** | (1) Screen/panel shake on a rejected order: `province_panel.gd:155-160` tweens `offset_left/right` +-4 px (explicitly banned). (2) Rolling-number counters: `hud_parts.gd Chip.set_num()` tweens the displayed value. (3) Looping decorative/progress animations: seal marching bar (`hud_parts.gd:545`), title spin, marching order dashes. Single transitions are 100-200 ms (compliant). |
| A11Y-MOT-004 | **NOT IMPLEMENTED** | No `turn_speed`, no skip signal; end-turn resolves on a thread (`_turn_thread`), battles are staggered 0.22 s each unless animate is off (`hud.gd:561`). |
| A11Y-TIM-001 | **PASS** | No timers, auto-advance or reflex input in single-player/hot-seat (grep). |
| A11Y-TIM-002 | **FAIL** | `mp_controller.gd:44` hard-codes `create_room(..., 120)`; `net/room.gd:11 turn_secs := 120`; no Off option, no per-player x1.5/x2/x3, no 25 % warning. (Open Question 4 unresolved.) |
| A11Y-TIM-003 | **FAIL** | Duration formula matches (5 s + 50 ms per char over 40, `hud.gd:537`; 120 chars = 9 s) but capped at 10 s, no "keep alerts until dismissed", no hover/focus pause, replaced not queued, not mirrored to Annals. |
| A11Y-TIM-004 | **FAIL (partial)** | Hot-seat curtain exists (`modals.pass_device`: opaque dialog, no timer, focus on "Ready" button when keyboard). The button is a standard 48 px primary, not >= 56 dp; no TTS announce. |

### Screen reader, localisation, safety, settings

| ID | Status | Evidence |
|---|---|---|
| A11Y-SR-001 | **PASS** | `TBKit.a11y()` (`ui_kit.gd:53`) and `Hit.set_a11y()` store meta + tooltip; name audit 180/181 focusable controls named (one anonymous plain `Control` in the HUD). Note: names appear on hover/long-press only, not on keyboard focus; AccessKit binding is a 4.5+ item (NOT ASSESSED). |
| A11Y-SR-002 | **FAIL** | Hover card is four lines (flag + place, owner + relation, army + terrain, attack note) not a one-sentence description; no stability or lens value; touch only via long-press peek. |
| A11Y-SR-003 | **FAIL** | Annals shows `g.log` with categories (Mine/All/War/Diplomacy/Events), a 40-row limit + "older", jump-to-province on rows with a province. Not met: toasts/alerts are not in it (COG-005), plain text rows are not focusable (`panel.gd` entry `interactive` only with a jump), no copy/export, no live strip semantics, the feed that does contain toasts is capped to the last 8 in the drawer. |
| A11Y-SR-004 | **NOT IMPLEMENTED** | The only TTS code is a dead hook: `hud.gd:48` `tts_mode := "off"` is never set from any setting (`grep tts_mode`: 2 hits, both in hud.gd) and speaks only new alert chips (`hud.gd:498`). No focus speech, rate/voice, no first-run offer, no Esc stop, no UZ fallback warning. |
| A11Y-SR-005 | **NOT ASSESSED** | State is shown as words (toggles read "On"/"Off", budget % values, inline disabled reasons: seen in screenshots); nothing is announced because there is no TTS to test with. |
| A11Y-LOC-001 | **NOT ASSESSED** | Only EN was rendered; no `qps` pseudo-locale in `i18n.gd`; RU +35 % matrix not run. |
| A11Y-LOC-002 | **NOT ASSESSED** | No glyph coverage test; plain/readable variants per language missing (`plain` absent). |
| A11Y-LOC-003 | **FAIL** | Essential text is truncated by drawn `fit()`/`draw_string` width: alert chips, legend labels, ListRow/ToggleRow (`panel.gd:488`), menu plates (`menu_parts.gd:73,78`), cmd-card cost line (`cmd_card.gd:352`); nations list names show "Ottoman E..." at 200 % with no full-text tooltip. |
| A11Y-LOC-004 | **NOT IMPLEMENTED** | No `layout_direction`/`text_direction` use; no mirrored pseudo-locale. |
| A11Y-SAF-001 | **NOT ASSESSED** | `main.gd _apply_safe_area` uses `get_display_safe_area()` and a `TB_SAFE` emulator (works in the 540x960 / 2340x1080 HUD shots); no device/notch run; the "Extra margin 0/8/16 dp" setting does not exist (minor). |
| A11Y-SAF-002 | **NOT ASSESSED** | No rotate-during-modal test. 360x640 u is the 540x960 harness size and fails at text >= 150 % (TXT-003). |
| A11Y-SET-001 | **PASS** | Existing a11y keys (`text_scale`, `readable`, `reduce_motion`, `touch_large`, `contrast`) persist in `user://settings.cfg [tb]` and `_apply_a11y()` runs in `_ready()` before the title is built (`main.gd:31-34`, D10 order fixed). Scope: only those five keys exist; `[keys]` and all missing settings are counted under their own IDs. |
| A11Y-SET-002 | **FAIL** | Title: Settings is 1 tap, any setting is then 2 (OK). In game: dock More (1) -> Settings (2) -> setting (3) (or Esc -> hub tab -> setting). No first-run "Comfort and access" page, no jump chips, one long two-column page instead of the 5-tab IA (Display / Controls / Sound / Comfort / Game), "Reset accessibility" runs without a confirm and does not reset volume/etc. (nothing else exists to reset). |

### Settings IA coverage (standard section "Settings screen information architecture")

Present: Language, Text size (3 of 4 steps), Layout scale (`ui`), Map view/Quality/Perf overlay, Map style (Standard/Parchment, not HC), Readable fonts, Large touch targets, High contrast
(single toggle), Reduce motion, Sound (one toggle), Reset accessibility. Absent: HUD scale, UI theme variants, Colour vision, Always show labels, Brightness, Handedness, Navigation pad, Map inertia,
Key bindings, Haptics, Safe-area margin, Volume sliders, Soft sounds, Visual alerts, Turn speed, Alerts stay, HUD detail, Plain language, Confirm all, Self-voicing, Photosensitivity notice, MP timer multiplier.

## Prioritised fix list

### BLOCKER (gate: must be closed or waived by the producer)

1. **B1 - Title and first screen are not keyboard/gamepad operable (KBD-001/002).** `main.gd show_menu()` line 224: always `grab_focus.call_deferred()` the primary plate when the input device is not touch (drop the `kbd_nav` guard) or add `_unhandled_key_input` on the title that, on any of Tab/arrows/Enter/Space, focuses `plates[0]` and sets `TBFrame.kbd_nav = true`. Do the same in `pick_flow.gd` (line 229), `panel.gd _focus_first` caller (line 318) and the menu hub open. Move the Tab hijack: `province_panel._input` should only cycle armies when the map has focus (e.g. after Space/`G`), otherwise let focus traversal reach the HUD (`hud.gd` set `focus_neighbor_*` along dock -> ribbon -> chips -> seal). Add `hud.cycle_alert` to include offer chips or make offer buttons focusable in order. Test: scripted keyboard run title -> new game -> pick nation -> play 1 turn with no mouse.
2. **B2 - Map has no keyboard or single-pointer route (KBD-004, GES-001, GES-002, TCH-003).** (a) `map_view.gd`: add `_unhandled_key_input` for arrows = move selection to the neighbour province nearest in that bearing (needs the neighbour graph from `TBGame`), Enter = `province_picked`, Shift+Enter = secondary, `,` `.` previous/next alert, `[`/`]` already used by share (move to Alt) or keep as army cycle; draw a static cursor ring in `map_labels.gd` using `map.focus_province` (already exists). (b) New `ui/nav_pad.gd` (`TBNavPad`): 4 arrows + recenter + `+`/`-` calling `map.drag_by()`, `map.zoom_by(1.4, true)`, `map.fly_to()`; auto-on at text >= 150 % or large targets; `+`/`-`/WASD/arrow-pan actions. (c) New "Provinces / Armies" list modal (searchable, sorted by name/alert) built with `TBPanel` like `nations_screen.gd`, selecting a row calls `main._goto_province`; add "Next idle army" button in the province panel. (d) `map_view.pick_at()` returns a candidate list within `dp(12)`; open a `TBPanel` sheet when >= 2 candidates for provinces < 24 dp.
3. **B3 - Text size does not meet TXT-001/002/003.** (a) `menu_hub.gd:189`: add the 200 % step (`["2.0","200%"]`) and `_scale_id()`. (b) One source of truth: make `TBHudParts.fs`, `TBCmdCard.fs`, `map_labels` font sizes and every `draw_string` call read `TBKit.text_scale` (delete the two private statics, call `hud.build()` + `panel.rebuild()` from `main._apply_a11y()`; apply `fs()` in `map_labels.gd:151,186,498,504,548,604`, `cmd_card.gd:257,260`, `order_flow.gd:345`, `stat_chart.gd`). (c) Replace the 11 px literals with `TBKit.fs(12)`; clamp `TBHudParts.fs()` and `TBKit.fs()` to `TBKit.min_font()`; keep `ui: small` from lowering the floor (compute `min_font()` from `dp_scale` set in `_update_ui_scale`). (d) Reflow: in `modals.gd`, `menu_hub.gd`, `pick_flow.gd`, `main.gd show_menu()` set `custom_minimum_size.x` only from `viewport` bounds, wrap titles (`autowrap`), and give the title/menu plates `size_flags` + max width = `vs.x - 24`; add the ribbon "more" chip (hud `layout_for()`) when ribbon height > 20 % of the screen. (e) Run the screenshot matrix at 540x960, 360x780 dp, 1920x1080, 2340x1080 x 100/200 % and require the overflow walker to report 0.
4. **B4 - Reduce motion must be honoured everywhere, and the banned motion removed (MOT-001/002).** Redefine `TBHudParts.reduced_motion()` and every `TBMapView.animate` read (`hud_parts.gd:20`, `alert_ticker.gd`, `province_panel.gd:112,155`, `map_tip.gd:70`, `map_labels.gd:237-267,594`, `map_view.gd` select/fly/zoom/inertia) as `not TBKit.motion_ok()` (keep the env var only as a test override inside `motion_ok`). Add a shader uniform `motion` multiplying the `sin(time*3.0)` term (`globe.gdshader:189`, set in `map_view._push_view()`), skip title spin when reduced (`main.gd:739`), disable flick inertia and use cut `fly_to`. Delete the rejection shake (`province_panel.gd:155-160`, keep the 120 ms outline flash), make `Chip.set_num` set the value immediately (no counter), replace the seal marching bar with the static three-block form always. Test: idle frame-diff = 0 changed pixels after settle with the toggle on.
5. **B5 - No colour-vision support and colour-only encodings on the map and legend (CVD-001..007, D8).** Add `cvd` setting (Off / Deuteranopia / Protanopia / Tritanopia) and per-mode palette tables in `lenses.gd` (viridis-like monotone ramps replacing `STAB_RAMP`, Okabe-Ito categorical sets for `REGIME_COL`/`BUILD_COL`/`TERRAIN_COL`, orange/blue relation set), adjacency-aware greedy colouring in `refresh_nations()`; `TBTokens` semantic CVD variants for `pos/neg`. Write the relation class (own/ally/war/truce/rebel) into the `pal` texture (resolve Open Question 3) and add screen-space hatch/dash patterns in `globe.gdshader` plus glyphs in `map_labels.gd`; use a static pattern for valid targets and selection brackets (CVD-007). `hud_parts.gd Legend`: draw a letter/number or pattern inside each swatch and ticks with numbers on ramps; `lenses._war_groups()` returns a bloc letter shown at the nation label. Build `tools/cvd_sim.gd` and the greyscale/10-province test; update the colour-as-only audit table to Done.
6. **B6 - High contrast is incomplete (CON-005/006/007).** Split `contrast` into `ui_theme` {paper, hc_light, hc_dark} (`TBTokens` third dictionary) plus `map theme` {standard, parchment, high contrast}; push `TBTokens.is_hc()` into `map_view._push_view()` as shader `theme = 2` (>= 2.5 px double national border, 3 px selection, sea/land luminance gap >= 3:1). In `map_labels.gd` choose the label colour and halo from the fill luminance (`TBLenses.color(p)`) and draw an opaque plate under labels in HC; remove the 0.45 alpha under gonfalons. Build the CON-006 sampler (10 lenses x 3 CVD x HC) and require >= 4.5:1. 4 px focus ring in HC (`frame.gd _draw_focus`).
7. **B7 - Touch targets (TCH-001, D5).** `panel.gd:594,623` and `nations_screen.gd:83`, `menu_parts.gd:173`, `ui_kit.gd:567,603`: use `K.touch()` for height always (not only on mobile); Segmented cell = `K.touch()`; `hud_parts.gd Hit._has_point` must expand both axes to >= `K.touch()` (e.g. grow by `max(0, (touch - size)/2)`); IconBtn `sq` 36 -> hit rect 48; HUD popover rows (`hud.gd:758,767,779`) = `K.touch()`; make `K.touch_large` affect HUD `sq`/`chip_h`. Write `tools/a11y_audit.gd` (headless walk over every screen) and put it in CI.
8. **B8 - Multiplayer timer (TIM-002, D11).** `mp_controller.gd:44` add a timer picker (Off default / 60 / 120 / 180) before `net.create_room(...)`; pass 0 for Off; add the per-player multiplier to the room handshake (`net/room.gd turn_secs`, server side per Open Question 4); 25 % warning that persists until acknowledged. Until the server supports it, hide the timer for Off rooms and document the limit.
9. **B9 - Text mirror and self-voicing (SR-003/004, COG-005).** `TBModals.chronicle` must read both `g.log` and `hud.feed` (merge by turn, newest first), make every row focusable (`focus_mode = FOCUS_ALL`, a11y name), add a Copy button (`DisplayServer.clipboard_set`) and an "Alerts" filter; keep >= 500 entries. Add `tts` / `tts_rate` / `tts_voice` to `cfg` and Settings > Comfort, wire `hud.tts_mode` from it, speak on focus change (`focus_entered` for Controls with `a11y` meta), new Annals lines, turn start, hot-seat seat; `tts_stop()` on Esc; check `tts_get_voices_for_language()` and show a warning when UZ has no voice.
10. **B10 - Audio channels (AUD-001/006/002).** `audio.gd`: create `Music`, `SFX`, `UI` buses with `AudioServer.add_bus`, sliders + steppers in Settings > Sound (0-100, default 80, persisted `vol_*`), keep the mute toggle; add an `AudioEffectLimiter` on Master; add the "Visual alerts" strip (forced on when muted) fed from `hud.toast()`; complete the twin table (Annals column) and run the muted 20-turn playthrough.

### MAJOR

11. **KBD-005/006/007 - remapping and shortcuts.** Define `tb_*` actions in `main.gd _ready()` (`InputMap.add_action` + default events per the standard: Space end turn, Esc, F1 help, L, N, B, D, A, G, V, S, Home, `+`/`-`, 1-4), convert `hud.gd:971-1000` and `province_panel.gd` keys to `event.is_action_pressed("tb_*")`, add Settings > Controls page (click-to-capture, conflict warning with swap, Reset, `[keys]` section via `var_to_str`), and `TBKit.prompt(action)` for glyphs by last input device.
12. **COG-004 - undo + remaining confirms.** Engine: command log in `TBGame.apply()` with `undo_last()` (resolve Open Question 2); visible Undo button in the HUD/province panel; add "Confirm all orders" setting; confirm for disband/raze and quit.
13. **TIM-003/TIM-004.** `alert_ticker.show_info()`: queue instead of replace (max 5 stacked), pause on hover/focus, `toast_sticky` setting, mirror to the Annals; hot-seat curtain button `custom_minimum_size.y = max(56, touch())`, announce the seat via TTS.
14. **SET-002 / first run.** `modals.settings()` rebuilt as the 5-tab page (Display / Controls / Sound / Comfort / Game) with jump chips; add the first-run "Comfort and access" screen (text size preview, contrast, colour vision, reduce motion, TTS, sound) with Skip; "Reset accessibility" behind `TBPanel.confirm` and covering all new keys; photosensitivity one-line notice (VIS-002) retrievable under Comfort.
15. **COG-002/003, ONE-002, VIS-001.** Simple HUD preset (<= 5 readouts, `cfg.hud`), `plain` setting + `*_plain` strings with the `TBI18n.T` lookup, handedness/dock side + HUD scale, "Show all labels" label tier factor.
16. **CON-003 / TXT-004.** Hatched face or lock glyph for disabled controls and a reason string on every disabled button; rebuild `map_labels._tracked` and `hud_parts._f_nat` when `readable` changes (do not cache across the toggle).
17. **LOC-003.** Replace truncating `fit()`/`draw_string` width on essential text by wrapping `Label`s with `OVERRUN_TRIM_ELLIPSIS` and a full-text tooltip/focus readout; add the `qps` pseudo-locale (+60 %) to `i18n.gd` and run it with the RU matrix (LOC-001/002).
18. **SR-002 / GES-003 / TCH-006.** One-sentence province description (<= 25 words) shared by tooltip, TTS and the hover card; `cfg.inertia` toggle; visible "i" button for the touch peek and HUD tooltips.

### MINOR

19. Focus ring 3 px (4 px HC) plus corner brackets (`frame.gd _draw_focus`, `hud_parts.focus_ring`, province panel buttons `province_panel.gd:392`); show the accessible name as a tooltip on keyboard focus (`Hit` focus_entered -> `tip_on`).
20. "Alert" word on bad toasts (`alert_ticker InfoRow`), "You"/"Them" labels and win/lose icon on the battle bar (`hud.gd:1021-1040`), meter low-value glyph.
21. Large-targets setting should scale HUD `sq` and `chip_h`; budget stepper hold-repeat and numeric field; safe-area "Extra margin" setting; `Reset accessibility` confirm.
22. Haptics (HAP-001) via `TBHaptics.play(kind)` (mobile only); turn-speed setting and skip (MOT-004); per-screen "?" help (COG-006).
23. Replace the scratch audit walk by committed `tools/a11y_audit.gd`, `tools/cvd_sim.gd`, `tools/pseudo_loc.gd` and a keyboard-run script (Tab/Enter) in `tests/`, and record the user-testing report under `production/qa/accessibility/` (not yet filed).

## Phase-4 checklist status

| Checklist line | Result |
|---|---|
| D1-D11 each verified closed | No (3 closed, 3 partly, 5 open) |
| A11Y-TXT: four sizes on every screen at four viewports | No |
| A11Y-CON: PAIRS green; HC light + dark complete (menus and map); toasts/banner/legend fixed | Partial: PAIRS green, toasts fixed; HC dark and map HC missing; legend colour-only |
| A11Y-CVD | No |
| A11Y-TCH | No |
| A11Y-GES | No |
| A11Y-KBD | No |
| A11Y-SR | Partial (helper yes; Annals mirror and TTS no) |
| A11Y-AUD | No |
| A11Y-MOT/TIM | No |
| A11Y-COG | No |
| A11Y-LOC/SAF | NOT ASSESSED |
| A11Y-SET | Partial (persistence yes) |
| Per-feature matrix all "Addressed" | No |
| User-testing report filed | No |
| Known limitations accepted | Pending (creative director + producer, Open Question 6) |

Recommendation to Producer: report B1-B10 as release-blocking. B1 (title keyboard entry) and the HUD half of B3 (text scale not reaching the HUD) are one-day fixes and should be done first because they currently
make the shipped settings appear to work while not working (Text size and Reduce motion produce little or no change on the HUD and map).
