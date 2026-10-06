# Accessibility Requirements: Terra Bellum

> Authoring guidance: .claude/docs/templates/guidance/accessibility-requirements-guide.md

> **Status**: Committed (tier chosen by creative director; requirements Draft until the UI-redo Phase-4 review)
> **Author**: creative director + accessibility-specialist
> **Last Updated**: 2026-10-06
> **Accessibility Tier Target**: Comprehensive (plus selected Exemplary items, see below)
> **Platform(s)**: Android, iOS, Windows. Input: touch (primary), mouse + keyboard (full), gamepad (optional, free via Control focus)
> **Engine**: Godot 4.4.1, GDScript, Control nodes, GL Compatibility. No image assets; UI is procedural; fonts Cinzel / Alegreya / JetBrains Mono
> **External Standards Targeted**:
> - WCAG 2.1 Level AA (all UI text/controls); AAA for body text contrast (SC 1.4.6) and target size (SC 2.5.5) where listed
> - AbleGamers / Game Accessibility Guidelines (basic + intermediate + selected advanced); CVAA: N/A (no in-game chat; MP has fixed lobby text only)
> - Xbox XAG: No (no console target). Apple HIG (44 pt targets, Dynamic-Type intent) and Material (48 dp, 12 sp min): Yes
> **Accessibility Consultant**: None engaged (see Open Questions)
> **Linked Documents**: `design/game-brief.md`, `design/ux/` (per-screen specs), `docs/ux/interaction-pattern-library.md` (to be written; must cite A11Y IDs)

> **How to use**: every requirement has an ID. UX specs, tickets and PRs cite IDs. A feature that conflicts with an ID changes; this
> document does not, unless the producer approves a revision. Severity of a failed requirement: S2 (BLOCKING at the gate) unless marked
> `[adv]` (advisory). Owners: **UIP** ui-programmer, **ART** art-director, **TA** technical-artist, **GC** game code (engine/ + controllers),
> **UXD** ux-designer, **AUD** audio, **LOC** localization, **QA** qa-tester.

---

## Accessibility Tier Definition

### This Project's Commitment

**Target Tier**: Comprehensive.

**Rationale**: Terra Bellum is turn-based, which removes the worst motor and reaction-time barriers; the barriers that remain are visual
(a GPU-shader map whose meaning rides on ~250 arbitrary nation colours and 10 colour lenses, 9-16 px text today), motor-by-touch
(a pan/pinch map, small tap targets on 360-dp phones) and cognitive (dense ledgers, many systems, three languages with +35 % strings).
The audience is strategy players on phones and PCs, skewing 25-55, where colour-vision deficiency (about 8 % of men) and presbyopia are
common and one-handed phone use is the norm. A pure-UI redo is the cheapest moment to build focus, scaling, semantic colour and
non-colour redundancy in; retrofitting after screens ship costs several times more. Dropping to Standard would remove high-contrast,
reduced-motion, redundant audio/visual channels and the Annals mirror, which together serve an estimated 10-15 % of players.

**Features in scope beyond the Comprehensive baseline (elevated from Exemplary)**:
- High-contrast theme for menus **and** map (Exemplary) - the map is the hero, so it must be legible too.
- Cognitive assist tools: plain-language option, simple HUD, undo/confirm (Exemplary) - the game is number-dense.
- Haptic twin for the key audio/visual alerts (Exemplary, mobile only).
- Self-voicing text-to-speech (`DisplayServer.tts_speak`) as the screen-reader substitute while on Godot 4.4.1.

**Features explicitly out of scope** (all repeated in Known Intentional Limitations):
- OS-level screen reader (TalkBack / VoiceOver / NVDA) on Godot 4.4.1: AccessKit integration is not in 4.4 (see A11Y-SR-001).
- Free drag-and-drop HUD repositioning (Comprehensive baseline lists it): replaced by dock side / handedness / HUD scale presets (A11Y-ONE-002).
- Subtitles and caption styling: the game has no voiced dialogue; all narrative is text. Event sounds get visual twins instead (A11Y-AUD).
- External third-party accessibility audit (Exemplary): not budgeted; internal audit plus an AbleGamers-style panel is an Open Question.
- Eye-tracking / switch-device specific profiles: covered only via keyboard-equivalent operation (A11Y-KBD).

### Baseline defects found in the current interface (must be closed by the redo)

| # | Defect | Where | Requirement that closes it |
|---|--------|-------|----------------------------|
| D1 | Toast text uses `K.TEXT` (dark ink) on a navy plate = **1.2:1**; bad toasts `K.RED` on navy = 3.0:1 | hud.gd `toast()` | A11Y-CON-001/002 |
| D2 | `GOLD` 3.78:1, `GREEN` 4.22:1 on paper, `DIM` on `PANEL2` 4.09:1, disabled text 1.85:1 | ui_kit.gd palette | A11Y-CON-001/003 |
| D3 | Every Button/Segmented/ListRow/Seal sets `FOCUS_NONE`; theme `focus` stylebox is `StyleBoxEmpty`; map has no keyboard path | ui_kit.gd, hud_parts.gd, map_view.gd | A11Y-KBD-001..006 |
| D4 | Text 9-10 px (caps captions, legend, badge, turn line) | hud.gd, hud_parts.gd, ui_kit.gd | A11Y-TXT-002 |
| D5 | `MIN_TOUCH = 44` logical px, but dock 46x54, lens 34 high, Segmented/ListRow 40, IconBtn 40, slider 30 | ui_kit.gd, hud.gd | A11Y-TCH-001..003 |
| D6 | Logical px is not dp: base 1280x720 on a 411-dp-tall landscape phone makes 1 logical px about 0.53 dp (44 logical = 23 dp) | main.gd `_update_ui_scale` | A11Y-TXT-005, A11Y-TCH-001 |
| D7 | `ChoiceCard` fires on press-down, mouse only (cannot be focused, cannot be cancelled) | ui_kit.gd | A11Y-GES-003, A11Y-KBD-001 |
| D8 | Owner, relation, stability, war-bloc and legend swatches are colour-only; war lens colour is a hashed hue | lenses.gd, hud_parts.gd Legend | A11Y-CVD-001..008 |
| D9 | Sound is on/off only; toasts vanish after a fixed 5.5 s; `ui` size is 3 steps via `content_scale_size` (max +19 %) and scales layout, not text | main.gd, hud.gd, modals.gd | A11Y-AUD, A11Y-TIM, A11Y-TXT-001 |
| D10 | `K.theme()` is built before `_load_cfg()`; `TBMapView.animate` is an env var, not a player setting; `ListRow.draw_string` clips without ellipsis | main.gd, map_view.gd, ui_kit.gd | A11Y-SET-002, A11Y-MOT-001, A11Y-LOC-003 |
| D11 | Multiplayer room creation passes a `120` (s) turn-timer argument | mp_controller.gd `create_room` | A11Y-TIM-002 |

## Visual Accessibility

### Text size and layout reflow

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-TXT-001 | Four text-size steps, independent of layout scale: **100 / 125 / 150 / 200 %** (200 % satisfies SC 1.4.4). Applies to every Label, Button, LineEdit, popup, toast, map label and drawn text. Layout/HUD scale (`ui`: small/normal/large) stays a separate setting. | At 200 % on 540x960 and 1920x1080 no text is clipped, overlapped or cut by an edge; every control still reachable (scroll allowed vertically only). Screenshot matrix passes. | UIP | One function `TBKit.fs(px)` = `round(px * text_scale)`, floored by A11Y-TXT-002; all `add_theme_font_size_override` / `draw_string` call sites go through it. Rebuild screens on change (settings already rebuild on language). Never scale via `content_scale_factor` (that is the layout scale). |
| A11Y-TXT-002 | Minimum rendered size at 100 %: **body 14 dp / 16 logical (desktop), caption/label never below 12 dp** (11 pt iOS). No 9-10 px text anywhere, including legends, badges, army numbers, hover cards. Decorative glyph-only elements are exempt. | Automated tree walk reports min effective font size per screen >= floor in dp; zero violations. | UIP / ART | `TBKit.fs()` clamps to `TBKit.min_font()` = 12 dp expressed in logical px (A11Y-TXT-005). Replace `caps(..., 9/10)` with floor-clamped calls. |
| A11Y-TXT-003 | Reflow rules: (a) text wraps, never truncates, except single-line list names which use ellipsis plus full text on focus/tooltip; (b) containers grow vertically; (c) at >= 150 % portrait modals become a single column and landscape two-column modals collapse to one below 820 logical px; (d) the top ribbon wraps (HFlowContainer already) and drops from 9 readouts to the 4 essentials plus a "more" chip when height > 20 % of screen; (e) fixed-size drawn controls (Seal, dock) scale with `max(layout_scale, text_scale^0.5)` so labels fit. | Pass 200 % screenshot matrix on 540x960, 360x780 dp portrait, 2340x1080 landscape, 1920x1080; ribbon never exceeds 20 % of height; no horizontal scroll. | UIP | `HFlowContainer`, `autowrap_mode = AUTOWRAP_WORD_SMART`, `ScrollContainer` (`horizontal_scroll_mode = DISABLED`), `K.modal` height cap already exists; add `layout_for()` breakpoints keyed on text scale. |
| A11Y-TXT-004 | "Readable fonts" option: display capitals (Cinzel, Alegreya SC, tracked) swapped for Alegreya Bold sentence case with no letter-spacing; no ALL-CAPS strings longer than 3 words anywhere. Cyrillic and Uzbek apostrophes (o', g') render in both font sets. | Toggle on: screenshot of every modal shows no tracked capitals; no tofu boxes in EN/RU/UZ. | UIP / ART | `TBKit.display()` and `caps()` return the body face when `cfg.readable_fonts`; `caps()` skips `to_upper()`. |
| A11Y-TXT-005 | One logical unit = one dp on mobile. Set `content_scale_size` from window pixels and `DisplayServer.screen_get_dpi()/160`, then multiply by layout scale; desktop keeps 1280x720 / 540x960 bases. All dp rules below are measured through `TBKit.dp(n)`. | On a 411x891 dp phone and a 891x411 dp phone: `TBKit.dp(48)` renders 48 +/-1 dp (measured by screenshot ruler). Layouts verified at 891x411 dp (minimum landscape height 360 dp). | UIP | `main.gd._update_ui_scale()`; `TBKit.dp()` static; `DisplayServer.screen_get_dpi()` (Android/iOS return real density). |

### Contrast and high-contrast theme

Measured on the current palette: TEXT/PANEL 11.7:1, GOLD2/PANEL 7.7:1, RED/PANEL 4.7:1, DIM/PANEL 4.9:1, SMOKE/UMBER 5.0:1, BRASS_LT/UMBER 9.1:1.

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-CON-001 | All text: **>= 4.5:1** against its actual background (3:1 for text >= 24 px or >= 18.7 px bold). **Body and primary-figure text >= 7:1** (AAA, SC 1.4.6). Secondary captions (DIM) may stay 4.5-7:1. `GOLD` and `GREEN` may not be used for text < 24 px on paper (use `GOLD2` / darker green >= 4.5:1). | Unit test over the registered pair list `TBKit.PAIRS` (fg, bg, role) asserts ratios; zero failures. Screenshot sampling for text over translucent plates. | ART / UIP | Colour tokens in `TBKit` with a `PAIRS` table; `static func contrast(a: Color, b: Color) -> float` using WCAG relative luminance; run headless in CI. |
| A11Y-CON-002 | Non-text UI (borders of controls, focus ring, meter fills, slider rails/beads, icons, chart lines, state indicators) **>= 3:1** against adjacent colours (SC 1.4.11). Hairline ink rules that are purely decorative are exempt. | PAIRS test for control edge vs panel; slider rail at 3:1 (current rail alpha 0.35 fails). | ART / UIP | `StyleBoxFlat`/`TBFrame` border colours; opaque rail; bead outline. |
| A11Y-CON-003 | Disabled controls remain >= 3:1 (WCAG exempts disabled, we do not) and carry a non-colour disabled cue (hatched face or a "locked" glyph), plus a visible "why" via tooltip/long-press (cognitive twin). | Visual + PAIRS; every disabled button has a reason string. | UIP | Theme `font_disabled_color`; `TBFrame` hatch option; `tooltip_text`. |
| A11Y-CON-004 | **Toasts, hover card, battle banner and legend use the paper-on-dark pair that already passes** (CREAM/BRASS_LT on navy) - never `K.TEXT` on navy. Bad news adds a glyph and the word "Alert", not just a red rule. | Fix D1; PAIRS covers every plate type. | UIP | `hud.gd toast()`; `TBHud.show_preview`. |
| A11Y-CON-005 | **UI theme "High contrast"** (setting): opaque panels (no alpha, no paper noise texture), pure-ish black text on white (light HC) or white on black (dark HC), body >= 7:1, all text >= 7:1, 2 px solid control borders >= 4.5:1, 3 px focus ring, no gradients or tracked display type, selection state shown by fill + border + glyph. Both HC variants ship. | Every screen in all states screenshotted in both variants; PAIRS-HC all >= 7:1 for text, >= 4.5:1 for UI; no transparency in HC panels. | ART / UIP | `TBKit.theme(variant)` builds a second `Theme` (`StyleBoxFlat`); `main.gd` swaps `theme =` and rebuilds; `TBFrame` factories take `hc` flag. |
| A11Y-CON-006 | **Map text** (nation names, province labels, army gonfalon numerals, legend): >= 4.5:1 against whatever lens colour is under it, achieved by an auto-chosen plate/outline (light text + dark outline or inverse chosen from the underlying colour's luminance), not by assuming the lens. | Render all 10 lenses x 3 CVD modes x HC; sampling tool measures label vs pixels beneath in a 1.5x text-height halo; >= 4.5:1. | TA / UIP | `map_labels.gd` outline colour computed per label from `TBLenses.color(p)` luminance; HC theme adds an opaque plate (`draw_rect`). |
| A11Y-CON-007 | **Map theme "High contrast"** (3rd value of shader `theme` uniform): national borders >= 2.5 px and >= 3:1 against both neighbours, province borders 1 px at >= 3:1 only at zoom where provinces > 24 dp wide, selection outline 3 px double stroke, sea/land luminance gap >= 3:1. | Screenshot matrix; border contrast sampler. | TA | `globe.gdshader` `theme` int and border-width uniforms; `map_view.gd._push_view()`. |

### Colour-vision safety (map and UI)

Modes: Off, Deuteranopia, Protanopia, Tritanopia (setting `cvd`). Modes change **palettes**, never the information model: the non-colour
channels in A11Y-CVD-003..008 are on in every mode, including Off.

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-CVD-001 | Three CVD palette sets for every colour-coded thing in `lenses.gd` (ramps, categorical, relation) and `TBKit` semantic colours (good / bad / warn / info / own / ally / enemy). Ramps are luminance-monotone (viridis-like, never red-green hue ramps); good/bad pairs are orange vs blue (deut/prot) and red vs cyan (trit), not red vs green. | Machado (2009) simulation of every lens at severity 1.0 for all three types: adjacent legend stops differ by DeltaE00 >= 10; good vs bad semantic pair DeltaE00 >= 20. Tool: `tools/cvd_sim.gd` or Coblis. | ART / TA | `TBLenses` consts become per-mode arrays; `static var cvd` selects; `STAB_RAMP` (red-green) replaced in CVD modes; `repaint_all()` on change. |
| A11Y-CVD-002 | **Political lens in CVD modes** recolours nations from an adjacency-aware assignment: Okabe-Ito-derived palette (8 hues x 2 lightness steps), greedy graph colouring on the province-neighbour graph so adjacent owners never share a palette index; own nation always gets one reserved colour. In Off mode nation colours stay historical. | Over every era: >= 90 % of adjacent owner pairs have DeltaE00 >= 8 under each simulated type; the remaining pairs are separated by the national border (A11Y-CVD-003) and labelled. | TA / GC | `TBLenses.refresh_nations()` builds `nat_rgb[]` from the colouring when `cvd != off` (and the flag texture fallback is unchanged); recompute on owner change, cached per era. |
| A11Y-CVD-003 | **Owner identity is never colour-only.** Always-on: (a) national border: dark outer + light inner stroke, >= 2 px, regardless of fill colours; (b) nation name labels at the zoom tiers that show province labels; (c) flag + name on gonfalons and in the hover card; (d) a "Find nation" list/search that selects and flies to a nation (A11Y-GES-002). | Greyscale screenshot (luminance only) of political lens: every owner border visible; a tester names owner of 10 random provinces using labels/borders alone with >= 9/10 correct. | TA / UIP | Existing shader rim/border code (`e_nat`) with width/contrast uniforms; `map_labels.gd`; Nations modal. |
| A11Y-CVD-004 | **Relation markers on the map (pattern + glyph)**, drawn in screen space (constant pixel pitch, 45 deg, independent of zoom): **own** = heavier solid border + star glyph at capital label; **ally** = dashed inner border + shield glyph; **war** = diagonal red-agnostic hatch (2 px lines, 6 px pitch, luminance-contrasting colour) + crossed-swords glyph at label; **truce/NAP** = dotted inner border + hourglass glyph; **rebel** = cross-hatch. The existing "hatch for occupied land" is unified into this system. | Legend lists marker + glyph + name; greyscale screenshot passes; each relation distinguishable at zoom 1x and 4x in all CVD modes. | TA / UIP | Relation class code (0..5) written to a free channel/row of the `pal` texture by `TBMapView._write()`; fragment shader derives pattern from `gl_FragCoord`/`UV * rect_size`; glyphs drawn by `map_labels.gd` via `TBGlyph`. Marker intensity: subtle in Off mode, strong in CVD/HC. |
| A11Y-CVD-005 | Diplomatic, wars, stability, economy, military, population, buildings, governments, terrain lenses: **legend swatches carry a letter/number or pattern**, and each province can show its value on demand (hover card / long-press / focus readout, A11Y-KBD-004). War lens blocs show a bloc letter (A, B, C) at the nation label instead of relying on the hashed hue. | Legend screenshot in greyscale: each entry distinguishable; war bloc letters present; value readout works for every lens. | UIP / TA | `hud_parts.gd Legend` draws `draw_string` letter inside swatch; `lenses.gd _war_groups()` returns bloc index as well as colour. |
| A11Y-CVD-006 | UI semantic colours: every colour-coded UI state has a redundant glyph or text. Required rows: net-gold sign and arrow (+ up / - down), battle bar (labels "You"/"Them", numerals, win/lose check/cross), toast severity (info i / warn triangle / alert octagon + word), advisor badge (shape by severity, number inside), meters (numeric value always visible, tick marks, threshold glyph at <25), diplomatic relation chips (icon + word), selected vs unselected states (A11Y-CVD-007). | Colour-as-only audit table below has zero open rows in all four modes. | UIP | `TBGlyph.draw()`; `GlyphLabel`; `P.DockButton.badge`. |
| A11Y-CVD-007 | Selection, hover, valid-target and focus are never colour-only: selection = thicker double outline + corner brackets, valid target = animated-free dotted fill/hatch + "target" glyph, focus = ring (A11Y-KBD-003), disabled = hatch. | Greyscale screenshots; reduce-motion static. | TA / UIP | Shader `sel_id`, row-3 target flag; static pattern instead of `sin(time*4)` when reduce-motion (A11Y-MOT-002). |

### Colour-as-Only-Indicator Audit

| Location | Colour signal | What it communicates | Non-colour backup (required) | Status |
|----------|---------------|----------------------|------------------------------|--------|
| Political lens fill | Per-nation colour | Owner | Border stroke, labels, flag in hover card, adjacency-aware CVD palette | Not Started |
| Diplomatic lens (`REL_COL`) | Grey/red/cyan/blue/violet | Peace/war/NAP/ally/marriage | A11Y-CVD-004 patterns + glyphs, legend letters | Not Started |
| War lens (`war_col`, hashed hue) | Bloc hue | Which war bloc | Bloc letter at labels, hatch on belligerents | Not Started |
| Stability / economy / military / population ramps | Red-green, yellow, orange, blue ramps | Magnitude | Luminance-monotone CVD ramps; numeric on demand; legend ticks | Not Started |
| Buildings / governments / terrain lenses | Categorical colours | Category | Legend letters/patterns; name in hover card | Not Started |
| Valid move/attack targets | Yellow breathing tint | Where an order can go | Dotted hatch + target glyph; static in reduce-motion | Not Started |
| Own provinces/armies | Green (`0x46c36b` in diplomatic lens) | "Mine" | Heavy border + star glyph | Not Started |
| HUD gold caption | Green/red | Income sign | "+"/"-" sign (exists) + up/down arrow | Not Started |
| Battle preview bar | Green vs red split | Win/lose odds | Labelled sides, numbers, outcome sentence + icon | Not Started |
| Toasts | Red rule / red text | Bad news | Glyph + "Alert" word + Annals entry | Not Started |
| Advisor badge | Red vs brass | Critical vs normal | Shape (octagon/circle) + count | Not Started |
| Meters (`Meter`, `meter_row`) | Green/red fill | Good/poor level | Value text, ticks, "low" glyph | Not Started |
| Army gonfalons | Owner colour field | Whose army | Flag glyph + number + friendly/hostile frame shape | Not Started |

### Other visual requirements

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-VIS-001 | Map zoom-disclosed information (gonfalons, labels) never encodes meaning only by size or distance; "Show all labels" toggle for low-vision users forces the largest label tier at any zoom (capped by overlap rules). | Toggle works at 100-200 % text. | TA | `map_labels.gd` tier thresholds multiplied by an accessibility factor. |
| A11Y-VIS-002 | Photosensitivity: no element flashes > 3 times per second; no red flash; whole-screen luminance changes (fade-to-black transitions) <= 1 per 2 s. Existing pulses (`sin(time*4)` 0.64 Hz, `sin(time*3)`) are compliant but still removed by A11Y-MOT-002. Pre-launch notice on first run (one line, dismissible, retrievable in Settings > Comfort). | Frame-diff analyser over recorded turn-end, battle, event, game-over sequences: zero > 3 Hz luminance flashes. | TA / UXD | `time` uniform; tween durations >= 0.33 s for alternating states. |

## Motor Accessibility

### Touch targets and spacing

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-TCH-001 | Every interactive control has a hit area **>= 48 x 48 dp** (>= 44 pt on iOS is met by the same value); "Large targets" setting raises it to **56 dp**. Visual art may be smaller than the hit area (e.g. 24 dp glyph in a 48 dp button). `MIN_TOUCH` becomes `TBKit.dp(48)`. | Automated tree walk (`tools/a11y_audit.gd`) lists every Control with `focus_mode != NONE` or a click handler and asserts `size >= dp(48)` on both axes; zero violations on all screens. Fixes D5. | UIP | `custom_minimum_size`; `Control._has_point()` override or transparent padding for glyph buttons; `IconBtn(px >= 48)`, `Segmented` / `ListRow` height >= 48, `OptionButton` height >= 48, slider hit height >= 48 with grabber 28 dp. |
| A11Y-TCH-002 | Adjacent targets are separated by >= 8 dp (or are visually grouped rows with >= 48 dp pitch). Destructive buttons (Disband, Declare war, Delete save) are never adjacent to a primary action without 16 dp or a confirm step. | Audit walk checks sibling gaps; layout review. | UIP / UXD | Container `separation` constants. |
| A11Y-TCH-003 | Map targets: gonfalons and capital markers have a 48 dp hit area; taps within 12 dp of a border of two or more small provinces (province < 24 dp) open a **disambiguation sheet** listing up to 5 candidates in 48 dp rows; double tap/zoom is never required. | Test at max zoom-out on 360 dp phone: a user selects an intended 10 dp province in <= 2 taps. | UIP / TA | `map_view.gd.pick_at()` returns candidate list within radius; bottom sheet built with `K.modal` variant; `_tap_slop()` 16 px -> `dp(10)`. |
| A11Y-TCH-004 | Sliders (budget, etc.) have **-/+ steppers** (step 5 %, 1 % on long-press/hold repeat) and a numeric field; dragging is optional. | Budget modal completable with taps only. | UIP | `HSlider` + two `K.button` steppers; `value` set directly. |
| A11Y-TCH-005 | Activation on **release** and cancellable: pressing and sliding off a control cancels (SC 2.5.2). Applies to Buttons (default), `ChoiceCard`, `ListRow`, map taps, End Turn seal. | Manual: press, drag off, release does not fire. Fixes D7. | UIP | `Button.action_mode = ACTION_MODE_BUTTON_RELEASE`; `ChoiceCard._gui_input` fires on release if still inside `get_rect()`. |
| A11Y-TCH-006 | No time-dependent gestures: no long-press-only features, no double-tap-only features, no swipe-only dismissal. Long-press may exist only as a shortcut for an on-screen "..." action. Hold-repeat on steppers has a toggle: tap-only mode. | Feature inventory shows a visible control for each. | UXD / UIP | Review. |

### Gesture alternatives

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-GES-001 | Every pointer gesture has a single-pointer, button/keyboard equivalent (SC 2.5.1): drag-pan = **pan pad** (4 arrows + recenter) and arrow keys / WASD; pinch/wheel zoom = **+ / - buttons** (`zoom_by(1.4, true)`) and `+`/`-` keys; globe rotate = pan pad; flat/globe toggle = button. "Navigation controls" cluster is shown by default on touch when text scale >= 150 % or Large targets, optional otherwise. | With the cluster enabled, a tester performs: select a distant province, move an army, pan across the globe using only taps, one finger, one hand. | UIP | New small `TBNavPad` Control calling `map.drag_by()`, `map.zoom_by()`, `map.fly_to()`; `Input.is_action_pressed("tb_pan_*")`. |
| A11Y-GES-002 | Non-spatial route to every map verb: a **Provinces / Armies list** (searchable, sorted by name/alert) opens the province panel and flies to it; "Next army / next idle army / next alert" buttons; every on-map "move/attack" has a panel-button path with target chooser list. | All orders executable without touching the map after the list opens. | UIP / GC | `TBModals` list builder; `map.fly_to()`; `panel.move_requested`. |
| A11Y-GES-003 | Multi-touch is never required; two-finger pinch remains an optional shortcut. Inertia/flick can be switched off (also forced off by reduce-motion). | Disable multi-touch in test device: full game still playable. | UIP | `map_view._touches` handling untouched; `cfg.inertia`. |

### Keyboard, gamepad and remapping

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-KBD-001 | **Every** interactive control is reachable and operable by keyboard (SC 2.1.1): `focus_mode = FOCUS_ALL` for Buttons, OptionButton, sliders, LineEdit, Segmented items, ListRow, ChoiceCard, dock, seal. Custom `Control` widgets implement `_gui_input` for `ui_accept`. Gamepad (D-pad/A/B) works with no extra code because it drives the same `ui_*` actions. | Tab-through test on every screen with no mouse; automated: every Control with a handler has `focus_mode != NONE`. Gamepad smoke test (Xbox + generic) navigates menus, end turn. | UIP | `focus_mode`, `focus_neighbor_*`, `Control.grab_focus()`; replace `FOCUS_NONE` in `ui_kit.gd`, `hud_parts.gd`; `_unhandled_input`. |
| A11Y-KBD-002 | Logical focus order = visual reading order (top-left to bottom-right, RTL mirrored); modals trap focus and restore it to the opener on close; Esc / gamepad B closes the top modal; Tab never lands behind an overlay; focus starts on the primary safe action (never a destructive one). | Order walkthrough per screen recorded in UX spec; automated check that off-modal controls are not focusable while a modal is open. | UIP | `focus_next/previous`, `Control.focus_mode` toggled on overlay show, `_overlay` ordering, `FocusMode` restore. |
| A11Y-KBD-003 | **Visible focus ring** on every focusable element: >= 3 px (>= 4 px in HC) outline at >= 3:1 against both the control and its surroundings, offset outside the control, not colour-only (a corner-bracket shape plus ring). Never hidden by the paper frame. | Screenshot per control type and per theme; PAIRS check; fixes D3. | ART / UIP | Theme `focus` stylebox (`StyleBoxFlat` with `draw_center=false`, `border_width_*`, `expand_margin_*`); custom-drawn controls draw ring in `_draw()` when `has_focus()`. |
| A11Y-KBD-004 | **Map keyboard cursor**: arrow keys / D-pad move the selection to the neighbouring province nearest in that direction (neighbour graph + bearing); Enter selects/opens panel; Shift+Enter = secondary (move/attack target); `[` / `]` previous/next own army; `,` / `.` previous/next alert; Tab leaves the map to the HUD; a focused province shows the ring plus its hover card text. Cursor is a distinct on-map marker (static in reduce-motion). | A tester completes recruit, move, attack, end turn using only the keyboard. | UIP / GC | `map_view` `_unhandled_key_input`; neighbour data from `TBGame`; `province_hovered`/`province_picked` signals reused. |
| A11Y-KBD-005 | Default shortcuts (all remappable): **Space** End Turn (with confirm if unspent orders, A11Y-COG-004), **Esc** back/menu, **F1** help, **L** lens menu, **N** nations, **B** budget, **D** decrees, **A** Annals, **G** goals, **V** advisor, **S** save (Ctrl+S), **Tab/Shift+Tab** focus, **+/-** zoom, **Home** recentre on capital, **1-4** send share 25/50/75/100. Shortcuts show in tooltips and the Controls page. No shortcut requires two keys held together or key-chords as the only path; Ctrl/Shift variants are optional extras. | Controls page lists all; no unintended conflicts; keyboard-only run of a full turn. | UIP | `InputMap.add_action("tb_*")`; `Shortcut`/`InputEventKey`; `Button.shortcut`. |
| A11Y-KBD-006 | **Remapping**: Settings > Controls lists every `tb_*` action; click-to-capture rebinding for key, mouse button and gamepad button independently; conflict warning with swap/cancel; Reset per action and all; persisted. Esc/Enter-to-capture ambiguity handled by "Press key... (Esc cancels)". Sticky/toggle: no hold inputs exist (turn-based) - rule stays: any future hold input must offer a toggle. | Rebind every action to non-default keys, restart, all work; conflict prevented; bindings survive. | UIP | `InputMap.action_erase_events` / `action_add_event`; serialise `InputEvent` with `var_to_str` in `user://settings.cfg` section `[keys]`. |
| A11Y-KBD-007 | Input-method switching at any time without restart; on-screen prompts show the active method (key caps vs gamepad glyphs vs none on touch). | Mid-game switch updates prompts within one frame. | UIP | Last-event type check in `_input()`; `TBKit.prompt(action)`. |

### One-handed play, handedness and haptics

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-ONE-001 | Portrait phone is fully playable one-handed: every primary verb (select via lists, order, End Turn, close, back) is reachable in the lower 60 % of the screen; top-of-screen items are read-only information; modal primary and Back are in the pinned footer (already so in `K.modal`), and the top-right close glyph is a duplicate, not the only exit. | Reach test on a 6.7-inch phone with the thumb of one hand; checklist per screen. | UXD / UIP | `K.modal` footer; `hud.layout_for()`. |
| A11Y-ONE-002 | **Handedness / dock side** setting (Left, Right, Bottom; default Right-hand = seal right, dock left) mirrors dock, seal, nav pad and province-panel side; **HUD scale** 80-130 % independent of menu scale; "Simple HUD" preset (A11Y-COG-002). Free drag repositioning out of scope. | Each preset screenshot passes overlap check with ribbon, panel, toast column and safe area. | UIP | `hud.layout_for()` anchors/`layout_direction`; `keepouts()` stays truthful for label avoidance. |
| A11Y-HAP-001 | **Haptics** (mobile only; Off / Light / Standard; default Light): taps on primary actions, End Turn, event arrival, war declared against you, battle result win/loss (distinct patterns), error/blocked action. Every haptic has a visual and (optionally) audio twin; haptics are never the sole channel. | Each listed event vibrates; Off silences all; no vibration during text entry. | UIP / AUD | `Input.vibrate_handheld(duration_ms, amplitude)`; central `TBHaptics.play(kind)`. |

## Cognitive Accessibility

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-COG-001 | **Consistent placement**: End Turn bottom-right (or mirrored), date/nation top-left, lens/legend and map controls in fixed anchors, modal Back/primary in the footer in the same order on every modal, same icon = same meaning everywhere (icon dictionary in the pattern library). Layout is identical across languages and text sizes except reflow. | Screenshot diff of anchor positions across orientations/languages; icon audit. | UXD / UIP | `layout_for()` anchor tables; shared `K.modal`. |
| A11Y-COG-002 | **Progressive disclosure and Simple HUD**: default view shows <= 5 readouts (gold, manpower, wars, date, nation) plus an "info" chip expanding the rest; province panel shows <= 6 groups, order list sorted by relevance with "More"; any screen offers no more than 7 ungrouped controls; deep numbers one tap away. Players can choose Full HUD. | Counting audit per screen; Simple HUD toggle available; documented per screen in UX spec. | UXD / UIP | `P.Readout.visible`; `HFlowContainer`; `cfg.hud = simple/full`. |
| A11Y-COG-003 | **Plain-language option**: replaces abbreviations and jargon with full words ("MP" -> "Military points", "NAP" -> "Non-aggression pact"), spells numbers in full (1.2M -> "1.2 million") in text, and uses short sentences (<= 20 words, tooltips <= 2 sentences). Reading level target <= grade 8 for tooltips/advisor in all three languages. | Key audit: every string with an abbreviation has a `_plain` variant; spot-check in EN/RU/UZ. | LOC / UXD | `TBI18n.T(key)` looks up `key + "_plain"` first when `cfg.plain`; `K.fmt()` plain branch. |
| A11Y-COG-004 | **Confirm and undo**: confirmation (naming the consequence and a safe default) for declare war, break alliance/pact, disband/raze, large budget reset, End Turn with unspent mp/orders (shows the count and a "go back" action), overwrite save, delete save, leave to main menu, quit game. **Undo last order** for any order issued this turn before End Turn (infinite stack back to turn start); "Undo" is a visible button, not a gesture. Setting "Confirm all orders" (default off) adds a confirm to every command. | Each listed action confirms; undo restores exactly `TBGame` state; no confirm dialog for safe actions by default. | GC / UIP | Command log in `TBGame.apply()` with `undo_last()` (new; needs engine work, see Open Questions); `TBModals.confirm()`. |
| A11Y-COG-005 | **Prevent loss of state**: no information appears and disappears without a trace. Every toast/alert/event is mirrored to the Annals feed (A11Y-SR-003). Toast display time per A11Y-TIM-003. Advisor badge persists until the cause is gone. | Run a scripted 20-turn game; every toast appears in Annals. | UIP / GC | `hud.toast()` also calls the Annals writer. |
| A11Y-COG-006 | Tutorial and help are persistent: replay from Settings (exists as `tut_help`), per-screen "?" explaining the screen, glossary (Codex). First-run tutorial skippable; each step can be revisited. Goals are reachable in <= 2 taps with current objective text in full. | Replay works from the title and in-game. | UXD / UIP | `TBModals.tutorial()`, `codex()`. |
| A11Y-COG-007 | **Assist options** (difficulty-adjacent): exact battle outcome preview (exists), advisor hints on/off, "Show consequences" in tooltips, optional AI aggression/economy handicap via difficulty (documented parameters), no hidden randomness in preview (preview must match result). | Preview == result across 200 simulated battles. | GC / UXD | `TBHud.show_preview()` info dictionary from engine. |

## Auditory Accessibility

The game has no voiced dialogue; all sound is procedural SFX (`audio.gd`: tap, turn, event, ...). Principle: **every sound has a visual twin and every visual alert has an optional audio twin.**

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-AUD-001 | Independent buses and sliders **Master / Music / SFX / UI** (0-100 %, default 80) replacing on/off; mute-all toggle; settings reachable from the title and in-game. | Each slider changes only its bus; persists. | AUD / UIP | `AudioServer.add_bus`, `set_bus_volume_db`; `AudioStreamPlayer.bus`. |
| A11Y-AUD-002 | **Audio-twin table** (below) is complete: no gameplay-relevant sound is the only carrier of information; each has toast/badge/animation twin plus Annals line. New sounds require a row before merge. | Mute everything: a full 20-turn game is playable with no missed information. | AUD / UIP | Review + table. |
| A11Y-AUD-003 | No sudden loud sounds: all SFX normalised <= -12 dBFS peak, no sound > 1.0 s without fade; optional "Soft sounds" (UI sounds -6 dB, no high-frequency clicks). | Loudness check on generated WAVs. | AUD | `_tone()` gain; limiter on Master bus (`AudioEffectLimiter`). |
| A11Y-AUD-004 | Hearing-aid safe: every cue's primary content is < 4 kHz or has a lower-frequency partial (`tap` currently 1320/1980 Hz only - add a low partial or a visual twin as the carrier). | Spectrum review of `_snd[]`. | AUD | `_tone()` partials. |
| A11Y-AUD-005 | Mono: audio is authored mono and no meaning is carried by pan/spatial position; a global "Mono" switch folds any future stereo asset. | Review; switch present when stereo is introduced. | AUD | `AudioStreamWAV.stereo=false`; `AudioEffectPanner` bus fold-down if needed. |
| A11Y-AUD-006 | Captions: `[sound]` captions are the toast/Annals text above (e.g. "War declared on X"); optional on-screen **sound indicator** strip ("Alert" glyph + word) when sound is muted or "Visual alerts" is on. | Toggle shows the strip for events. | UIP | `hud.toast()`; strip control. |

| Sound | Meaning | Visual twin | Haptic twin | Annals line |
|-------|---------|-------------|-------------|-------------|
| `tap` | Control activated | Pressed state + focus ring | Light tick | No |
| `turn` | Turn resolved / new date | Date/turn readout animation (static when reduced), "Turn N" toast | Medium pulse | Yes |
| `event` | Event, offer or ultimatum arrived | Modal/prompt itself + Advisor badge + toast | Double tick | Yes |
| war / battle sounds | War declared, battle won/lost | Battle result banner with icon (check/cross), toast, war hatch appears | Distinct win/loss patterns | Yes |
| revolt / low stability warning | Province unrest | Advisor badge (shape), province marker glyph | Warning pulse | Yes |
| error / refused action | Action not allowed | Inline reason text next to the control | Short buzz | No |

## Motion, Time Pressure and Comfort

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-MOT-001 | **Reduce motion** switch (Settings > Comfort; also asked at first run). When on: no globe auto-spin on the title, no inertia flick, `fly_to` and zoom easing replaced by instant cut (or <= 100 ms cross-fade), no panel slide/scale/fade tweens, no pulsing seal, no breathing target/selection tint, army moves shown as instant jump with a trail marker, label fades off. Replaces use of `TBMapView.animate` as a player setting (`animate` stays the test override). | All motion items verified off; frame-diff of idle screen = 0 changed pixels after settle. Fixes D10. | UIP / TA | `TBMapView.reduce_motion` static var; shader `uniform float motion = 1.0` multiplies the `sin(time * ...)` terms; `if reduce_motion: skip tween`. |
| A11Y-MOT-002 | No camera shake, screen shake, motion blur, parallax, rolling-number counters or looping decorative animation in the project - at all, in any setting. Single non-looping transitions <= 250 ms. | Code/design review at every UI gate; grep for shake. | ART / UXD | Policy. |
| A11Y-MOT-004 | **Skippable and speed-controlled animations**: turn-end resolution playback (armies, AI moves) can be skipped by any tap/Enter/Space and run at 1x / 2x / Instant ("Resolve turns instantly" setting); no animation blocks input for > 400 ms without a skip. | End-turn playback skip works at any frame; instant mode shows summary only. | UIP / GC | `main.gd` async end-turn (`_turn_thread`); `Engine.time_scale` not used; explicit `skip` signal. |
| A11Y-TIM-001 | **No real-time pressure** in single-player and hot-seat: no timers, no auto-advance, no reflex input. Pause = the game is always idle between actions. | Review. | GC | n/a |
| A11Y-TIM-002 | Multiplayer turn timer (D11): host may choose **Off**, or a timer; each player may request/receive **x1.5 / x2 / x3** time (accessibility multiplier negotiated with the server, applied to the player's own clock only); timer never expires into an irreversible forced action without a warning at 25 % remaining that persists until acknowledged. Default for new rooms: Off. | Server test with multipliers; no forced End Turn while the multiplier is active. | GC | `mp_controller.gd` room options; authoritative server param. |
| A11Y-TIM-003 | Reading time: no actionable text auto-dismisses. Toasts: min 5 s + 50 ms per character over 40; setting "Keep alerts until dismissed"; hover and focus pause the timer; all mirrored to Annals; at most 5 stacked (queue, not drop). Fixes D9. | Timing check; 120-char toast lasts >= 9 s. | UIP | `hud.toast()` `create_timer(...)`, queue instead of `queue_free` of oldest. |
| A11Y-TIM-004 | **Hot-seat curtain**: between seats a full-screen curtain shows "Pass the device to <player>" with a >= 56 dp "I am <player>" button (or Enter); no timer, auto-hides previous player's data (privacy and attention reset); curtain is readable by a screen/speech reader and announces the seat; reduce-motion uses a cut. | Hot-seat run: no map data visible during the curtain; focus lands on the button. | UIP | Full-rect `ColorRect` in `_overlay`; `seat_tag` in hud; TTS (A11Y-SR-004). |

## Screen Reader, Semantics and the Annals Feed

Godot 4.4.1 has **no AccessKit / OS screen-reader integration** (it arrives in 4.5+, desktop first; mobile screen-reader coverage must be verified when upgrading). Rule: build the semantic layer now, bind it to the engine API later, and ship self-voicing plus a text mirror today.

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-SR-001 | **Semantic layer**: every interactive or informative Control gets an accessible name, role and description through one helper `TBKit.a11y(ctrl, name, role, desc)` which sets `tooltip_text` (visible on hover/focus/long-press) and stores `meta("a11y")`. On engine >= 4.5 the helper also sets the AccessKit properties; no screen needs rewriting. Icon-only buttons always have a name. | Audit walk: zero focusable controls without a name; zero images without text alternative. | UIP | `Control.tooltip_text`, `set_meta`; later `accessibility_name/description` (4.5+). |
| A11Y-SR-002 | Map semantics: any province can be described in one sentence ("Samarkand, owned by Timurids, at war, 12,000 troops, stability 62") via hover card, focus and the Province list; the same sentence is the TTS and tooltip text. | Sentence generated for all lenses; <= 25 words. | UIP / GC | `TBProvincePanel` data; `TBLenses` value to text. |
| A11Y-SR-003 | **Annals feed as text-log mirror**: the existing Annals (`chronicle`) records every toast, alert, event, order result, diplomatic change, battle result and turn summary as plain text with turn/date, in chronological order, filterable (All / Mine / Wars / Alerts), each line focusable and linked to a province (fly-to). A compact **live strip** (one line, `Label` with `aria-live`-like semantics) shows the latest entry. Retains >= 500 entries per game, exportable/copyable. | Scripted game: every toast present in Annals; copy button copies text; keyboard-navigable. | UIP / GC | `TBModals.chronicle`, `TBChronicle`; `ItemList` or `VBoxContainer` of focusable Labels; `DisplayServer.clipboard_set`. |
| A11Y-SR-004 | **Self-voicing (TTS)** option (default off; offered at first run when voices exist): speaks focus changes (name + role + state), new Annals lines, turn start, hot-seat curtain; interrupt on new focus; rate/volume sliders; EN/RU/UZ voice selection with fallback and a visible warning when no voice for the language exists. Disabled automatically if the OS reader is detected (future). | TTS speaks the A11Y-SR-001 name for 20 random controls; stops on `Esc`. | UIP | `DisplayServer.tts_get_voices_for_language()`, `tts_speak(text, voice, volume, pitch, rate, utterance_id, interrupt)`, `tts_stop()`. |
| A11Y-SR-005 | State changes are announced as text: selection, toggle state ("on"/"off"), slider values, disabled reason. Do not rely on glyphs alone. | Walkthrough with TTS. | UIP | Same helper. |

## Localisation, Layout Safety and Persistence

| ID | Rule | Acceptance test | Owner | Godot mechanism |
|----|------|-----------------|-------|-----------------|
| A11Y-LOC-001 | EN / RU / UZ (Latin) at **+35 %** length (RU worst case) and a **+60 % pseudo-locale** (`[!! ... !!]` wrapper): no overflow, truncation of essential text or overlapping at any text scale. | Pseudo-locale screenshot matrix; automated overflow check (`get_minimum_size() > size`). | LOC / UIP | Debug language `qps` in `TBI18n`; `Control.clip_text` OFF for essential text; `autowrap_mode`. |
| A11Y-LOC-002 | Plain-language and readable-font variants (A11Y-TXT-004, A11Y-COG-003) exist in every language; Uzbek apostrophe glyphs (o', g') render with the chosen font; date/number formats are locale-aware. | Glyph coverage test in all fonts. | LOC / UIP | Font fallbacks list; `TranslationServer`. |
| A11Y-LOC-003 | No fixed-width assumptions: replace `draw_string` with clipped width by `Label` + `text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS` plus full text on focus/tooltip; no text baked into drawn glyphs; counts and plurals use ICU-style keys. | Grep for `draw_string` with `size.x - N` pattern: zero; overflow test. | UIP | `Label`, `TextServer`. |
| A11Y-LOC-004 | **RTL-ready layout** (no RTL language ships, but additions must not require rewrites): containers use `layout_direction = INHERITED`, start/end semantics, mirrored icons only where directional (arrows, back), no `offset_left`-only anchoring in new UI, numbers stay LTR; verified with a mirrored pseudo-locale on Settings and one modal. | Mirrored screenshots pass. | UIP | `Control.layout_direction`, `Control.text_direction`, `Window.set_layout_direction`. |
| A11Y-SAF-001 | **Safe areas**: all UI (including toasts, panel, nav pad, seal, dock, modals) stays inside `DisplayServer.get_display_safe_area()` on notched phones and honours the gesture bar; map may extend to the edge but interactive elements must not. "Extra margin" setting (0 / 8 / 16 dp). | Notch/cutout emulator (Android 14 cutout, iPhone 15 Dynamic Island) screenshots; no control within the unsafe region. | UIP | `main.gd._apply_safe_area()` (exists) + new margin; re-run on `size_changed` and orientation change. |
| A11Y-SAF-002 | Orientation: both orientations supported; rotation never loses state (open modal, selection, focus). Layout works down to 360x640 dp portrait and 640x360 dp landscape. | Rotate during each modal. | UIP | `resized`, `layout_for()`. |
| A11Y-SET-001 | **Persistence**: all accessibility settings persist in `user://settings.cfg` (`[tb]` flat keys below, `[keys]` bindings), are device-wide, apply immediately with live preview, survive reinstall via platform backup where available, and are applied before the first frame of the title screen. | Kill/restart: values retained; first frame honours text scale and theme. | UIP | `main.gd._load_cfg()` must run before `K.theme()` (fixes D10); `ConfigFile`. |
| A11Y-SET-002 | Safe defaults and discoverability: first run shows a one-screen "Comfort and access" page (text size preview, high contrast, colour vision, reduce motion, self-voicing, sound) with a skip; every setting is <= 2 taps from the title and from the in-game dock gear; "Reset accessibility to defaults" with confirm; a settings search/"Jump to" chip row at the top of the page. | Tap count measured; reset works. | UXD / UIP | `modals.settings()` rebuilt as tabbed page. |

### Settings screen information architecture

`Settings` has 5 tabs (`Segmented` header; one column on portrait, two on wide landscape per existing `wide` logic). Footer (pinned): Reset, Main menu, Back. Keys live in `main.gd cfg`.

| Tab | Setting | Widget | Values (default) | cfg key |
|-----|---------|--------|------------------|---------|
| Display | Language | Segmented | EN / RU / UZ (system) | `lang` |
| Display | Text size | Segmented + live preview | 100 / 125 / 150 / 200 % (100) | `text_scale` |
| Display | Layout scale | Segmented | Small / Normal / Large (Normal) | `ui` |
| Display | HUD scale | Stepper | 80-130 % (100) | `hud_scale` |
| Display | Theme | Segmented | Paper / High contrast light / High contrast dark (Paper) | `ui_theme` |
| Display | Colour vision | Segmented | Off / Deuteranopia / Protanopia / Tritanopia (Off) | `cvd` |
| Display | Map style | Segmented | Standard / Parchment / High contrast (Standard) | `theme` |
| Display | Readable fonts | Toggle | Off | `readable_fonts` |
| Display | Always show all labels | Toggle | Off | `all_labels` |
| Display | Brightness | Stepper | -30..+30 % (0) | `brightness` |
| Display | Map view / Quality / Perf overlay | Segmented | existing | `view`, `quality`, `perf` |
| Controls | Handedness / dock side | Segmented | Right / Left / Bottom (Right) | `hand` |
| Controls | Target size | Segmented | Standard 48 dp / Large 56 dp | `touch_large` |
| Controls | Navigation pad (pan, zoom) | Segmented | Auto / On / Off (Auto) | `navpad` |
| Controls | Map inertia | Toggle | On | `inertia` |
| Controls | Keyboard and gamepad bindings | List page | See A11Y-KBD-006 | `[keys]` |
| Controls | Haptics | Segmented | Off / Light / Standard (Light, mobile) | `haptics` |
| Controls | Safe-area margin | Segmented | 0 / 8 / 16 dp (0) | `safe_margin` |
| Sound | Master / Music / SFX / UI | Slider + steppers | 0-100 % (80) | `vol_*` |
| Sound | Soft sounds | Toggle | Off | `soft_sounds` |
| Sound | Visual alerts strip | Toggle | Off (forced on when muted) | `visual_alerts` |
| Comfort | Reduce motion | Toggle | Off (ask at first run) | `reduce_motion` |
| Comfort | Resolve turns | Segmented | Animated / Fast / Instant (Animated) | `turn_speed` |
| Comfort | Alerts stay until dismissed | Toggle | Off | `toast_sticky` |
| Comfort | HUD detail | Segmented | Simple / Full (Full; Simple at 200 % portrait) | `hud` |
| Comfort | Plain language | Toggle | Off | `plain` |
| Comfort | Confirm all orders | Toggle | Off | `confirm_all` |
| Comfort | Self-voicing (TTS) | Toggle + rate/voice | Off | `tts`, `tts_rate`, `tts_voice` |
| Comfort | Photosensitivity notice / Tutorial replay | Buttons | n/a | n/a |
| Game | Difficulty, hot-seat curtain, MP timer multiplier | existing + new | per A11Y-TIM | `difficulty`, `mp_timer_mult` |

## Platform Accessibility API Integration

| Platform | API / Standard | Features planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| Mobile | Material 48 dp / 12 sp, HIG 44 pt; TalkBack / VoiceOver | Dp sizing (A11Y-TXT-005), safe area, `Input.vibrate_handheld`, `DisplayServer.tts_*` | Not Started | No TalkBack/VoiceOver on 4.4.1; system font scale and reduced-motion flags are not exposed to GDScript, so a first-run prompt replaces them. |
| Windows | UIA / Narrator / NVDA; Windows High Contrast | Keyboard operation, focus ring, own HC themes; TTS self-voicing | Not Started | OS HC and Narrator not auto-detected on 4.4.1; AccessKit (4.5+) is the upgrade path (Open Question 1). |
| All | `DisplayServer.tts_*` | Self-voicing (A11Y-SR-004) | Not Started | Voice availability varies; Uzbek often missing - fall back and warn. |

## Per-Feature Accessibility Matrix

| System | Visual concerns | Motor concerns | Cognitive concerns | Auditory concerns | Addressed | Notes |
|--------|----------------|----------------|--------------------|-------------------|-----------|-------|
| Globe / flat map | Colour-only owners, small provinces, labels on variable fills | Drag/pinch only, tiny targets | Zoom-disclosed info | None | Not Started | CVD-002..005, GES-001..003, TCH-003, CON-006/007 |
| Lenses and legend | 10 colour ramps | Dropdown 34 px | Which lens am I in? | None | Not Started | CVD-001/005, TCH-001; lens name always shown in the chip |
| Province panel and orders | Long action list, small text | Share buttons, small rows | 6+ groups | Click sounds | Not Started | COG-002, TCH-001, KBD-004 |
| Armies, movement, battle preview | Red/green bar, gonfalons | Target on map | Predicted outcome | Battle sounds | Not Started | CVD-006, GES-002, COG-007, AUD twins |
| Diplomacy / Nations | Relation colours | List scrolling | 250 nations | None | Not Started | CVD-004, search + filters |
| Budget | Sliders | Drag-only sliders | Trade-offs | None | Not Started | TCH-004 |
| Decrees / events / ultimatums | Paper cards | `ChoiceCard` mouse-only | Consequence reading | Event chime | Not Started | TCH-005, KBD-001, COG-004, plain language |
| Annals / Advisor / Goals | Text density | Row targets | Memory | None | Not Started | SR-003, COG-005/006 |
| HUD ribbon and dock | 9 readouts, 9-10 px text | 46 px buttons | Overload | None | Not Started | TXT-002/003, COG-002, ONE-002 |
| End turn / turn resolve | Pulsing seal | Reachability | Confirm | Turn chime | Not Started | MOT-004, COG-004, ONE-001 |
| Hot-seat | Hidden info | Hand-off | Whose turn? | None | Not Started | TIM-004 |
| Multiplayer | Lobby text | Typing | Timer pressure | Notification sound | Not Started | TIM-002 |
| Save/Load, Settings, Title, Honours, Codex | Contrast, text | Targets | Overwrite risk | None | Not Started | COG-004, SET-001/002 |

## Accessibility Test Plan

Tooling to build in the redo: `tools/a11y_audit.gd` (headless SceneTree script that opens every screen at every settings combination, walks the Control tree, and reports target sizes in dp, min font size, focus_mode, names, contrast pairs), `tools/cvd_sim.gd` (Machado matrices over screenshots), `tools/pseudo_loc.gd`, frame-diff flash analyser. Matrix per run: viewport {540x960, 360x780 dp, 891x411 dp, 1920x1080} x text {100, 200 %} x theme {Paper, HC light, HC dark} x cvd {Off, deut, prot, trit} x lang {EN, RU, UZ, pseudo}; PR gate runs a reduced matrix, Phase-4 runs the full one.

| Feature | Test method | Test cases | Pass criteria | Responsible | Status |
|---------|-------------|-----------|---------------|-------------|--------|
| Text size and reflow | Automated + screenshots | All screens at 100-200 % | No clipping or overlap; all text >= floor | UIP / QA | Not Started |
| Contrast | Automated PAIRS + screenshot sampler | Every token pair, every plate type, map labels on 10 lenses | A11Y-CON-001/002/004/006 thresholds | UIP / TA | Not Started |
| CVD | Simulation + 3 CVD testers | Every lens, hover, war scene, battle preview | Thresholds in CVD-001/002; testers complete the "name owner / find enemy / find ally" task without help | ART / TA / QA | Not Started |
| Touch targets | Automated tree walk + device test | All screens on 2 phones, 1 tablet | Zero targets < 48 dp; one-handed reach test | UIP / QA | Not Started |
| Keyboard and gamepad | Manual no-mouse run | Title to game over, full turn, remap, modals | Every function reachable; focus visible and logical | QA | Not Started |
| Remapping | Manual | Rebind all, restart | A11Y-KBD-006 | QA | Not Started |
| Reduce motion | Manual + frame diff | All screens, turn resolve | A11Y-MOT-001/004 | QA / TA | Not Started |
| Photosensitivity | Flash analyser | Battle, event, game-over, title | Zero > 3 Hz flashes | TA | Not Started |
| Audio twins | Mute run | 20-turn scripted game | A11Y-AUD-002 | QA | Not Started |
| Annals mirror and TTS | Manual | Scripted game | Every toast in Annals; TTS names for controls | QA | Not Started |
| Localisation | Pseudo-locale + native review | EN/RU/UZ + RTL mirror | A11Y-LOC-001..004 | LOC / QA | Not Started |
| Safe area / orientation | Emulator + device with notch | Rotate during modals | A11Y-SAF-001/002 | QA | Not Started |
| Persistence | Manual | Change all, kill app, reboot | A11Y-SET-001 | QA | Not Started |
| User testing | 3 CVD, 2 low-vision/large-text, 2 one-handed/motor, 1 screen-reader user | Full 60-minute session each | No session-stopping barrier; every issue logged | producer | Not Started |

## Phase-4 Verification Checklist

Gate = all BLOCKING items checked, or each unchecked item has a producer-approved waiver recorded in Audit History.

- [ ] D1-D11 (baseline defects) each verified closed
- [ ] A11Y-TXT: four text sizes work on every screen at all four viewports; min font floor holds; dp scaling verified on phone landscape
- [ ] A11Y-CON: PAIRS test green; HC light and HC dark complete (menus and map); toasts/banner/legend fixed
- [ ] A11Y-CVD: three CVD palettes; adjacency colouring; relation patterns + glyphs on map; legend letters; colour-as-only table all "Done"
- [ ] A11Y-TCH: audit walk shows zero < 48 dp targets; sliders have steppers; release-activation everywhere; disambiguation sheet works
- [ ] A11Y-GES: pan pad, zoom buttons, province/army list; no multi-touch dependency
- [ ] A11Y-KBD: focus ring visible; full keyboard and gamepad run; map cursor; shortcuts; remapping persists
- [ ] A11Y-SR: semantic helper on every control; Annals mirrors every toast; TTS self-voicing works in EN and RU (UZ with fallback warning)
- [ ] A11Y-AUD: four volume buses; twin table complete; mute-run passes; no loud peaks
- [ ] A11Y-MOT/TIM: reduce motion complete; no shake; flash analyser clean; skippable turn playback; hot-seat curtain; MP timer off/multiplier; toast timing
- [ ] A11Y-COG: Simple HUD; plain language keys; confirms and undo; persistent help
- [ ] A11Y-LOC/SAF: pseudo-locale clean; RTL mirror test; safe areas on notched devices; rotation keeps state
- [ ] A11Y-SET: first-run page, <= 2 taps to every setting, persistence before first frame, reset
- [ ] Per-feature matrix: every row "Addressed = Yes" or a documented limitation
- [ ] User-testing report filed under `production/qa/accessibility/`
- [ ] Known Intentional Limitations reviewed and accepted by creative director and producer

## Known Intentional Limitations

| Feature | Tier required | Why not included | Risk / impact | Mitigation |
|---------|---------------|------------------|---------------|------------|
| OS screen-reader support (TalkBack, VoiceOver, NVDA) | Comprehensive | Godot 4.4.1 has no AccessKit; engine upgrade is a producer decision | Blind players cannot use the game with their own reader | Self-voicing TTS, Annals text mirror, semantic layer ready for 4.5+ upgrade (Open Question 1); state in store listing |
| Free HUD drag repositioning | Comprehensive | Procedural HUD with anchor logic; low value for turn-based | Players needing a custom layout | Handedness, dock side, HUD scale, Simple HUD |
| Subtitle styling | Standard | No voiced dialogue | None | Text-only narrative; Annals and readable fonts |
| Third-party audit | Exemplary | Not budgeted | Unknown blind spots | Internal audit, user panel, test plan |
| Uzbek TTS voice may be missing | Comprehensive | Depends on OS voice packs | Self-voicing unavailable in UZ | Warning + RU/EN fallback voice; Annals text |
| Historical nation colours in Off mode | Standard | Flags/identity art | Some neighbours similar | Always-on borders, labels, optional CVD palette |

## Audit History

| Date | Auditor | Type | Scope | Findings summary | Status |
|------|---------|------|-------|------------------|--------|
| 2026-10-06 | accessibility-specialist | Code and palette review (no running build) | `godot/src/ui/*.gd`, `render/*` | 11 baseline defects D1-D11 (contrast, focus, targets, colour-only, timing); criteria not checkable without a build are NOT ASSESSED | Open |

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 | https://www.w3.org/TR/WCAG21/ | Contrast, resize text, target size, pointer gestures |
| Machado et al. 2009 CVD model; Okabe-Ito palette | https://jfly.uni-koeln.de/color/ | Simulation and safe palette |
| Coblis | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Screenshot simulation |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | User testing |

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| 1. Upgrade Godot to >= 4.5 for AccessKit (and verify Android/iOS screen-reader coverage), or ship self-voicing only? | producer / technical-director | Before UI-redo Phase 2 | Unresolved |
| 2. Does `TBGame.apply()` support a command log for per-turn undo (A11Y-COG-004), or is engine work needed? | lead-programmer | Before Phase 2 | Unresolved |
| 3. Which `pal` texture channel/row can carry the relation class code (A11Y-CVD-004) without breaking the 4-row layout? | technical-artist | Before Phase 2 | Unresolved |
| 4. Multiplayer server: can the turn timer accept a per-player multiplier or be disabled (A11Y-TIM-002)? | network-programmer | Before MP work | Unresolved |
| 5. Budget for an external user panel (CVD, low vision, motor, blind) before release? | producer | Before Phase 4 | Unresolved |
| 6. Creative director sign-off that Comprehensive is met with OS-reader support replaced by self-voicing (see limitation 1). | creative-director | Before gate | Unresolved |
