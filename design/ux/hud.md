# HUD Design: Terra Bellum

> **Status**: Draft (decisions taken by ux-designer; creative-director review pending)
> **Author**: ux-designer
> **Last Updated**: 2026-10-06
> **Game**: Terra Bellum (single document for the whole in-game screen)
> **Platform Targets**: Android, iOS (touch-first, 540x960 portrait to 2340x1080 landscape), Windows (mouse + keyboard, 1920x1080). Gamepad not required.
> **Related GDDs**: none yet; inputs are `design/game-brief.md` and `godot/src/ui/{hud,hud_parts,province_panel,main}.gd`, `render/map_labels.gd`, `engine/advisor.gd`; companion spec `design/ux/command-card.md` (replaces the right-hand province panel)
> **Accessibility Tier**: Comprehensive
> **Style Reference**: `design/art/` (paper / ink / brass kept; ornament reduced, see 1)
> **Template**: HUD Design

**Units.** All sizes are `u` (logical px after content scaling, ~1 dp on phones). Reference viewports: Desktop 1920x1080 px at 1.5 px/u = **1280x720u**; Landscape phone 2340x1080 px at ~2.6 px/u = **900x415u**; Short 800x360 px at 1.0 = **800x360u**; Portrait 540x960 px at 1.5 = **360x640u** (up to 411x891u). Touch target >= 48u, mouse target >= 32u, text >= 12u. Current code (`_update_ui_scale`, fixed 1280x720 / 540x960 base) does not yield this on phones: see Open Questions Q1.

## 1. HUD Philosophy

**Relationship with information:** *Adaptive, quiet, command-table.* The map is the hero; the HUD is a thin staff-officer frame: a resource strip, a short list of things that need an answer, one command card for the selected place, and one End Turn control. Everything else is one tap deeper. Reference feel: Total War (unit card, orders on map) and HoI4 (stacked chips, outliner, map modes), executed in paper/ink/brass with **hierarchy and spacing doing the work, not ornament**.

**Visibility principle:** CONTEXTUAL. Default is HIDE; a value is shown when it changes an order the player can give this turn or warns an order is already failing.

**Rule of Necessity:** "A HUD element earns its place when it changes what the player orders this turn, or when ignoring it will cost them something next turn."

**Decoration budget (structure over ornament):** one brass hairline per panel edge; no ornaments/dividers/corner studs; flat paper chips (no wax, no medallion rings, no drop-shadow stacks); the only embossed object is the End Turn plate. Max one texture layer under any text.

## 2. Information Architecture
| Information | Always | Contextual | On demand | Hidden | Reasoning |
|---|---|---|---|---|---|
| Gold + net per turn | X | | | | Every build/hire/recruit decision; delta predicts bankruptcy |
| Manpower (value / cap) | X | | | | Gates recruit; "idle at cap" is waste |
| Moves (action points) | X | | | | The turn's budget; every order spends it |
| Diplomacy points (rules >= 1) | X | | | | Spent on ultimatum / alliance / marriage |
| Date + turn number | X | | | | Orientation; also on End Turn plate on phones |
| Nation flag + name | X | | | | Identity; hot-seat seat tag lives here |
| Active wars count | | X (>= 1 war) | | | Opens war list; absent in peace |
| Infamy / coalition | | X (infamy >= 5 or coalition) | | | Cost of aggression; warns before declaring |
| Alerts: war, revolt, offers, supply, event | | X (only when true) | Full list drawer | | Quiet until it matters; state-based, auto-clear |
| Map lens + legend | lens chip always | legend when lens != political | | | Lens is a mode; legend only explains non-trivial colour keys |
| Selected-place command card | | X (on selection) | Details drawer | | Verbs + costs; ledger one tap deeper |
| Army gonfalons | X (map layer) | zoom-disclosed tiers | | | Existing; own = brass rim, war = red + hatch, quiet foreign recedes |
| Battle preview | | X (attack target chosen) | | | Exact outcome before irreversible attack |
| Supply / attrition | | X (army outside own land: Supply alert + card chip) | Details drawer | | Only matters when an army is starving |
| Hot-seat status, turn report, opportunities | | X | Annals / Advice dot | | One summary chip after End Turn replaces 5 toasts; opportunities never interrupt; Intel, lands, tech, ruler, ledger figures are on demand (realm sheet / details drawer) |

## 3. Layout Zones

### 3.1 Zone diagram (A = top bar, B = screens rail, C = alert ticker, D = command card, E = End Turn, F = lens legend, G = hot-seat strip)

**Desktop 1280x720u (1920x1080 px)**
```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ ▣ FRANCE ▾ │1804 AD T12│◎ 4,585 ▲+608│☗ 90/1965 ▲+3│⚑ 10/10│✉ 6 ▲+1│⚔2 ☠7│ Lens: Political ▾ │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ B          ┌─ C ticker 280u ─────────┐                                    ┌─ F legend ─────┐ │
│ ▢ Nations  │⚔ Threat Lyon 1.8× ▲     │                                    │Economic        │ │
│ ▢ Budget   │✉ Prussia: alliance      │                                    │lo ▭▭▭▭▭▭ hi    │ │
│ ▢ Decree   │◇ Unrest: 3 provinces    │     M A P  (hero)                  └────────────────┘ │
│ ▢ Advice!  └─────────────────────────┘                                                       │
│ ⋯ More      (max 4 rows, then "+N")   ⚔ ───────► ◎  order arrow                              │
│                                           ┌ 119 vs 32 · Win · −32 men ┐                      │
│                      ┌─ D COMMAND CARD 480x160u (expands up) ─────────┐                      │
│                      │ Ariège ★ France › OWN            ⌃ Details  ✕  │                      │
│                      │ ⚔33  ★★ Ney  Supply 4  Stab 84 ▲               │    ┌─ E ───────────┐ │
│                      │ SEND [25][50][75][100%]  [➜M][⚒R][$H][★G][⌂B]  │    │ End Turn   ›  │ │
│                      │                                                │    │ 10 moves left │ │
│                      └────────────────────────────────────────────────┘    └───────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```
**Landscape phone 900x415u (2340x1080 px)**: safe-area insets (cutout/rounded) applied first: 44u left/right, 0 top (status hidden), 21u bottom.
```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ ▣ │T12 1804│◎4.6k▲608│☗90│⚑10│✉6│⚔2│                                   │Lens▾│  A 36u        │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ ▢     ┌─ C ticker ───────────┐                                                               │
│ ▢     │⚔ Threat Lyon ▲       │                                                               │
│ ▢     │✉ +2 more   (1 row + pill)           M A P                                            │
│ ▢     └──────────────────────┘      ┌ 119 vs 32 · Win ┐                                      │
│ ⋯                                                                                            │
│                                ┌─ D CARD STRIP 464x104u ──────────────┐   ┌─ E ──────────┐   │
│                                │ Ariège ★ OWN  ⚔33 ★★ Sup4 Stab84▲    │   │ End Turn  ›  │   │
│                                │ [25|50|75|100] [➜][⚒][$][★][⌂]  48u  │   │ 10 moves     │   │
│                                └──────────────────────────────────────┘   └──────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```
**Short 800x360u (small phone / small window)**
```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ ▣│T12│◎4.6k▲608│☗90│⚑10│⚔2│                                       │Lens▾│  ≡ menu   A 32u    │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ ≡     C: 1 ticker row + pill                                                                 │
│                                   MAP (>= 60% of height stays map)                           │
│                       ┌─ CARD STRIP 440x96u ─────────────────────────────┐                   │
│                       │ Ariège ★ OWN ⚔33 Sup4 Stab84  (labels on focus)  │    ┌─ E ────────┐ │
│                       │ [25|50|75|100] [➜][⚒][$][★][⌂]                   │    │ End Turn › │ │
│                       └──────────────────────────────────────────────────┘    └────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```
**Portrait phone 360x640u (540x960 px; up to 411x891u)**: insets: top 28-44u (notch/status), bottom 24u (gesture bar).
```
┌────────────────────────────────────────────┐
│ ▣│◎4.6k▲608│☗90│⚑10│✉6│  ⋯    A 40u        │
├────────────────────────────────────────────┤
│ C ⚔ Threat Lyon ▲ 1.8×      │ +3 ▾ │       │
├────────────────────────────────────────────┤
│               M A P                        │
│       ┌ 119 vs 32 · Win ┐                  │
├────────────────────────────────────────────┤
│ D SHEET ▔▔ drag handle 48u                 │
│ Ariège ★ France › OWN  ⚔33 ★★ Sup4         │
│ [25|50|75|100]                             │
│ [➜Move][⚒Rec][$Hire][★Gen][⌂Bld]           │
│ peek 180u · half 360u · full 560u          │
├────────────────────────────────────────────┤
│ B ▢N ▢B ▢D ▢A! ⋯│Lens▾│E End Turn ›        │
│ bottom bar 56u = thumb zone                │
└────────────────────────────────────────────┘
```
**Hot-seat (desktop shown; phone = seat badge in nation chip, strip collapses to "Round 4 · P2/4")**
```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ ■P2 NAPOLEON ▾│1804 AD T12│◎ 4,585 ▲+608│☗ 90/1965│⚑ 10/10│✉ 6│            │Lens▾│  A        │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│           G  Round 4:  ■P1 ✓ ended    ▲P2 ● playing    ●P3 ○ waiting    ◆P4 ○ waiting        │
│ rail B, ticker C (this seat only), card D, legend F as desktop                               │
│ on End: opaque curtain "Pass the device to P3 · [Ready]"  (no HUD, ticker, values)           │
│                                                                 ┌─ E ──────────────────────┐ │
│                                                                 │ Pass to P3  ›            │ │
│                                                                 │ (last seat: End Round ›) │ │
│                                                                 └──────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Zone Specification Table
| Zone | Position (D / L / P) | Size (D / L / P) | Primary elements | Max simult. | Notes |
|---|---|---|---|---|---|
| A Top bar | top, full width / same / same | 40u (5.6%) / 36u / 40u | nation chip, date, 4 resource chips, wars, infamy, lens (D/L) | 9 | Read-only; tap chip = breakdown popover |
| B Screens rail | left edge / left edge / bottom bar | 64x300u / 56x260u / 56u bar | 4 primary screens + "more" | 5 | Primary: Nations, Budget, Decrees, Advice(dot); More: Annals, Goals, Save, Options |
| C Alert ticker | top-left beside rail / same / under top bar | 280u wide / 240u / full width | alert chips (36u rows) | 4 + pill / 1 + pill / 1 + pill | Only rows with a true condition |
| D Command card | bottom-centre / bottom, handed / bottom sheet | 480x160u / 464x104u / 360x180u peek | see command-card.md | 1 | Collapsed by default; details drawer on demand |
| E End Turn | bottom-right / bottom-right / bottom bar right | 168x56u / 128x56u / 168x48u | one plate | 1 | Only embossed object |
| F Legend, G hot-seat strip | top-right under bar; G top-centre 20u (desktop only, phones fold into A) | 200x64u | lens key, seat chips | 1 each (contextual) | F hidden for political lens; popover in L/P |
| Map layer | full | n/a | selection ring, target markers, order arrow, preview tag, gonfalons, floaters | see 7 | Not a panel; keep-out registered for labels |

**Safe areas** (u): use OS safe area first, then minimum margin.

| Platform | Top | Bottom | Left | Right | Notes |
|---|---|---|---|---|---|
| Windows 1920x1080 | 0 | 0 | 8 | 8 | Margin only; window resize reflows to nearest profile |
| Android / iOS landscape | 0 | 21 | 44 (cutout) | 44 | Rail and End Turn sit inside the inset, never under cutout |
| Android / iOS portrait | 28-44 | 24 | 8 | 8 | Bottom bar above gesture bar; sheet handle >= 16u above it |

**One-handed / thumb reach (phones)**

| Profile | Easy-reach zone | Placement rule |
|---|---|---|
| Portrait, one hand (right) | bottom 45% of height, right 70% width | End Turn bottom-right; sheet verbs in lower half of sheet; top bar is read-only (never needs a tap during play) |
| Landscape, two thumbs | outer 40% of width each side, bottom 60% | Left: rail, ticker, lens. Right: card strip + End Turn (setting "Controls side" mirrors; default Right). Centre of map = pan/zoom only |
| Any | n/a | No destructive action (Declare War, Attack confirm) sits adjacent to End Turn; >= 16u gap |

## 4. HUD Element Specifications

### 4.1 Element Overview
| Element | Zone | Always | Trigger | Data source | Update | Max size | Min size | Overlap prio | Accessibility alt |
|---|---|---|---|---|---|---|---|---|---|
| Nation chip + date/turn | A | Yes | n/a | TBGame nation, seat, year, turn | on load, hot-seat swap | 14% W | 32u tall | 2 | Name text + seat shape (■▲●◆) |
| Resource chip x4 | A | Yes | Diplo if rules >= 1 | g.income, gold, manpower, mp, dp | after every command + end turn | 10% W each | 48u hit | 1 | Value + ▲▼ sign + label word |
| Screens rail | B | Yes | n/a | n/a | n/a | 64u W | 48u | 2 | Icon + 12u label; Advice dot has count |
| Alert chip | C | No | condition true | TBAdvisor + pending | each refresh | 22% W | 36u rows | 1 | Class glyph + word + severity mark |
| Command card | D | No | selection | see command-card.md | each refresh | 38% W | see spec | 2 | see spec |
| End Turn plate | E | Yes | n/a | mp, pending, busy | each refresh | 13% W | 48u | 1 | Text label, state word |
| Target markers | Map | No | army selected | move_check | on select | n/a | 24u glyph | 2 | Move = chevron; Attack = crossed-swords + hatch |
| Order arrow + preview tag | Map | No | target chosen | combat_preview | on target / share change | tag 18% W | 12u text | 1 | Tag text states outcome in words |
| Hover tooltip (desktop) | Overlay | No | hover 250ms | owner, rel, army, terrain | on hover | 22% W | 12u | 1 | Same content on keyboard focus |

### 4.2 Element behaviour (replaces per-element blocks)
| Element | Visual | Data / update behaviour | Urgency states | Interaction | Customisation |
|---|---|---|---|---|---|
| Resource chip | Flat paper chip: 20u glyph, value (mono 16u), delta line (12u) `▲+608` / `▼-40` | Value rolls 300ms then holds; delta = per-turn projection. Gain flash = text weight + arrow, not colour only | Normal / Caution (gold runs out in <= 5 turns, or manpower at cap) `!` badge / Critical (negative treasury) `!!` + outline | Hover/long-press: tooltip breakdown (below). Tap: pin popover with "Open Budget ›" | Show deltas on/off; text scale |
| Chip tooltips | n/a | Gold: "treasury 4,585 · income +1,020 (taxes, trade, tribute) · upkeep −412 · net +608/turn · runs out: never". Men: "90 of 1,965 · +3/turn · recruit costs". Moves: "10 of 10 · refills to 10 next turn · Move 1, Attack 2, Recruit 1, Colonize 2". Diplo: "6 · +1/turn · Ultimatum 2 · Alliance 3" | n/a | n/a | n/a |
| Alert chip | 36u row, class glyph (shape differs per class) + 1-line text + severity mark (▲ critical, none otherwise) | State-based: re-evaluated every refresh; appears 160ms, collapses 400ms after condition clears (shows ✓ first, 600ms) | Info / Warning / Critical (critical = double rule + ▲, sorts first) | Tap/click: focus map on subject + select; Offers expand inline (Accept / Decline). Swipe right / ✕: dismiss for this turn | Max rows; auto-fade on/off; announce via TTS |
| End Turn plate | Flat brass-edged plate, caption + sub-line; 3 states (6) | Sub-line = "N moves left" (0 = "All moves used") | idle / confirm-hint / busy / waiting / hot-seat | Click, tap, Enter; see 6 | Confirm mode Smart/Always/Never |
| Lens chip | Text + glyph, opens 2-col grid (icon + name + hotkey) | Legend updates with lens | n/a | Click, tap, `L`, `Alt+1..9` | n/a |
| Selection ring | 2u brass outline + 1u ink inner line; dashes march 12u/s | n/a | n/a | n/a | Reduced motion: static |
| Order arrow | Curved arrow source -> target; width scales with send share; Move = dashed + chevron, Attack = solid + ⚔ + red hatch on target | Redraws live when share changes | n/a | n/a | n/a |
| Hover tooltip | Chip stack: [flag Province] / [owner · relation icon+word] / [⚔Army · Terrain] / in order mode a result line `Win: hold 87, lose 32` | 250ms delay, follows cursor (+18,+20), flips at edges | n/a | Esc hides | Delay 0-800ms |

## 5. HUD States by Gameplay Context
| Context | Shown | Hidden | Modified | Transition in |
|---|---|---|---|---|
| Idle (nothing selected) | A, B, C (if any), E, gonfalons, F if lens | D | Moves chip sub-line on E | Tap empty sea / Esc, 160ms fade |
| Province selected | + D collapsed, selection ring, (own army) target markers | none | Gonfalon of selected x1.18; ticker unchanged | Tap/click, 160ms card rise |
| Order mode (target pick) | + target markers, order arrow follows pointer (desktop) | Verb row replaced by Order row (Cancel / share) | Non-targets dim 25% | Tap own army (implicit) or `M`/Move |
| Battle preview | + preview tag on target, card Order row = [Cancel] [Attack ⚔ N moves] | Ticker collapses to pill | Others dim | Tap/right-click enemy target |
| Details drawer open | + drawer (up on D, side sheet on L, half-sheet on P) | Ticker collapses to pill on S/P | Card header becomes drawer title | Tap header / `I` |
| Turn busy / MP waiting / report | A, E (busy), map pan/zoom; afterwards one Turn report chip + battle replays (max 8, 220ms apart) | D inputs (read-only, 40% dim), selection | E shows "Resolving…" | End Turn, 0ms; map locked from picks |
| Modal / screen open | A dimmed 40%, rest hidden behind scrim | B, C, D, E | Esc / back closes top-most | Rail, hotkey, event |
| Event / proposal prompt | scrim + event card (one at a time) | HUD input | "Decide later" turns it into an Event/Offer chip | Turn start |
| Hot-seat curtain | opaque full-screen curtain only | all HUD + map detail | n/a | Last action of seat |

## 6. Information Hierarchy
| Element | Tier | Reasoning | If hidden |
|---|---|---|---|
| Moves chip | MUST KEEP | Budget of the turn | none (never hidden) |
| Gold + Manpower chips | MUST KEEP | Drive every purchase / recruit | Card cost line |
| End Turn | MUST KEEP | The one required action | none |
| Command card verbs | MUST KEEP | Orders | none |
| Alert chips (critical) | MUST KEEP | War/revolt cannot be silent | Advice-icon dot |
| Nation chip | SHOULD KEEP | Identity; flag only on small screens | Realm sheet |
| Lens, Date, Diplo (rules >= 1), Wars/Infamy, deltas, legend | SHOULD KEEP / CAN HIDE | Mode and context; collapse order below | Popovers, End Turn sub-line, realm sheet |
| Alert chips (info) / Turn report | CAN HIDE | Reference material | Annals |
| Screens rail | CAN HIDE | Reachable by hotkey / more menu | "≡" menu (S), bottom bar (P) |
| Ruler cameo, ornaments, medallion rings, corner studs, dividers | ALWAYS HIDE | Decorative | Ruler in realm sheet |
| Intel, lands, tech | ALWAYS HIDE (HUD) | Not a this-turn decision | Realm sheet |

**Collapse order on small screens (first to go to last):** 1 ticker rows beyond first -> pill; 2 legend -> lens popover; 3 resource deltas; 4 Wars/Infamy chips -> badge on nation chip; 5 Diplo chip -> realm sheet; 6 date line -> End Turn sub-line; 7 nation name -> flag only; 8 rail -> single "≡" (S) or bottom bar (P); 9 card chips -> drawer. **Never collapse:** Moves, Gold, Manpower, End Turn, card verbs, critical alert.

## 7. Visual Budget

Area base 1280x720u = 921,600u². Hard limits; additions must displace.

| Constraint | Limit | Measurement | Estimate | Status |
|---|---|---|---|---|
| Persistent elements, idle (nothing selected, no alerts) | 12 | Count non-faded: A 7 (nation, date, 4 chips, lens) + rail group + End Turn | 9 | To verify |
| Elements with 4 alerts + card + wars/infamy | 22 | same | 20 | To verify |
| HUD area, idle | <= 10% | px area of all HUD rects / screen | A 5.6 + B 2.1 + E 1.0 = 8.7% | To verify |
| HUD area, selected, drawer closed | <= 22% | same | + card 9.2 + ticker 2.3 = 20.2% | To verify |
| HUD area, drawer open | <= 32% | same | + drawer 11 = 31% | To verify |
| Center 40% x 40% of screen | only preview tag, tooltip, order arrow | rect overlap test | 0 panels | To verify |
| Alert rows | 4 (D), 1 (L/S/P) + pill | count | n/a | Spec |
| Text contrast | >= 4.5:1 text, >= 3:1 glyph/border | measured over lightest + darkest map colour | TBD | To verify |
| Panel opacity floor | >= 88% behind text (deviation from template's 65% cap: text must beat saturated map colours) | alpha of chip background | 94% | Spec |
| Min size | icon 24u glyph / 48u touch (32u mouse); text 12u | at each profile | TBD | To verify |
| Decoration | 0 ornaments, <= 1 hairline per panel, 0 drop-shadow stacks | review | n/a | Spec |

## 8. Feedback & Notification Systems

Classes (priority order, then severity, then newest first). Tap/click on any chip focuses the map on its subject (`fly_to` + select); chips are **state-based and clear themselves when the condition clears**.

| Class (glyph) | Source / trigger | Position | Duration | Anim in / out | Max | Priority | Queue behaviour | Dismissible |
|---|---|---|---|---|---|---|---|---|
| 1 War (⚔) | threat (enemy stack >1.3x adjacent), occupied, capital lost, coalition, war declared on me | C | While true | slide 160 / collapse 400 | 4 shown | Critical | Never merged across provinces beyond "Lyon +2"; preempts all | Dismiss for this turn only |
| 2 Revolt (◇ broken flag) | province stability < 30 (unrest), rebel spawn | C | While true | same | merge per count ("3 provinces") | High | One chip per class; tap cycles provinces | Dismiss for turn |
| 3 Offers (✉) | AI proposal (NAP/ally/trade/marry/peace), ultimatum received | C | Until answered or turn ends (unanswered = declined) | same; expand inline | all (cap 3 + pill) | High | Each its own chip; inline Accept / Decline / View nation | No (answer) |
| 4 Event (✦ quill) | event with choice deferred ("Decide later"), succession | C | Until answered | same | 2 | Medium | Events show as a modal at turn start first | No |
| 5 Supply (⛟) | attrition on army outside supply, bankrupt / low treasury, manpower idle at cap | C | While true | same | merge per kind | Medium | Treasury critical is promoted to class 1 | Dismiss for turn |
| Turn report / Info (▤) | end-of-turn log summary (battles, revolts, deals); also "Saved", honours (2.5 s) | C bottom | 6 s, or until tapped | fade | 1 | Low | Replaces all toasts; details in Annals | Yes |
| Command error | rejected command (moves, gold, rules) | On card footer + shake 120ms | 3 s | fade | 1 | Medium | Replaces previous | n/a |

**Queue rules**
1. Criticals (class 1) never queue, never merge into other classes, and re-sort to the top.
2. Same-class chips for different subjects merge into one chip with a count when rows would exceed the max; tap cycles subjects.
3. Overflow "+N" pill opens the full alert list (drawer / sheet) grouped by class; handled rows show ✓ 600ms then leave.
4. During battle replay after End Turn (up to 8), Low-priority chips are held and released afterwards.
5. Advisor opportunities never enter the ticker (Advice screen dot only).
6. Pending choices (events, proposals) persist across turns only as long as the engine keeps them; chip disappears when engine drops them.

**End Turn control states**

| State | Trigger | Plate | Behaviour |
|---|---|---|---|
| Idle | default | "End Turn ›" + "N moves left" / "All moves used" | Click / tap / Enter ends the turn |
| Hint (soft block) | >= 1 unanswered offer or deferred event, and confirm mode = Smart | Plate expands to "N offers pending · End anyway" 3 s, relevant chips pulse once | First press never ends turn; second press (or Ctrl+Enter) does. Never hard-disabled |
| Busy | turn resolving on worker thread | "Resolving…" + indeterminate bar (static dots if reduced motion), disabled | Pan/zoom still work; picks ignored; card dimmed |
| Waiting (MP) | End pressed, others pending | "Waiting for N players" | Cancel not offered |
| Hot-seat | >1 human | "Pass to P3 ›" / last seat "End Round ›" | Curtain on press |
| Disabled | game over | greyed + "Game over" | n/a |

## 9. Platform Adaptation
| Platform | Safe zone | Resolution (u) | Input | HUD-specific notes |
|---|---|---|---|---|
| Windows | 8u margin | 1280x720 to 2560x1440 px windowed/full (u = px / 1.5) | Mouse + keyboard | Hover tooltips, right-click orders, hotkeys; ticker width fixed 280u |
| Android / iOS landscape | OS safe area + 8u | 900x415 typical; 800x360 minimum | Touch | Card strip handed; no hover; long-press 450ms = tooltip peek |
| Android / iOS portrait | OS safe area + 8u | 360x640 minimum to 411x891 | Touch | Bottom bar + sheet; top bar read-only; dp-derived scale |
| Hot-seat (any) | as host profile | as host | host | Curtain; seat shapes; seat-specific ticker |

Map-label keep-outs: every HUD rect (A, B, C, D, E, F, G) must be returned by the HUD keep-out function so labels/gonfalons avoid them. **HUD repositionability:** only "Controls side" (Right/Left) and card Collapsed/Expanded default are player-set; free repositioning is out of scope (open question Q7).

## 10. Accessibility (Comprehensive)

### 10.1 Colour-independence
| Element | Colour-only risk | Fix |
|---|---|---|
| Resource deltas | green/red gain/loss | ▲▼ glyph + sign + word in tooltip |
| Alert severity | red = critical | ▲ mark, double rule, sort order, class glyph shapes differ |
| Relations (war/ally/NAP) | map colours | Icon + word on card, tooltip, gonfalon (war = hatch + ⚔ micro-glyph) |
| Preview win/lose | green/red bar | Text "Win"/"Lose" + numbers + ✓/✗ glyph + bar split with divider |
| Seats (hot-seat) | P1-4 colours | Shapes ■ ▲ ● ◆ + "P2" text |
| Lens legend | ramps | Labelled low/high, categorical swatches carry text; optional pattern overlay for diplomatic lens |
| Target markers | ring colour | Move = chevron, Attack = crossed swords |

### 10.2 Text scaling (100 / 125 / 150 / 175%; matrix status TBD, verify each row at all four)
Resource chip: delta line drops first, then chips wrap to a 2nd bar row (A grows to 72u). Alert chip: wraps to 2 lines (56u) then "…" with full text in tooltip/list. End Turn: sub-line wraps, plate grows to 200x64u. Rail: labels truncate; at >= 150% rail becomes the "≡" grid menu. Card: see command-card.md.

### 10.3 Motion
| Motion | Severity | Reduced-motion | Replacement |
|---|---|---|---|
| Rolling numbers, gain flash | Mild | Disabled | Instant value, arrow stays |
| Selection dash march, End Turn bezel sweep | Moderate | Disabled | Static dashes, static "Resolving…" text |
| Floating +15/−12 | Mild | Optional | Static for 1.5 s |

No element flashes more than 2 times per second; none above 3 flashes.

### 10.4 Settings (Accessibility menu). No voiced dialogue; sound cues mirror alert chips; "Captions for sounds" (default Off) writes them to the ticker Info row.
| Setting | Range | Default | Effect |
|---|---|---|---|
| UI text scale | 100 / 125 / 150 / 175% | 100% | Scales all HUD text; layouts per 10.2 |
| HUD opacity floor | 88-100% | 94% | Panel background alpha |
| Reduced motion | Off / On | follows OS | Per 10.3 |
| High contrast | Off / On | Off | Solid ink-on-paper chips, 2u borders, no texture |
| Colour-blind patterns | Off / On | Off | Hatch/pattern overlays on map keys and relations |
| Icon labels | Always / Hover | Always | Rail and verb labels |
| Alert announcements (TTS) | Off / Critical / All | Off | OS text-to-speech reads new chips ("Warning: Lyon threatened by 1.8 times") |
| Confirm End Turn | Smart / Always / Never | Smart | Hint state rules |
| Controls side | Right / Left | Right | Mirrors card strip and End Turn on landscape phone |
| Tap-hold time | 300-800ms | 450ms | Long-press peek; also hover delay on desktop |

Keyboard (desktop): Enter/Ctrl+Enter End Turn; `A` / Shift+A next/prev alert; F1-F4 Nations, Budget, Decrees, Advice; F5 Annals; F6 Goals; `L` lens menu; Esc layered back (see command-card.md). Screen reader: Godot 4.4 has no AccessKit; accessible names are set on every control and mirrored by TTS announcements (Q5).

## 11. Tuning Knobs
| Parameter | Value | Range | Increase | Decrease | Player-adjustable | Notes |
|---|---|---|---|---|---|---|
| Ticker max rows (D) / card default state | 4 / Collapsed | 2-6 / Collapsed-Expanded | clutter | more "+N" | Card default only | |
| Hover tooltip delay | 250ms | 0-800 | calmer | twitchy | Yes (hold time) | |
| Long-press peek | 450ms | 300-800 | fewer accidents | accidental peeks | Yes | |

## 12. Acceptance Criteria
- [ ] **Safe areas**: all HUD stays inside OS safe areas at 1920x1080, 2340x1080, 800x360, 540x960, 1080x2340 (cutout emulation on).
- [ ] **No overlap / keep-out**: no two HUD rects overlap in any state of section 5; keep-out list holds A-G; map labels avoid them.
- [ ] **Budget**: idle HUD <= 10%, selected <= 22%, drawer open <= 32% of screen area; centre 40%x40% holds only preview tag, tooltip, arrow.
- [ ] **Sizes**: touch controls >= 48u, mouse >= 32u, text >= 12u at 100% scale; collapse order of section 6 applies in sequence; Moves, Gold, Manpower, End Turn, verbs never collapse.
- [ ] **Context correctness**: each row of section 5 shows exactly its listed elements; hot-seat curtain leaks no values, ticker or card to the next seat; seat shape + "P#" always visible; last seat reads "End Round".
- [ ] **Orders on map**: selecting an own army highlights valid targets without pressing Move; a preview is shown before any attack is committed.
- [ ] **End Turn**: Hint state never ends the turn on first press; Busy ignores map picks but allows pan/zoom; never hard-disabled by alerts.
- [ ] **Alerts**: each class appears when its condition is true and clears (✓ then gone) within 1 s of it turning false; tap focuses and selects the subject; offers Accept/Decline inline; criticals sort first and never merge across classes; overflow shows "+N" + full list; <= 1 toast-style message (Turn report or Info) at once.
- [ ] **Contrast / colour**: text >= 4.5:1 over light and dark map regions, glyphs/borders >= 3:1; greyscale test leaves every relation, severity, delta and preview outcome distinguishable.
- [ ] **Scale / motion**: 150% text causes no clipping or overlap, 175% reflows per 10.2; reduced motion removes every animation in 10.3; all 10.5 settings persist.
- [ ] **Input**: every control reachable by Tab/arrows on desktop and has an accessible name; thumb test passes (portrait one-handed; landscape outer-40% thumbs) for select, order, confirm, End Turn.
- [ ] **Lifecycle**: backgrounding autosaves; resizing between profiles reflows without rebuild glitches.

## 13. Open Questions
| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Q1 Scale: current fixed 1280x720 / 540x960 content base gives 25-30dp touch targets on 2340x1080 and ~0.5x UI at 800x360. Derive scale from DPI so 1u ~ 1dp on phones? | ui-programmer | before implementation | Recommend yes |
| Q2 Engine must expose: income breakdown (taxes/trade/upkeep), manpower growth, mp refill, and `can_do(cmd)` returning ok / reason / cost. Today only net, manCap are returned and errors appear after apply. | game-designer, gameplay-programmer | | Needed for tooltips and disabled-verb reasons |
| Q3 `TBAdvisor.alerts` needs a `class` field (war / revolt / supply) and a stable subject id; offers come from `g.pending` kind "prop". Confirm "unanswered offer = declined next turn" is final. | game-designer | | |
| Q4 Hint state blocks on pending offers/events only. Should unspent moves during war also count? | creative-director | | Recommend no (nagging) |
| Q5 Screen-reader: Godot 4.4 lacks AccessKit; accept TTS + accessible names until engine upgrade? | accessibility-specialist | | Recommend yes |
| Q6 Contested: phone-landscape card as bottom strip handed to the dominant thumb (A, recommended) vs right-docked 292u column (B: saves height, loses brief's bottom-centre). | creative-director | | Recommend A |
| Q7 Accept as intentional limitations: no free HUD repositioning (Controls side + card default only), no gamepad on-map cursor (focus order defined), Intel/lands/tech demoted to realm sheet (confirm in playtest)? | creative-director, accessibility-specialist | playtest | Recommend yes |
