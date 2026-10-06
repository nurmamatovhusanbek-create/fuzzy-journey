# Interaction Pattern Library: Terra Bellum

> **Status**: Draft
> **Author**: ux-designer
> **Last Updated**: 2026-10-06
> **Version**: 0.1
> **Engine**: Godot 4.4 (GDScript, GL Compatibility)
> **UI Framework**: Godot Control nodes, procedural drawing (`TBKit`, `TBFrame`, `TBGlyph`), no image assets
> **Accessibility Tier**: Comprehensive
> **Related Documents**: `design/game-brief.md` (pillars), `hud.md` (zones A-G, units `u`, End Turn, ticker), `command-card.md` (verbs, order flow), `modal-system.md` (containers), `main-menu.md`, `nation-pick.md`
> **Template**: Interaction Pattern Library

> Scope: this file specs **behaviour, sizes and structure**. Colour, material and ornament belong to art-director; the only visual rule imposed here is the *decoration budget* (`modal-system.md` 5.6, same budget as `hud.md` 1). Direction (creative director): keep the paper-table language, but read as a **command table** (Total War / HoI4): grouped info chips, orders on the map, panels that confirm and explain.

---

## 1. Overview

**Governing rules** (derived from the pillars; every pattern below obeys them)

| # | Rule | Pillar |
|---|------|--------|
| R1 | A verb that changes the world is a map gesture plus an on-map preview. Panels host parameters and explanations, never the main verb. | 2 |
| R2 | Irreversible or war-starting actions are always previewed, then confirmed by a second explicit act. Reversible ones commit at once with an Undo toast. | 2, 4 |
| R3 | A number is shown only with a reason it matters (delta, threshold, cost, comparison). Costs are chips; unaffordable = chip with an X glyph plus colour. | 3 |
| R4 | Never colour alone: every state pairs colour with a shape, glyph, sign or text (RED/GREEN/STEEL on paper are redundant channels). | Accessibility |
| R5 | One management panel at a time (drawer / sheet / wide panel), at most one dialog above it; the command card is not a panel. Panels never stack. | 1 |
| R6 | Disabled never means silent: activating a disabled control states why, in a tooltip/toast with a glyph. | 3 |
| R7 | Text floor 12 logical px (body 15-16, captions 12). The current 9-11 px caps captions are non-conformant. | Accessibility |
| R8 | Everything reachable by touch, mouse and keyboard; focus is always visible (today `focus_mode = FOCUS_NONE` everywhere: gap). | Accessibility |

**Naming and units are shared with `hud.md`** (the source of truth for zones and sizes): all sizes are `u` (logical px, about 1 dp on phones, 1.5 px on 1080p desktop); zones **A** top bar ("ribbon"), **B** screens rail ("dock"), **C** alert ticker, **D** command card, **E** End Turn, **F** legend, **G** hot-seat strip. Reference viewports: D 1280x720u, L 900x415u, S 800x360u, P 360x640u. HUD owns the HUD shortcuts (`A` next alert, Enter/Space End Turn, "Confirm End Turn: Smart") and the Turn report; this file owns panel-level behaviour.

## 2. Pattern Catalog Index

| ID | Pattern | Category | Used in | Status |
|----|---------|----------|---------|--------|
| P-01 | Selection and Hover | Map | Map, nation pick | Draft |
| P-02 | Order / Preview / Confirm | Map | Move, attack, recruit, ultimatum | Draft |
| P-03 | Command Card (rules; spec in command-card.md) | Map / Layout | Any selection | Draft |
| P-04 | Info Chip (readout) | HUD | Ribbon, cards, rows | Draft |
| P-05 | Alert Chip | HUD / Feedback | Top-left zone | Draft |
| P-06 | Toast | Feedback | Outcomes, log lines | Draft |
| P-07 | Tooltip (hover / focus / long-press) | Feedback | Chips, buttons, disabled reasons | Draft |
| P-08 | Dialog / Drawer / Sheet / Page | Container | All 15+ screens (see modal-system.md) | Draft |
| P-09 | Tab Bar | Navigation | Nations, Council, Saves, Settings | Draft |
| P-10 | Segmented Control | Input | Filters, difficulty, players | Draft |
| P-11 | List Row | Layout / Input | Nations, Annals, Saves, Honours | Draft |
| P-12 | Slider | Input | Budget | Draft |
| P-13 | Stepper | Input | Troops, players, budget fine-tune | Draft |
| P-14 | Toggle | Input | Settings | Draft |
| P-15 | Number Roll | Feedback | Ribbon chips | Draft |
| P-16 | Confirmation of Destructive Actions | Feedback | Overwrite, war, abandon | Draft |
| P-17 | Loading / Busy | Feedback | End turn, era load | Draft |
| P-18 | Empty State | Feedback | Lists, search | Draft |
| P-19 | Error State | Feedback | Rejected orders, save failure, MP | Draft |
| P-20 | Back Navigation | Navigation | Android Back, Esc, X | Draft |
| P-21 | Focus Order and Shortcuts | Navigation | Everywhere | Draft |
| P-22 | Button and Meter basics | Input / Feedback | Everywhere | Draft |

## 3. Shared Standards

**Size classes** (profiles of `hud.md`; computed from viewport in `u`, input type and physical size, never from logical width alone)

| Profile | Viewport (u) | Min touch target | List row |
|---------|--------------|------------------|----------|
| D desktop / tablet | 1280x720 (pointer) | 32 mouse, 48 touch | 36 |
| L landscape phone | 900x415 | 48 | 48 |
| S short window | 800x360 | 48 | 48 |
| P portrait phone | 360x640 (to 411x891) | 48 | 52 |

Targets 48u touch, 32u mouse, text 12u minimum (hud.md). Draw glyphs at 24-28u, keep the hit area at 48u. The code still uses fixed 1280x720 / 540x960 base sizes with `MIN_TOUCH = 44`, which is about 4 mm on a 2340x1080 phone: the `u` mapping (px per u from DPI) must replace `_update_ui_scale` (hud.md Q1).

**Timing** (reduced-motion column replaces slides/scales by a fade at 50 % duration, stops loops)

| Animation | ms / easing | Reduced motion |
|-----------|-------------|----------------|
| Hover / focus enter / press tint | 80 out / 60 | none |
| Dialog open / close | 160 cubic-out / 120 in | fade 80 |
| Drawer slide / sheet rise | 180 / 200 cubic-out | fade 80 |
| Tab content swap | 120 crossfade | instant |
| Toast in / out | 160 / 160 | fade 80 |
| Number roll | 400 out | instant swap |
| Selection pulse (once) | 240 | static ring |
| Ghost-arrow dash march (loop) | 1000 linear | static dashes |

**Audio** (existing `TBAudio` ids): `tap` (any press), `coin` (spend), `turn`, `event`, `war`, `alert`, `win`. Add `cancel`, `error`, `confirm`. Sound is never the only channel.

**Accessibility baseline all patterns inherit**: contrast 4.5:1 text, 3:1 UI edges/glyphs (computed approx. on laid paper: TEXT 12:1, DIM 4.9:1 on PANEL but 4.1:1 on PANEL2, GOLD 3.8:1, GREEN 4.2:1 and the 28 %-alpha locked Honours fail small text: darken GOLD/GREEN and stop fading text; verify in tooling). UI size Small/Normal/Large exists; add independent **Text size** 100/125/150/175 % (hud.md 10.4), **High contrast** palette (no paper texture behind text, 2 px borders), **Reduced motion** (default follows OS), **Toast duration** 3-10 s, **Narration** via `DisplayServer.tts_speak` (AccessKit screen-reader support arrives in Godot 4.5; on 4.4 narration is the fallback).

## 4. Map Patterns
### P-01 Selection and Hover

| Aspect | Spec |
|--------|------|
| Use | Choosing a province/army/nation on the map; peeking at facts. |
| Anatomy | Hover outline (1 px bright) plus **hover card** (desktop only: flag, name, owner-relation glyph, army, terrain; in armed mode adds outcome line). Selection ring (2 px brass-light, drawn double-line so it survives any province fill) plus one pulse. Legal targets: dashed outline and a small marker; illegal provinces unmarked. |
| States | idle, hover, pressed (touch tint 60 ms), selected, armed (targets lit), previewed (see P-02). |
| Input T/M/K | T: tap selects, 12u slop, tap empty sea deselects; no hover, facts appear in the command card header. M: hover 120 ms delay opens card, click selects, Esc/right-click-empty deselects. K: arrow keys move a map cursor along province adjacency, Enter selects, Tab / Shift+Tab cycle provinces with idle armies (`N` jumps to next), Esc deselects. |
| A11y | Selection and legality never by colour only (ring plus dash plus marker); cursor ring visible at 3:1; narration reads "Paris, France, army 120, plains". |
| Godot | Overlay `Control` above the map for rings/dashes drawn in `_draw`; hover card `PanelContainer` in a high `CanvasLayer`, `mouse_filter = IGNORE`, clamped to viewport (existing `_on_hover`); keyboard cursor = Vector adjacency walk using `g.nb_off/nb`. |
### P-02 Order / Preview / Confirm

| Aspect | Spec |
|--------|------|
| Use | Move, attack, declare war, recruit/build with a target, ultimatum defiance. |
| Anatomy | Verb armed from the command card (or right-click) -> target chosen -> **ghost arrow** from to, **outcome chip** on the target ("Win, hold 38" / "Lose, -120" with ^/v glyph and %), troops badge. The card swaps to an order row [Cancel] [Confirm (primary)] (`command-card.md`). |
| Commit rule | Plain move into own/neutral land commits on first tap (Undo toast 5 s). Any attack, war declaration or irreversible spend requires preview then confirm (R2). Touch: tap target = preview pinned, tap same target or press Confirm = commit. Mouse: hover shows the same preview live, a click commits (player has seen it). Keyboard: cursor over target previews, Enter commits. Right-click today commits attacks without a preview: make it preview first, right-click again confirms (as `command-card.md`). |
| States | idle, armed, previewed, committing (march fx 450 ms), cancelled, rejected (P-19). |
| Cancel | tap empty sea, X on the card, Esc, Android Back (first pop in P-20). |
| A11y | Explicit Confirm button exists (second tap alone is invisible); outcome expressed as text and sign, not green/red alone; narration "Attack Ariege: expected win, you hold 38". |
| Godot | Preview state lives in `main.gd` (`_pv_to`); outcome chip = `PanelContainer` positioned from map screen coords each frame in `map.labels` layer; arrow via existing `labels.add_fx`; troops selector = share segmented plus P-13 in the order row. |
### P-03 Command Card (verbs on the selection)

Full spec: `command-card.md` (zone D, replaces `TBProvincePanel`). Pattern-level rules this library adds:

| Rule | Spec |
|------|------|
| Verbs | max 5 slots with stable positions, icon over text label (never icon-only), cost chip on the button, unaffordable = chip with X glyph; disabled verb stays and states why on activation (R6) |
| Parameters | verbs with parameters (troops, building choice) open the **order row** above the card using P-13 / P-10; the card never scrolls |
| Details | ledger and meters live one tap deeper in the card's Details drawer, not in the default card |
| Overlap | card rect registered in `map.keepout_fn`; 16u gap to End Turn; Declare War isolated from End Turn |
| Godot | `PanelContainer` > `HBoxContainer`; verb = `Button` (`icon`, `icon_alignment = TOP`, `expand_icon`, min 88x48u); order row `HFlowContainer`; collapsed state = header only |

## 5. HUD and Feedback Patterns
### P-04 Info Chip (readout)

| Aspect | Spec |
|--------|------|
| Use | Ribbon figures, card facts, list trailing figures. |
| Anatomy | glyph, mono value, optional delta (+/-, ^/v), caption on hover. Top-bar groups (zone A, `hud.md` 4) separated by a 1 px gap: **Economy** (gold, net/turn, manpower), **Military** (army, wars), **Politics** (diplomatic pts, intel, infamy), **Realm** (provinces, tech). Max 9 chips visible; extras fold into a "more" chip on CP. |
| States | normal, changed (delta flash 1.5 s), threshold (warning shape plus colour), disabled/unknown ("--"). |
| Input | T: long-press = tooltip (what it means, what moves it, link to Codex topic). M: hover tooltip. K: focusable in ribbon order, Enter opens the owning screen (gold -> Budget). |
| A11y | Delta carries sign and arrow, not colour alone; value is never truncated, chip wraps below at CP. |
| Godot | `HFlowContainer` of `Control` subclass (existing `P.Readout`); fixed-width monospaced digits so rolling never reflows; `tooltip_text` or custom (P-07). |
### P-05 Alert Chip

| Aspect | Spec |
|--------|------|
| Use | Quiet-until-it-matters surfacing: war on you, revolt, offers/ultimatum, supply shortfall, opportunity. |
| Anatomy | Shape-coded severity (diamond info, triangle warning, square crisis) plus 2-4 word text plus count. Visible rows per `hud.md` zone C (4 on D, 1 on L/P) plus a `+N` pill that opens Council (Alerts). Priority: war > revolt > offers > supply > opportunity. |
| States | appear (fade 160), crisis pulses **once**, persistent until resolved, resolved (fade out and collapse), snoozed this turn (swipe/x). |
| Input T/M/K | T: tap flies the camera to the subject and selects it; long-press = why. M: click same; hover = tooltip with fix hint. K: Tab into chip row, Enter acts, Delete snoozes. |
| A11y | Narration announces new crisis chips once per turn ("Crisis: Revolt in Lyon"); text never replaced by icon. |
| Godot | `HBoxContainer` under the ribbon; chip = flat `Button` with `_draw` shape; `Tween` for fade; source = `TBAdvisor.alerts()` (sev 0-2 maps to shape). |
### P-06 Toast

| Aspect | Spec |
|--------|------|
| Use | Outcome of the player's own action and notable log lines. Not for decisions or errors that need action (use P-19 dialog). |
| Anatomy | single-line slip (max 2 lines) with glyph, text, optional action ("Undo", "Show"). One at a time (hud.md: at most one toast-style message); end-of-turn events are summarised by the **Turn report**, not by toasts. |
| States | in, held (paused while hovered/focused or narration speaking), out, queued (overflow coalesces: "+4 events" opens Annals). |
| Timing | info 4 s, error 6 s, user setting 3-10 s; never under 3 s. |
| Input | T/M: tap dismisses or runs action. K: `Esc` clears toasts when no panel is open. |
| A11y | Announced without taking focus (TTS); bad news carries a glyph, not just red; never the only channel for actionable info. |
| Godot | existing `_toasts` `VBoxContainer`, `mouse_filter = IGNORE` except action buttons; `Timer` per slip, `Tween` modulate. |
### P-07 Tooltip (hover / focus / long-press)

| Aspect | Spec |
|--------|------|
| Use | Explains chips and disabled controls. Never the only place for required info. |
| Anatomy | Title (13 caps), effect line with numbers, optional reason line with an X glyph, optional "Open in Codex". Max 3 lines, 280 px wide. |
| Trigger | Mouse hover 400 ms; keyboard focus 300 ms; **touch long-press 450 ms** with 10 ms haptic tick, card sits above the finger, stays until next touch/scroll/Back (so it can be read); short tap still performs the normal action. |
| A11y | Same text is narrated on focus; dismiss with Esc; contrast 4.5:1; honours reduced motion (no fade). |
| Godot | Hover: override `_make_custom_tooltip(for_text)` returning a styled `PanelContainer`. Touch: a `TooltipHost` node that watches `InputEventScreenTouch` with a `Timer`, shows the card in a `CanvasLayer` (layer 90), clamps to viewport; `Input.vibrate_handheld(10)` on Android. |
### P-15 Number Roll

| Aspect | Spec |
|--------|------|
| Use | Ribbon chips and cost totals when a value changes. |
| Behaviour | Roll 400 ms ease-out, max 8 intermediate frames, plus a delta chip ("+20") for 1.5 s. Do not roll on first draw, on load, or when change exceeds 10x; throttle to one roll per 250 ms. Reduced motion: swap instantly, keep delta 3 s. |
| A11y | Narrate once per turn as a batched summary ("Gold 120, plus 20"), never per tick. |
| Godot | `Label` with mono font and `Tween` on a float property; fixed `custom_minimum_size.x` from the widest digits (existing `P.Readout.set_num`). |

## 6. Container and Navigation Patterns
### P-08 Dialog / Drawer / Sheet / Page

Decision rule (full spec in `modal-system.md`):

| Question | Yes -> |
|----------|--------|
| Blocking, needs an answer, under one screen? | **Dialog** (centered, backdrop, focus trap) |
| Player should keep seeing and using the map while tuning/reading? | **Drawer** (landscape right rail, non-modal) / **Sheet** (portrait bottom, drag handle) |
| Browse, compare or configure, wants width, map not needed? | **Wide panel** (landscape) / **Page** (portrait full screen) |

Never a drawer over a wide panel; never more than one panel plus one dialog.
### P-09 Tab Bar

| Aspect | Spec |
|--------|------|
| Use | Switching the **view** of a screen (Annals filters excluded: those are P-10). 2-5 tabs; more scroll with edge fade. |
| Anatomy | Text tabs on a tinted band, 44 high (48u touch), selected = underline 3 px plus bold weight plus filled tick (not colour alone). Badge dot for new content. |
| Input T/M/K | T: tap, no swipe (conflicts with sliders and map). M: click. K: Left/Right moves and activates, Home/End, Ctrl+Tab cycles tabs from anywhere in the panel, `[`/`]` also. |
| A11y | Role tab/tablist semantics in narration ("Alerts, tab 1 of 2"); label never truncated: width follows text, min 72. |
| Godot | Native `TabBar` (`scrolling_enabled`, `tab_changed`) above a script-swapped body; theme `tab_selected` stylebox with underline. Avoid `TabContainer` (frame and focus styling fight the paper theme). |
### P-10 Segmented Control

| Aspect | Spec |
|--------|------|
| Use | One value or filter inside content: difficulty, players 1-4, filter All/War/Allies, map view. 2-4 options; more -> list or dropdown. Binary on/off uses P-14. |
| Anatomy | Joined cells, **selected = filled cell plus check glyph**, others outlined; height 44 (48u touch); equal width unless a label overflows (RU/UZ +35 %), then content width, then wrap into stacked list. |
| Input | T/M: tap. K: Left/Right moves selection, Space/Enter confirms (or applies live, per screen), Home/End. |
| A11y | Differs visually from tabs on purpose (box vs underline) so sections and values are never confused. |
| Godot | `HBoxContainer` of `Button` with `toggle_mode = true` and a shared `ButtonGroup`; `pressed` stylebox = filled; replace today's `K.Segmented` underline look when it is used for values. |
### P-20 Back Navigation (Android Back, Esc, X)

Pop order, one step per press (implemented in `main.gd _on_back`):

| # | State when pressed | Result |
|---|--------------------|--------|
| 1 | Tooltip or long-press card open | Close it |
| 2 | Order armed or previewed | Cancel the order (P-02) |
| 3 | Dialog or panel open | Close top-most. **Exception**: event/ultimatum prompt, game over, hot-seat pass curtain are *unanswered* states: Back is swallowed with a toast "Choose an option". |
| 4 | Province/selection present | Deselect |
| 5 | In game, nothing else | Open **Menu** hub (not quit) |
| 6 | New-game flow | Previous step (pick -> setup -> title), keeping selections |
| 7 | Title screen | First press toast "Press Back again to exit" (2 s), second quits |

Today `_on_back` frees the topmost `ColorRect` blindly: it can discard an event prompt that was already marked shown (never re-prompted) and skips step 7's guard. Requires `application/config/quit_on_go_back = false` (handled via `NOTIFICATION_WM_GO_BACK_REQUEST`). `Esc` and `ui_cancel` map to the same stack; every X button, backdrop tap (dismissable dialogs only) and Back share one `pop()` function. Drawer/sheet/page Back arrow in header is a visible duplicate for touch.
### P-21 Focus Order and Keyboard Shortcuts

| Rule | Spec |
|------|------|
| Initial focus | First actionable control in the body; on a read-only panel, the primary footer action; on destructive dialogs, **Cancel**. Never on a non-interactive node. |
| Tab order | Reading order: tab row, body (top to bottom, left column then right), footer actions, Close last. Focus is trapped in the open dialog/panel (map input disabled while an overlay exists). |
| Return | On close, focus returns to the element that opened it (dock button, chip). |
| Visibility | Every interactive control draws a 2 px focus ring offset 2 px (oxblood on paper, brass-light on dark); custom `_draw` controls (`ListRow`, `Segmented`, `IconBtn`, `Entry`) must draw it. |
| Shortcuts | Panel level: `Esc` back, `Ctrl+Tab`/`[` `]` tabs, `/` search a list, `F5` quick-save, `F9` quick-load, `?` shortcut list. Screens: `N` Nations, `B` Budget, `D` Decisions, `C` Council, `Y` Annals (`A` is next alert, hud.md), `Esc` with nothing open = Menu. Verb keys, `Tab` targets, End Turn: `hud.md` / `command-card.md`. Shown in tooltips; remappable in Settings (Comprehensive). |
| Godot | Set `focus_mode = FOCUS_ALL` on interactives (today `FOCUS_NONE`), restore focus `StyleBox`, `focus_neighbor_*` for grids, `ScrollContainer.follow_focus = true`, handle global keys in `_unhandled_key_input`, gated by `_overlay.get_child_count() == 0`. |

## 7. Input Control Patterns
### P-11 List Row

| Aspect | Spec |
|--------|------|
| Use | One entity per row (nation, annal, save slot, honour). |
| Anatomy | lead 28 (flag/glyph), text block (primary 1 line ellipsis, secondary 13 px dim 1 line), up to 2 chips, trailing mono figure, chevron if it navigates, 1 px hairline. Whole row is the target. Max one trailing action button; more actions go to the detail view. |
| Density | CD 40 high compact, CL 52, CP 56 comfortable (see modal-system.md 5.5). Section headers sticky. Lists over 12 rows get search and sort; sort header shows a ^/v glyph. |
| States | idle, hover/pressed tint, selected (3 px left bar plus tint plus check), focused (ring), disabled (text stays 4.5:1, plus a reason line), current-player row (bold plus "You" chip). |
| Input T/M/K | T: tap row; long-press = peek tooltip; no swipe actions. M: click, hover tint. K: Up/Down, Enter, Home/End, type-ahead on first letter. |
| A11y | Narrate "Spain, 208 provinces, rank 1 of 250". Do not silently cap: the Nations list stops at 60 of 250 with no indicator (gap). |
| Godot | `ScrollContainer` (`follow_focus`) > `VBoxContainer` of pooled row `Control`s (visible window plus 4) when over 60 rows; rows keep today's `K.ListRow` custom draw but add focus ring. `Tree` rejected: poor touch kinetic scrolling. |
### P-12 Slider

| Aspect | Spec |
|--------|------|
| Use | Allocations (Budget %) and volume. Always paired with a numeric value and a consequence ("Tax 50 %: +112 gold/turn"). |
| Anatomy | label and value on top, rail with bead (draw 24-28, hit 48), P-13 stepper at the end on touch. Allocation sliders sum to 100: moving one redistributes from unlocked rows; lock glyph per row. |
| Input T/M/K | T: drag the bead or tap the rail; vertical drags starting off the bead scroll the panel. M: drag, wheel disabled (`scrollable = false`) so wheel scrolls the panel. K: arrows 1, Shift 5-10, PgUp/PgDn 10, Home/End. |
| A11y | Value text always visible; delta chip carries sign; step 5 for coarse, stepper for exact. |
| Godot | `HSlider` with `step`, `scrollable = false`, `ScrollContainer.scroll_deadzone = 12`, grabber icons existing (`bead_tex`), `value_changed` -> `g.apply` live with a "Revert" footer action. |
### P-13 Stepper

| Aspect | Spec |
|--------|------|
| Use | Exact small numbers: troops to send (with quick fractions 1/4, 1/2, 3/4, All above it), players 2-4, budget fine-tune. |
| Anatomy | [-] value [+] with 48u buttons, value mono centred, optional unit. Hold-to-repeat: 400 ms delay, then 80 ms interval, accelerating. At min/max the button disables and shows the limit in the tooltip. |
| Input | T/M: tap/hold. K: Up/Down arrows, PgUp/PgDn x10, typed digits if focused. |
| A11y | Narrate value changes (debounced 300 ms). |
| Godot | `HBoxContainer`: `Button`, `Label`, `Button` plus a `Timer`; do not use `SpinBox` (tiny hit area, text-edit caret on touch). |
### P-14 Toggle

| Aspect | Spec |
|--------|------|
| Use | Binary settings (Sound, Perf readout, Reduced motion, High contrast). Replaces two-cell On/Off segmented rows. |
| Anatomy | Whole row is the target: label left, switch plus visible "On"/"Off" word right (position and word, not colour). 48u high. |
| Input | T/M: tap row. K: Space/Enter toggles. Applies immediately. |
| Godot | `CheckButton` re-themed (custom `checked`/`unchecked` icons drawn by `TBGlyph`) stretched across the row; `focus_mode = ALL`. |
### P-22 Button and Meter basics

| Aspect | Spec |
|--------|------|
| Button | **Primary** = one per container (wax plate, right of footer), label = verb plus object ("Play as France", "Enact Decree"); **Secondary** = outline; **Destructive** = text red plus warning glyph, never executes directly (P-16); **Icon** = needs tooltip and a narration name. Never label "OK", "Yes", "Back" in footers (X plus Back key already exist). Height 48u touch; disabled stays focusable and explains (R6). |
| Meter | Thin bar with ticks 25/50/75, numeric label always, threshold marker shape (diamond at goal). Colour (STEEL under 40 %, GOLD2 40-90, GREEN over 90) plus the % text. Godot: existing `K.Meter` or `ProgressBar` with `show_percentage = false`. |

## 8. Feedback State Patterns
### P-16 Confirmation of Destructive Actions

| Level | Examples | Pattern |
|-------|----------|---------|
| L0 reversible | plain move, budget change, toggle | no confirm; Toast with Undo 5 s |
| L1 consequential, previewable | declare war, break pact, yield to ultimatum, demand land | on-map preview (P-02) or Dialog stating the consequence ("Infamy +8; truce ends"); confirm button names the act |
| L2 data loss | overwrite save, delete save, abandon campaign to menu (progress since autosave) | Dialog, default focus **Cancel**, red labelled confirm ("Overwrite slot 2"), shows what is lost ("Turn 19, 1850 AD") and offers "Save and exit" when leaving a game |
| Soft | End Turn with unhandled critical alert (setting Confirm End Turn: Smart, hud.md) | the plate morphs to "Confirm?" for 3 s (inline, no modal) |

No hold-to-confirm (motor accessibility). Gaps today: Save overwrites slots silently; Main menu from Settings exits without a prompt.
### P-17 Loading / Busy

| Case | Pattern |
|------|---------|
| End turn (worker thread) | After 150 ms seal shows a spinning ring and "Turn 12 -> 13"; minimum 400 ms to avoid flicker; if over 1 s show progress text ("Nations acting"); orders and commit buttons disabled with reason "Turn in progress"; camera and read-only panels stay usable. |
| Era/save load | Inline "Loading era..." row with skeleton rows; never a blank panel; Cancel available over 3 s. |
| Multiplayer wait | persistent top banner "Waiting for 2 players" plus count. |

A11y: narrate "Turn processing" and "Turn 13 begins"; reduced motion: static hourglass glyph.

### P-18 Empty State

Rule: glyph (48, dim), one line stating what, one line stating why or next, optional action. Calm states are positive ("quiet until it matters").

| Place | Content |
|-------|---------|
| Annals "Mine" | "No entries yet. Wars, treaties and events appear as turns pass." + [Show all] |
| Council alerts | "All quiet. Nothing needs you this turn." |
| Nations search | "No nation matches 'xyz'." + [Clear search] |
| Save slot | "Empty slot" + [Save here] |
| Honours earned filter | "None yet. Try: occupy an enemy province." (shows the nearest honour) |
| Decisions all locked | reasons per row instead of an empty list |
### P-19 Error State

| Type | Pattern | Tone |
|------|---------|------|
| Order rejected (`g.apply` err) | Toast with X glyph and reason ("Needs 40 gold, you have 22"); selection kept | specific, never blames |
| Save/Load failed | Dialog [Retry] [Cancel] with the cause and free-space hint; slot row shows "Unreadable" with [Delete] | calm, actionable |
| Corrupt / newer-version save | Row disabled, reason line, never crash | factual |
| Multiplayer lost | banner "Reconnecting 2/5", then Dialog [Retry] [Main menu] | reassuring |
| Missing data (era) | Dialog "Could not load Napoleonic Era. Using Modern World." | recovers by default |

## 9. Gaps Found in the Current Build (feed to ui-programmer)

| # | Gap | Pattern |
|---|-----|---------|
| 1 | No focus ring; `FOCUS_NONE` on all buttons: keyboard unreachable | P-21 |
| 2 | Back button discards unanswered event prompts; title screen quits at once | P-20 |
| 3 | Save overwrites silently; Main menu from Settings loses unsaved turns | P-16 |
| 4 | Nations list truncated at 60 of 250 without notice | P-11 |
| 5 | Captions at 9-11 px, locked Honours at 28 % alpha, GOLD captions below 4.5:1 | R7 |
| 6 | `MIN_TOUCH = 44` logical is under 48u on high-DPI phones | Sec. 3 |

## 10. Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Does `g.apply({"cmd":"budget"})` normalise to 100, or are the four sliders independent? Linked sliders need game-designer sign-off. | game-designer | before Budget build | Open |
| Godot 4.4 has no AccessKit: accept TTS narration as the Comprehensive screen-reader substitute, or upgrade to 4.5+? | technical-director | before Pre-Production gate | Open |
| Right-click attack: should veterans get immediate commit (Shift+RMB) or is preview-always acceptable? | creative-director | playtest | Open |
| Which Android back convention for the hot-seat pass curtain: swallow or open Menu? | creative-director | before hot-seat polish | Open |
