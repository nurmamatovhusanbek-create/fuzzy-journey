# UX Specification: Modal System (all panel and dialog screens)

> **Status**: Draft
> **Author**: ux-designer
> **Last Updated**: 2026-10-06
> **Screen / Flow Name**: `TBPanel` (replaces `TBKit.modal` and its 15+ call sites in `modals.gd`)
> **Platform Target**: Android, iOS, Windows. Touch-first, mouse/keyboard supported. 540x960 portrait to 2340x1080 landscape phone to 1920x1080 desktop
> **Related GDDs**: none (UI redo, input `design/game-brief.md`)
> **Related ADRs**: none yet (see Open Questions)
> **Related UX Specs**: `hud.md` (zones A-G, units `u`, rail, ticker, End Turn), `command-card.md` (selection, details drawer), `interaction-patterns.md`, `main-menu.md`, `nation-pick.md`
> **Units**: `u` as in `hud.md` (logical px, about 1 dp on phones). Profiles: D 1280x720u, L 900x415u, S 800x360u, P 360x640u. Touch target 48u, mouse 32u, text 12u minimum.
> **Accessibility Tier**: Comprehensive
> **Template**: UX Spec

---

## 1. Purpose and Player Need

**Player need.** Strategy players need to read, tune and decide without losing the thread of the map. Today every screen is a centered paper card 380-920 px wide with an ornament rule, a footer "Back" bar and its own ad-hoc layout. Popups on landscape are narrow (Budget 460, Chronicle 560), the footer Back wastes the pinned slot, and the same widget (segmented underline) is both tab and setting.

**Player goal.** Find the number or lever for a decision in one glance, change it, and be back on the map in one gesture.

**Game goal.** One container system with one set of rules, so each of the 15+ screens is a content recipe, not a layout project; keeps the map visible whenever the screen is about the map (pillars 1, 3, 5).

**Creative direction applied.** Paper-table material stays; hierarchy, grouping and info chips do the work (Total War / HoI4 command table). Wide layouts on landscape.

## 2. Player Context on Arrival

| Question | Answer |
|----------|--------|
| What was the player doing? | Mid-turn on the map, or on the title/setup screens |
| Emotional state | Calm staff-officer focus; spikes for events, ultimatums, game over |
| Cognitive load | Medium: holding a plan for the turn in mind |
| Already known | Ribbon numbers, current selection, alert chips |
| Most likely goal | Check one figure, change one setting, enact one thing, leave |
| Afraid of | Losing the map, mis-tapping a destructive button, not understanding a cost |

**Emotional target**: a clear, quiet desk; everything has a place and a reason.
## 3. Navigation Position

```
Game (map + HUD)
  ├── Dialog        event, ultimatum, confirm, pass-device, game over*, tutorial step
  ├── Drawer/Sheet  Budget, Annals, Council (Advisor+Goals)
  └── Wide panel/Page  Nations (list, rankings, nation card), Decisions, Menu hub
        └── Menu hub → Saves, Settings, How to play (Codex+Tutorial), Honours, Main menu
Title → New game page (era, difficulty, players) → Pick (map) → Game
```
\* Game over is a Page (blocking), listed as dialog family for dismissal rules.
**Modal behaviour**: Dialog = modal (backdrop, focus trap). Drawer/Sheet = non-modal over the map (map pannable; orders blocked while a Sheet is above 60 % height). Wide panel/Page = modal. **Depth rule**: one panel plus at most one dialog. Opening a panel while another is open *replaces* it (120 ms crossfade); drill-in inside a panel (Nations list to Nation detail on portrait) pushes within the same container with a header Back arrow.

**Reachability**

| Entry point | Trigger | Notes |
|-------------|---------|-------|
| Screens rail (hud.md zone B) / shortcut | Tap, `N B D C Y`, Esc to Menu | rail primary: Nations, Budget, Decrees, Council (Advice dot); More: Annals, Menu (see Open Questions) |
| Ribbon chip | Tap chip (gold to Budget, army to Nations, infamy to Codex topic) | chips are shortcuts, not new entry points |
| Map | command card owner link or Diplomacy verb to Nations detail | province details stay in the card's Details drawer |
| System | Event/ultimatum queue, turn end, game over, hot-seat hand-over | shown one at a time |
| Title | Continue/Load/Settings/Honours/New game | uses same containers |
## 4. Entry and Exit Points

| Trigger | Source | Transition | Data in |
|---------|--------|-----------|---------|
| Open from rail/shortcut | map | Dialog scale+fade 160; Drawer slide 180; Page fade 160 | `g`, `cfg`, screen id, optional deep-link (nation id, tab, filter) |
| Replace panel | other panel | crossfade 120 | same |
| Event queued | `show_events()` | Dialog; next shows after answer | event dict |

| Exit | Destination | Data out | Notes |
|------|-------------|----------|-------|
| X (header), Esc, Android Back | map; focus returns to opener | none (changes applied live) | all share `pop()` |
| Backdrop tap | map | none | **info dialogs only**; never event, confirm with input, game over, pass-device |
| Primary footer action | map or next step | command via `on_cmd` | closes only if the action completes the task |
| "Show on map" / row jump | map, camera flies, selection set | province/nation id | panel closes on P, stays on landscape drawer |

## 5. Layout Specification

### 5.1 Wireframes

Shared anatomy (every presentation): **Header bar, Tab row (optional), Scrolling body, Pinned footer (optional)**.

```
WIDE PANEL (D/L/S landscape, 960 x 600u on D)      DRAWER (landscape right rail, 400u on D)
╔══════════════════════════════════════════╗       ┌─────────────────────────────┐
║ [◈] NATIONS      (chip: 62 · #4)    [find][✕]║     │ [◈] BUDGET   net +112/t  [✕]│
╟[Nations][Rankings]──────────────────────────╢     ├[Allocation][Presets]────────┤
║ list (filters, search, sort)  │ detail pane  ║    │ body scrolls                │
║ ▸ row row row ...             │ facts | acts ║    │  ...                        │
╟──────────────────────────────────────────────╢    ├─────────────────────────────┤
║ [Secondary]                    [PRIMARY act] ║   │ [Revert]          [Done]    │
╚══════════════════════════════════════════╝       └──── (ends above End Turn) ──┘

SHEET (P portrait)                     PAGE (P portrait)               DIALOG (all)
┌────────── map ──────────┐            ┌[←] SETTINGS          ┐         ┌──────────────────────┐
│                         │            ├[Display][Audio][Acc.]┤         │ kicker               │
├───── ▬▬ (drag handle) ──┤            │ body                 │         │ TITLE                │
│ [◈] BUDGET        [✕]   │            │                      │         │ text / choice cards  │
│ body (56 % tall, drags  │            ├──────────────────────┤         │ [Cancel]  [CONFIRM]  │
│ to 92 %)                │            │ [secondary] [PRIMARY]│         └──────────────────────┘
├─ rail + End Turn visible ┤            └──────────────────────┘
```

### 5.2 Size profiles and presentation (units `u`)

Profile comes from viewport in `u`, input type and physical size, **never from logical width alone**.

| Profile | Dialog | Drawer / Sheet | Wide panel / Page |
|---------|--------|----------------|-------------------|
| **P** portrait (360x640u) | width min(vw - 32, 328); wide dialog n/a | **Sheet**: full width, snap 56 % / 92 % height, handle, rises above rail and End Turn | **Page**: full screen minus safe area, header Back arrow, no X |
| **L** landscape phone (900x415u) | 360-440; wide dialog 640 | **Drawer** 340, top = bar A bottom, bottom = End Turn top minus 8 | w = 90 % vw (810), h = 92 % vh (380) |
| **S** short (800x360u) | same as L | **Drawer** 320 | w = 90 % vw (720), h = 92 % vh (331); footer actions move into header |
| **D** desktop / tablet (1280x720u) | 400-480; wide dialog 640 | **Drawer** 400 | w = clamp(90 % vw, 640, 960), h = min(88 % vh, 600) |

On L and S the command card collapses to its header while a drawer is open (selection kept).

### 5.3 Presentation decision rule

| Question (ask in order) | Presentation |
|---|---|
| Blocking, needs an answer, fits one screen? | **Dialog** |
| About tuning/reading something the map shows, so the map should stay live? | **Drawer** (landscape) / **Sheet** (portrait) |
| Browse, compare, configure; needs width; map not the subject (includes title and setup) | **Wide panel** / **Page** |

Right-rail rule: the right rail holds **one** management drawer at a time. Province details are the command card's own Details drawer (`command-card.md`), not a right-rail occupant. Top bar A stays live above all drawers; End Turn stays visible and tappable (the drawer stops above it).

### 5.4 Width rules and two-column rules

| Rule | Spec |
|------|------|
| Body text column | max 66 characters (about 440u); wider panels split into columns, never stretch a paragraph |
| Single column | any container under 640u inner width: all Drawers, Sheets, Dialogs, P Pages |
| Two columns | only wide panels at 640u inner width or more (all of D, L, S), only when the content has two independent groups |
| Column roles | **Left = what is** (list, facts, status). **Right = what you can do** (detail, actions, parameters). Equal width unless master-detail: master 240-300u, detail the rest |
| Scrolling | one scroll per column (master-detail) or one shared scroll (two groups of equal length); never nested scrolls horizontally |
| Collapse | below 640u: right column stacks under the left in reading order; master-detail becomes list page then detail page (push) |
| Wide dialog (640u) | landscape only, two columns: narrative left, choices right (Events, Game over) |

### 5.5 Density rule for lists

| Profile | Row height | Lines | Notes |
|---------|-----------|-------|-------|
| D pointer | 36 | 1 (+1 dim) | dense by default; Settings "Density" can switch to comfortable |
| L / S touch | 48 | 1-2 | 48u is the touch minimum |
| P touch | 52 | 1-2 | |
Rules: **one entity per row, at most two text lines, at most three chips**; trailing figure right-aligned mono; whole row is the target; one trailing action max; group by sticky section header instead of repeating a date/category per row; hairline separators only (no ornament rules, no per-row panels); more than 12 rows requires search and sort; more than 60 rows is pooled; never silently truncate (show "Showing 120 of 412, [Older]").

### 5.6 Component inventory and shared anatomy

| Component | Spec | Reuses |
|-----------|------|--------|
| Header bar | 48u high (S: 44), flat band, one 1 px brass hairline (no double rule). Left: glyph 24 (page: Back arrow); title Cinzel 20u single line, ellipsis; optional **context chip** (count/net figure); right: optional header action (search/filter, 48u), **X close 48x48u** (landscape/dialog). No ornament diamond | P-22, P-04 |
| Tab row | optional, pinned under header, 44u (48u touch), max 5 tabs | P-09 |
| Body | `ScrollContainer`, visible 3 px scrollbar, fade edge 16 px, `follow_focus` | P-11 |
| Footer | optional, pinned, 56u, 1 px top rule, safe-area bottom inset; **secondary left, primary right (min 40 % width)**; max 2 buttons; hidden on live-apply screens. The footer "Back" button is removed (X, Esc, Back key exist) | P-22 |
| Backdrop | Dialog and Page only, 70 % dark (not 86 %), map still faintly readable; Drawer/Sheet no backdrop | |
| Drag handle | Sheet: 36 x 4u plus 48u touch area; double-tap toggles snap | |
| Option cards | Event choices | neutral style, no pre-highlighted primary |

**Decoration budget** (art-director to confirm the visual form): remove corner brackets, ornament rule under titles, paper cloud texture behind small text; keep laid-paper fill, one 1 px ink border, brass accent for selected/primary, wax plate for the single primary. Title uses Cinzel; captions use Alegreya/mono at 12 minimum; borders and type weight lighter (earlier feedback: "too bold").

**Godot recipe.** One `TBPanel` factory: `TBPanel.open(kind, title, glyph, opts) -> {root, header, tabs, body, footer}` with `kind in {DIALOG, DRAWER, PAGE}`; the presentation is resolved from the size class. Node tree: `Control` (full rect) > [`ColorRect` backdrop (STOP) for DIALOG/PAGE only] > `PanelContainer` (anchored per class) > `VBoxContainer` > header `HBoxContainer`, `TabBar`, body `ScrollContainer` (`size_flags_vertical = EXPAND_FILL`), footer `HBoxContainer`. Layout comes from anchors and size flags; delete the current `fit` height hack (a `ScrollContainer` has zero min height). Drawer root `mouse_filter = STOP` only on the panel rect; elsewhere `PASS`/`IGNORE` so the map stays interactive. Safe area via existing `offset_*` on the root. Sheet drag via `_gui_input` on the handle with a `Tween` snap.

### 5.7 Information hierarchy and per-screen recommendations

Order everywhere: **headline number or status** (context chip), then the **lever**, then the **reason/effect**, then history/detail behind a tab or scroll. IA merges (rail stays at 4 primary plus More, as hud.md): Goals + Advisor = **Council**; Save, Options, How to play, Honours, Main menu = **Menu hub**.

| Screen | Presentation (landscape / portrait) | Moves up | Dropped or changed |
|--------|-------------------------------------|----------|--------------------|
| **Nations** (list + Statistics + Nation card, one screen) | Wide panel, master-detail / Page list then detail | Left: list (rank, flag, name, provinces, army, relation glyph) with filter chips All, Neighbours, At war, Allies and search; right: **Nation card** for the selected row (ruler, facts grid, relations, actions) with "Show on map" in footer. Tab 2 **Rankings** (chart + table) | The 60-row cap; separate Nation card modal; "Wars" as a separate dock path becomes the At-war filter |
| **Statistics** (tab of Nations) | same panel, tab Rankings | Metric segmented (Provinces / Army / Gold / Tech), 6 series plus You, legend chips that toggle series | Chart alone: add a **Table** toggle (same numbers, accessible alternative), distinct dash patterns per series, direct end-labels |
| **Budget** | Drawer / Sheet (map stays live, top-bar numbers roll) | Context chip **Net/turn** with before to after; four allocation sliders each with its effect line ("Tax 50 %: +112 gold, unrest +2"); optional Preset segmented (Balanced / War / Growth) | Footer Back; label-only sliders; footer = [Revert] [Done] |
| **Decisions** | Wide panel two-column grid (current structure works) / Page | Doctrine as a 3-way segmented with the current one selected and its effect; decisions grouped Active (with turns left), Available, Unavailable; cost chips (gold, military points) with X glyph when unaffordable; one-line **reason** on locked rows | Per-row oversized buttons; description lines over two; Enact is the row trailing action |
| **Annals** (Chronicle) | Drawer / Sheet | Filter chips Mine, All, War, Diplomacy, Events; rows grouped by turn with a sticky "Turn 12 - 1804" header; whole row jumps to the map; bad news with a v glyph | Date repeated per row; fixed 360 px scroll box; cap 120 silently (use "Older") |
| **Goals** | Drawer / Sheet, tab 2 of **Council** | Closest goal first with % and the missing amount ("-2,300 gold"); meters with 25/50/75 ticks; realms section only when over 25 % | Full list when only the top 3 matter: show top 3, "All goals" expands |
| **Advisor** | Drawer / Sheet, tab 1 of **Council** | Alerts sorted by severity with shape glyphs, each with the jump button as the whole row; mirrors alert chips | Static pips; per-row pin button (row is the target) |
| **Nation card** | detail pane of Nations (also opens standalone from map diplomacy verb) | Ruler line, relation and casus belli, war score; actions in two groups **Diplomacy** (War, Pact, Alliance, Marriage, Trade) and **Intel** (Steal, Sabotage, Incite) with cost chips and disabled reasons; allies/enemies as flag chips | The 7-row text grid becomes a 2-column facts grid with chips; War is separated and red with confirm (P-16 L1) |
| **Settings** | Wide panel two groups / Page with tabs | Groups: Display (quality, map view, map style), Interface (UI size, text size, density), Audio (toggle), Accessibility (text size, high contrast, reduced motion, toast time, narration), Language, Advanced (perf readout, copy diagnostics) | Action buttons (How to play, Codex, Main menu) leave to the Menu hub; On/Off segmented rows become toggles (P-14) |
| **Save / Load** | Wide panel / Page, tabs Save + Load (Load only on title) | Slot rows: flag, nation, "Turn 19 - 1850 AD", saved date, optional thumbnail; Autosave row first and not saveable; empty slot "Save here" | Bare "#2 Empty slot"; silent overwrite (L2 confirm) |
| **Honours** | Wide panel two-column tile grid / Page one column | Progress meter 5/19 in the context chip; filter All / Earned / Locked; locked at full contrast with a lock glyph and **how to earn**; progress where countable ("52/60 provinces") | 28 % alpha text; unlabelled earned year column (add "Earned 1804") |
| **Codex** | Wide panel master-detail / Page topic list then page | Left topic list (11), right topic text (max 66 chars per line); deep-links from tooltips ("Open in Codex") | Two newspaper columns in one scroll; a 600 px scroll box inside a modal |
| **Era picker** (New game page) | Wide panel two columns / Page | Left chronology rail; right: year, name, blurb, **great powers as flag chips**, nation count; below: difficulty and players segmented; footer [Back] [Next: Pick nation] | Separate Hot-seat dialog; "New Game" label (it only advances); empty right pane filler |
| **Hot-seat setup** | folded into the New game page as a Players segmented 1-4 | none | Standalone dialog removed; title entry removed (main-menu.md) |
| **Event / Ultimatum** | Dialog; wide dialog 640u on landscape (narrative left, choices right) | Category kicker, title, <= 280 characters flavour, **choice cards with effect chips** (gold -40, stability -8, signed with ^/v); ultimatum adds a strength comparison chip and "Defy: war with X" | Emoji icon (use drawn glyph); choice 0 pre-styled as primary; Back/backdrop dismissal |
| **Game over** | Page (wide dialog on landscape) | Result headline, rank table (top 5 plus You), key numbers (turns, peak provinces), [Main menu] primary, [View final map] secondary (hides the panel, a chip brings it back) | Single "Main menu" dead end |
| **Tutorial** | **Coach marks**, not a modal: spotlight plus small card anchored to the real HUD element, 5 steps (top bar, select, move/preview, End Turn, Council); card 2 lines, [Skip] [Next] with pips | Replay from Menu > How to play | 7-step centered carousel over a blank card |
| **Briefing** | removed as a modal | Neighbour threat and 2 advisor tips become first-turn alert chips; facts live on the pick confirm card | one tap fewer before the first turn |
| **Pass-device curtain** | opaque Dialog | Seat colour chip, flag, "Pass to Player 2", turn and date, [Ready] | Back is swallowed (P-20) |
| **Menu hub** (new) | Dialog (short list) | Resume, Save, Load, Settings, How to play, Honours, Main menu (L2 confirm) | rail More holds Annals + Menu |

## 6. States and Variants

| State | Trigger | Visual | Behaviour |
|-------|---------|--------|-----------|
| Opening | open call | per section 10 | input locked 160 ms, focus set at end |
| Loading | slow data | skeleton rows, tabs live | cancel allowed (P-17) |
| Populated | data ready | normal | |
| Empty | no rows | glyph + line + action (P-18) | focus on first control |
| Error | load/save fail | inline banner or dialog (P-19) | retry available |
| Busy (turn processing) | `_busy` | commit buttons disabled with reason | read-only still works |
| Dirty | live-apply screen changed | [Revert] enabled, chip shows delta | revert restores opening values |
| Replaced | another panel opens | crossfade 120 | only tab/filter remembered per screen |

## 7. Interaction Map

### 7.1 Navigation inputs

| Input | Platform | Action | Notes |
|-------|----------|--------|-------|
| Tap / click row, tab, chip | T/M | select / switch | `tap` sound |
| Drag handle, drag body | T | Sheet resizes; body scrolls | scroll deadzone 12 |
| Wheel / PgUp / PgDn | M/K | scroll body (never over sliders) | |
| Tab / Shift+Tab | K | next / previous control; order: tabs, body, footer, X | trapped in panel |
| Ctrl+Tab, `[` `]`, arrows | K | next/previous tab; arrows move within list/tabs/segmented | |
| Esc / Android Back / X | all | `pop()` per P-20 | |
| `N B D A C` | K | open screen (replaces current) | `?` lists shortcuts |

### 7.2 Action inputs

| Input | Context | Action | Response |
|-------|---------|--------|----------|
| Enter / Space | focused button | activate | press tint 60 ms, sound |
| Enter | primary footer when focus is not on a field | primary action | only if enabled |
| Long-press | any chip/button/row | tooltip card | P-07 |
| Swipe down | Sheet handle | to 56 %, again to close | |

### 7.3 State-specific restrictions

| State | Restriction | Reason |
|-------|-------------|--------|
| Unanswered event/ultimatum, game over, pass-device | Back, Esc, backdrop disabled | answer is required |
| Sheet above 60 % | map orders blocked | avoid accidental orders |
| Turn processing | commit buttons disabled | state is changing |

## 8. Data Requirements

| Data | Source | Update | Owner | Missing handling |
|------|--------|--------|-------|------------------|
| Net income, budget shares, effect per share | `TBGame.income`, `budget` | on slider change | game | "--" plus tooltip |
| Nation rows (provinces, army, relation) | `g.own_count`, `g.army`, `get_rel` | on open and on turn end | game | "?" if not in intel range |
| Rankings series | `TBStats` | each turn | stats | "Not enough history yet" |
| Decision costs, reasons | `TBDecisions` | on open | game | reason string required, never empty |
| Annals | `g.log`, `TBChron` | on open | game | empty state |
| Save meta (nation, turn, year, saved_at, version, thumbnail) | `TBSave.meta` | on open | save system | "Unreadable" row. **New fields needed**: year, saved_at, version, optional thumbnail |
| Settings | `cfg` | on change | main | defaults |
| Effect chips for events | `TBModals.fx_text` data, as structured (op, delta) not prose | on prompt | content | no chip if zero |

Rule: panels never write game state; they emit commands (`on_cmd`) and the game notifies.

## 9. Events Fired

| Action | Event | Payload | Receiver |
|--------|-------|---------|----------|
| Slider / Revert / Done | `cmd budget` | `{key, val}` | game |
| Enact / doctrine | `cmd decide`, `cmd doctrine` | `{id}` | game |
| Diplomacy / spy verbs | `cmd declareWar`, `nap`, `ally`, `marry`, `trade`, `spy`, `peace` | `{t, ...}` | game (L1 confirm first) |
| Event choice | `cmd eventChoice` | `{uid, i}` | game |
| Save / Load / Delete | `save.write/read/delete` | `{slot}` | save system (L2 confirm on overwrite/delete) |
| Open / close | `ui.panel_open/close` | `{id, kind, reason}` | analytics only |
| Tab / filter change | `ui.tab` | `{panel, tab}` | analytics only |

## 10. Transitions and Animations

| Transition | Type | ms | Easing | Interruptible | Reduced motion |
|------------|------|----|--------|---------------|----------------|
| Dialog open / close | fade plus scale 0.97 to 1 | 160 / 120 | cubic out / in | yes | fade 80 |
| Drawer open / close | slide from right | 180 / 140 | cubic out | yes | fade 80 |
| Sheet rise / snap | slide up | 200 | cubic out | yes (drag) | fade 80 |
| Page push / pop | slide 24 px plus fade | 200 | in-out | yes | fade 80 |
| Panel replace | crossfade | 120 | linear | yes | instant |
| Tab swap | crossfade | 120 | linear | yes | instant |

## 11. Input Method Completeness Checklist

**Keyboard**
- [ ] Every control reachable by Tab/arrows; visible focus ring on all (custom-drawn controls included)
- [ ] Order tabs, body, footer, X; focus trapped while open; returns to opener
- [ ] Esc closes; never quits from inside a panel
**Gamepad** (not required; free via `ui_*` actions): [ ] D-pad focus, A activate, B back, shoulders switch tabs
**Mouse**
- [ ] Hover states and tooltips on all controls; right-click does nothing inside panels (defined no-op)
- [ ] Wheel scrolls the body, never changes a slider
**Touch**
- [ ] All targets 48u or more; one-handed reachable footer (bottom) in portrait
- [ ] Long-press tooltip; no swipe gestures that fight the system back swipe (Sheet handle only)
- [ ] Android Back follows the P-20 stack

## 12. Accessibility (Comprehensive)

| Requirement | Spec |
|-------------|------|
| Contrast | Text 4.5:1, glyphs/borders 3:1 against paper; fix GOLD captions and GREEN; no 28 % alpha text |
| Color | Every state pairs colour with glyph/shape/sign (relation, goals, deltas, alerts) |
| Text | Floor 12 px; scalable 100/125/150 % independent of UI size; layouts verified at 150 % in RU (+35 %) |
| Motion | Reduced-motion setting replaces slides/scales by 80 ms fades and stops loops; no flashing |
| Focus order | tabs, body in reading order, footer, X; initial focus = first actionable, Cancel on destructive |
| Narration | `DisplayServer.tts_speak` (opt-in): panel title and tab on open, row on focus, value changes debounced 300 ms |
| Timing | No timed dismissal of panels; toasts 3-10 s configurable and pause on focus |
| Alternatives | Charts have a table view; tooltips' content also reachable by focus; no information only in hover |
| Motor | No hold-to-confirm, no path-dependent gestures, 48u targets, 12u tap slop |

**Cognitive load**: each screen shows at most 5-7 groups; headline number first; details behind tabs; no more than two actions in the footer.

## 13. Localization Considerations

| Element | EN baseline | Budget | Overflow rule |
|---------|-------------|--------|---------------|
| Header title | 14 chars | 32 | ellipsis plus tooltip |
| Tab label | 9 | 16 | width follows text; 6th tab scrolls |
| Segmented label | 8 | 14 | stacks as list if row overflows |
| Row primary | 24 | 36 | ellipsis; secondary line wraps to 2 |
| Footer button | 16 | 28 | grows to 40-60 % width; max 2 lines |
| Chip caption | 10 | 16 | wraps below value on P |
RU and UZ run about 35 % longer; RU is not upper-cased (existing rule); Uzbek apostrophes (O‘zbekcha) need a font fallback test; no text in images; RTL not targeted.

## 14. Acceptance Criteria

**Layout**
- [ ] Every screen renders without overlap or clipping in profiles D, L, S, P (540x960, 800x360, 1920x1080, 2340x1080 px) in EN/RU/UZ at Text size 150 %
- [ ] Landscape browse/compare screens use the wide panel of 5.2 (never a 380-560u centered card); drawers only for tuning screens
- [ ] Wide panel two-column only at 640u inner width or more; single column below
- [ ] Footer never overlaps the End Turn seal; drawer ends above it
- [ ] No list silently truncated; lists over 60 rows pooled and scroll at 60 fps on mid-range Android

**Behaviour**
- [ ] Exactly one right-rail occupant; at most one panel plus one dialog
- [ ] Android Back follows P-20 including swallowed Back on unanswered events
- [ ] Opening a screen from the rail and from a top-bar chip give the same result
- [ ] Budget changes update top-bar chips while the drawer is open

**Input and accessibility**
- [ ] Complete flow of each screen using keyboard only; focus visible; trapped; restored
- [ ] All touch targets 48u or more (measured on device)
- [ ] No state conveyed by colour alone (grayscale screenshot test)
- [ ] Reduced motion produces no slides or scales
- [ ] Text contrast 4.5:1 verified on every text style over paper and over the dark top bar

**Performance**
- [ ] First frame within 200 ms of trigger on min-spec Android; interactive within 500 ms

## 15. Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Approve IA merges: Nations+Statistics+Nation card; Goals+Advisor into Council; Save/Options into Menu hub (hud.md rail More = Annals + Menu instead of Annals, Goals, Save, Options)? | creative-director | before ui-programmer starts | Recommended: yes |
| Drop Briefing modal and Hot-seat dialog (folded elsewhere)? | creative-director | same | Recommended: yes |
| Decoration budget: art-director to define the thinner frame, border weight and header band. | art-director | before art pass | Open |
| Does the Drawer allow map orders while open on L/S (card collapsed)? Tested only by playtest. | ux-designer | first playtest | Open |
| Save thumbnails and `saved_at`/`version` meta: cost and storage on mobile? | lead-programmer | before Save screen | Open |
| Tutorial as coach marks needs HUD anchors and a step runner: scope? | producer | sprint planning | Open |
| Screen-reader route on Godot 4.4 (TTS only) vs upgrading to 4.5+ | technical-director | Pre-Production gate | Open |
