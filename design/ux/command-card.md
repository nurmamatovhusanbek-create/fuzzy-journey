# UX Specification: Command Card

> **Status**: Draft (decisions taken by ux-designer; creative-director review pending)
> **Author**: ux-designer
> **Last Updated**: 2026-10-06
> **Screen / Flow Name**: `CommandCard` (replaces `TBProvincePanel`), with sub-flow `OrderFlow` (select -> target -> preview -> confirm)
> **Platform Target**: Android, iOS (touch-first), Windows (mouse + keyboard). Gamepad not required.
> **Related GDDs**: none yet; derived from `design/game-brief.md`, `godot/src/ui/province_panel.gd`, `main.gd` (`_on_pick`, `_try_move`, `_commit_move`, `_select`, `_on_hover`), `engine/commands.gd`
> **Related ADRs**: none
> **Related UX Specs**: `design/ux/hud.md` (zones D/E, ticker, budget, safe areas, units: all sizes in `u` as defined there)
> **Accessibility Tier**: Comprehensive
> **Template**: UX Spec

## 1. Purpose & Player Need
**Need:** "I picked a place on the map. Tell me what I can do here, what it costs, what will happen, and let me do it without leaving the map." The old panel answered with a 330u-wide scrolling list of 5-9 full-width buttons plus 9 ledger rows, covering ~25% of the map.
**Player goal:** issue one order (move, attack, recruit, build, colonize, a diplomatic act) on the selected place in <= 2 taps/clicks and see its exact result first.
**Game goal:** capture a validated command (`{cmd, ...}`), spend moves/gold/manpower once, and never let an irreversible act (attack, declare war) happen without a preview or confirm.
**Pillar mapping:** map is the hero (card <= 480x160u, no scroll) / orders happen on the map (targets, arrow, preview tag live on the map; card only confirms and explains) / every number answers a decision (<= 4 chips, ledger one tap deeper) / quiet until it matters (card exists only on selection) / structure over ornament (flat chips, no dividers).

## 2. Player Context on Arrival
| Question | Answer |
|---|---|
| Just doing | Scanning the map, tapped a province or an army gonfalon |
| Emotional state | Calm-focused; tense when the province is threatened or at war |
| Cognitive load | Medium: tracking moves left, gold, adjacent threats |
| Already knows | Owner (map colour), army number (gonfalon), their own resources (top bar) |
| Most likely wants | Move/attack with the army, or recruit/build in own land; for foreign land: diplomacy or war |
| Afraid of | Losing an army to a bad attack, wasting scarce moves, misclicking Declare War |
**Emotional target:** a staff officer's confident glance at an orders card: nothing hidden, nothing nagging.

## 3. Navigation Position
```
Game HUD (map)
  └── Selection ──> CommandCard (collapsed)
        ├── Details drawer (ledger)           ├── Order row (armed / preview)
        ├── Diplomacy popover / Build picker  └── Nation card screen (tap owner "France ›")
```
**Modal behaviour:** Overlay-live, non-modal (map stays interactive; turn resolution dims it read-only). Dismiss: Esc / empty-sea click / ✕ (desktop) / Android back / tap empty map (touch). Back layers, one per press: Preview -> Order mode -> Popover -> Drawer -> Card (deselect) -> Game menu.
| Entry point | Triggered by | Notes |
|---|---|---|
| Tap/click province or gonfalon | map pick | Primary |
| Alert chip, Annals link, Nations screen | `fly_to` + select | Card opens on the subject |
| Keyboard `Tab` / `A` | cycle own armies / alerts | Opens card for the focus |
| After a move/attack | order resolves | Selection follows the army to its new province |
| Hot-seat seat change | curtain Ready | Cleared, no card |

## 4. Entry & Exit Points
| Trigger | Source | Transition | Data in | Notes |
|---|---|---|---|---|
| Select province p | Map | Card rises 160ms | `p`, game state | Replaces content if already open (cross-fade 100ms, no rise) |
| Alert chip / link | HUD / screens | Map flies, card opens | `p` | Alert subject becomes selection |
| Long-press (touch, 450ms) | Map | Tooltip peek only | `p` | Does not select |

| Exit action | Destination | Data out | Notes |
|---|---|---|---|
| Esc, ✕, empty map, back | Idle HUD | none | Nothing is pending on the card; no discard prompt |
| Tap owner "France ›" | Nation card screen | `n` | Card stays selected underneath |
| Verb confirm | Command bus -> `TBGame.apply` / `mp.send_command` | command dict | Card refreshes from state; selection kept |
| End Turn | Busy HUD | none | Card dims, read-only |

## 5. Layout Specification
### 5.1 Wireframes (desktop 480x160u collapsed; order/preview; drawer; portrait sheet)
```
┌─ D COMMAND CARD · case 1 own province with army ─────────────┐
│ ▣ ARIÈGE ★  France › · YOUR PROVINCE             ⌃ Details ✕ │ header 32u
│ ⚔ 33 men │ ★★ Gen. Ney │ ⛟ Supply 4 │ ◇ Unrest 28            │ chips <=4, 28u
│ SEND [25][50][75][100%] → 32 men │ Move · 1 move             │ share + cost line 36u
│ [➜ Move M][⚒ Recruit R][$ Hire H][★ General G][⌂ Build B]    │ verbs 5 x 88x48u
└──────────────────────────────────────────────────────────────┘
 on map:  ⚔ Ariège ═══════► Lérida      ┌ WIN · 119 vs 32 · hold 87, lose 32 ┐   (preview tag)
┌─ CARD · order preview (enemy target) ────────────────────────┐
│ ▣ LÉRIDA   Spain › · AT WAR ⚔                       ⌃  ✕     │
│ Defenders 32 │ Plains │ From: Ariège 119 │ War score 18      │
│ SEND [25][50][75][100%] → 119 men                            │
│ [ Cancel  Esc ]      [ ⚔ Attack · 2 moves · −32 men  Enter ] │
└──────────────────────────────────────────────────────────────┘
┌─ DETAILS DRAWER (opens upward +200u; side sheet on landscape phone) ──────────┐
│ Population  82.0k           │ Stability  ▰▰▰▰▰▱ 84 ▲                          │
│ Development ◆◇◇◇◇ 1/5       │ Happiness  ▰▰▰▰▱▱ 65                            │
│ Economy     ◆◇◇◇◇ 1/5       │ Supply     limit 4 · attrition 0                │
│ Terrain     Marsh           │ General    ★★ Ney · replace 50 g                │
│ Building    Fort L2         │ Occupation none            │
└───────────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────┐  portrait bottom sheet, peek 180u (case 4)
│            ▔▔▔ handle 48u        │  half = drawer, full <= 560u
│ LÉRIDA  Spain › ⚔ AT WAR   ⌃ ✕   │
│ Def 32 │ Plains │ From Ariège 119│
│ SEND [25][50][75][100%] → 119    │
│ [⚔ Attack][☮ Peace][⚖ Terms]     │
└──────────────────────────────────┘
```
### 5.2 Layout Zones
| Zone | Description | Size D / L-phone / P | Scrollable | Overflow |
|---|---|---|---|---|
| Header | flag, name, capital badge, owner link, relation tag, Details, ✕ | 32u / merged with chips 36u / 36u | No | Name wraps to 2 lines (+16u) then "…" |
| Chips | <= 4 stacked info chips (priority list in 5.5) | 28u / (in header) / 28u | No | Extra chips go to drawer; wrap to 2nd row at text >= 150% |
| Share + cost | segmented 25/50/75/100 + result count; live cost line of focused verb | 36u / 48u / 48u | No | Cost line truncates "…" with full text in reason tooltip |
| Verbs | 3-5 icon+label buttons, fixed slots | 88x48u / 52x48u / 64x56u | No | Row wraps to 2 rows at >= 150% (+56u) |
| Order row | replaces Verbs in order/preview: Cancel + Confirm | same | No | Confirm label wraps |
| Drawer | ledger 2 cols (1 col on P) | +200u up / 300u side sheet / half 360u | P full only | Rows wrap; never horizontal scroll |
Card width: 480u D, 464u L-phone (handed to dominant side), full width minus 16u P. Max height collapsed: 160 / 104 / 180u (<= 30% of height).
### 5.3 Component Inventory
| Component | Type | Zone | Purpose | Req. | Reuses |
|---|---|---|---|---|---|
| CardHeader | HBox | Header | identity, relation tag (icon + word) | Yes | `TBFlags.chip`; new |
| InfoChip | Chip | Chips | icon + value (+ tooltip), max 4 | Yes | new (replaces `K.row`) |
| ShareSegmented | Segmented | Share | 25/50/75/100 %; duplicate presets disabled when army is small | own army > 1 | `K.segmented` |
| CostLine | Label | Share | "Recruit +15 · 1 move · 60 g · 15 men"; red part = shortfall | Yes | new |
| VerbButton | Button | Verbs | icon + label + hotkey badge (desktop), disabled with reason | Yes | new (replaces `K.button` list) |
| VerbPopover | Popover | Verbs | Diplomacy list, Build picker | Yes | replaces `OptionButton` |
| OrderRow | HBox | Order row | Cancel + Confirm | Yes | new |
| ReasonLine | Label | footer | why a verb is disabled / command rejected | Yes | replaces toast |
| DrawerLedger, LedgerRow, Meter, Pips | Grid | Drawer | figures | Yes | `K.meter_row`, `K.Pips` |
| SheetHandle | Drag | P only | peek/half/full | P | new |
| PreviewTag, OrderArrow, TargetMarker | Map layer | Map | on-map order feedback (hud.md 4.1) | Yes | `map.set_targets`, `labels.add_fx` |
**Primary focus on open:** the primary verb of the case (slot 1); if all verbs are disabled, the Details toggle.
### 5.4 Information Hierarchy
1) Who/what is this (name, owner, relation) 2) Can I act and what does it cost (verbs, cost line) 3) The one or two facts that decide the act (army, defenders, supply, terrain when attacking) 4) Everything else (ledger) behind Details.
### 5.5 Content by case (chips in priority order; max 4)
| Case | Header tag | Chips (priority) | Verbs (slot order) | Share row |
|---|---|---|---|---|
| 1 Own, army > 1 (also "held": occupied foreign land I control: no Recruit/Build) | YOUR PROVINCE / HELD | Army · General · Supply / Attrition (only if outside own land or attrition > 0) · Unrest (< 30) / Occupied by X / Building progress | Move-Attack (primary), Recruit, Hire, Appoint general (only if no general, army >= min, slots free), Build | Yes |
| 2 Own, army <= 1 | YOUR PROVINCE | Army · Building (or "No building" hint) · Unrest/Occupied | Recruit (primary), Hire, Build | No (hint: "Raise troops to move them") |
| 3 Foreign, peace / NAP / ally / vassal | owner + Peace / NAP / Ally / Vassal (icon + word) | Army · Terrain · Strength ratio vs you (`ult_ratio`, rules >= 1) · Truce/pact expiry | Diplomacy ▾ (NAP, alliance, break pact), Ultimatum (rules >= 1, 2 DP, shows ratio), Declare War (red outline, 16u gap, confirm). Allies/NAP: no Declare War; "Break pact" lives in Diplomacy | No |
| 4 Enemy at war | owner + AT WAR ⚔ | Defenders · Terrain · Source army ("From Ariège 119") · War score | Attack (primary; source = strongest adjacent own army, others selectable by tapping them on the map), Peace (white peace), Terms (demand land) | Yes (when a source exists) |
| 5 Neutral / unowned | UNCLAIMED | Terrain · Reach ("adjacent", "needs port") · Cost | Colonize (primary; 2 moves + gold) | No |
**Verb catalogue**
| Verb (label) | Icon | Key | Cases | Cost / rule (from engine) | Command |
|---|---|---|---|---|---|
| Move / Attack | ➜ / ⚔ | M | 1, 4 | Move 1 move, Attack 2 moves; leaves >= 1 man | `move {from,to,troops}` |
| Recruit | ⚒ | R | 1, 2 | +15 men; moves + gold + manpower | `recruit {p,amount:15}` |
| Hire (mercenaries) | $ | H | 1, 2 | +40 men; gold (regime cost) | `hire {p,amount:40}` |
| General (appoint) | ★ | G | 1 | gold (`TBGenerals.cost`), army >= min, slots n/cap | `appoint {p}` |
| Build | ⌂ | B | 1, 2 | picker: building · level · gold · moves | `build {p,b}` |
| Colonize | ⚑ | C | 5 | 2 moves + gold | `colonize {p}` |
| Diplomacy ▾ | ✉ | D | 3 | NAP / alliance / break pact; numbers `1-4` inside | `nap`/`ally`/`breakPact {t}` |
| Ultimatum | ⚖! | U | 3 | 2 DP, ratio vs 2.4 needed | `ultimatum {t,p}` |
| Declare war | ⚔ red | W | 3 | infamy shown in confirm | `declareWar {t}` |
| Peace (white) / Terms (cede) | ☮ / ⚖ | P / T | 4 | | `peace {t,kind}` |
**Verb rules:** slot positions are stable (primary verb always slot 1, styled solid); verbs that cannot ever apply to the case are hidden; verbs that are only temporarily blocked (moves, gold, adjacency) stay visible, disabled, with the reason in ReasonLine and the missing amount in red + text. **Dropped:** "ACTIONS" caption, ornament divider, "Capital" caps line (now a ★ badge), Army shown twice, "Building: None" row, full-width verb stack, scroll body, `OptionButton` Build dropdown, per-row dotted leaders.

## 6. States & Variants
| State | Trigger | Visual | Behaviour | Notes |
|---|---|---|---|---|
| Hidden | nothing selected | none | Map gets all input | Default |
| Collapsed case 1-5 | selection | per 5.5 | Verbs live | Rise 160ms |
| Held province | occupied foreign land under my control | tag HELD, supply chip | Move yes; Recruit/Build disabled "Not your land" | From `controller(p) == me` |
| Own, enemy-occupied | `occupier != 0` and at war | red chip "Occupied by X" | Recruit/Hire/Build disabled with reason | Attack source suggestions |
| Order armed | army selected (implicit) or `M` | targets marked on map, others dim 25%; Verb row shows Cancel + share | Tap/click target orders | Implicit targets: enemy, neutral, own land without army; own armies need explicit Move |
| Preview | enemy target chosen | tag + arrow on map; Order row [Cancel][Attack ⚔ N moves] | Confirm: button, Enter, tap target again, right-click again; live recompute on share change | Never auto-commits |
| Drawer open | Details / `I` / drag | ledger visible | Verbs stay reachable | Esc closes drawer first |
| Insufficient resource | moves/gold/manpower short | verb disabled, shortfall red + "needs 2 moves" | Tap on disabled verb flashes ReasonLine | Never a silent no-op |
| Command rejected | engine returns `err_*` | card shake 120ms, ReasonLine 3 s | No state change | Replaces toast |
| Busy (turn resolving) | End Turn | 40% dim, read-only | All verbs disabled; Details allowed | "Resolving…" |
| Hot-seat curtain | seat switch | card removed | Selection cleared | No leak |
| Peek (touch long-press) | 450ms hold | tooltip chip stack, no selection | Release closes | Same content as desktop hover |
| Empty data | no general / no building / no ratio | chip omitted | No placeholder text | No "None" rows |
| Stale | state changed under card | auto rebuild | Focus kept on the same verb slot if still present | After End Turn, AI events |

## 7. Interaction Map
### 7.1 Navigation inputs
| Input | Platform | Action | Visual response | Audio | Notes |
|---|---|---|---|---|---|
| Hover province | Mouse | tooltip (250ms): name, owner·relation, army, terrain; in armed state also result line | outline + tooltip, gonfalon x1.1 | none | Cursor: crossed swords over attack targets |
| Left-click province | Mouse | select (or order if armed) | ring + card | soft tap | Click empty sea deselects |
| Right-click target | Mouse | order from the selected army (any valid target incl. own armies = merge) | arrow, preview if attack | tap | Right-click again = confirm preview |
| Tap province | Touch | select; if it is a highlighted implicit target: order | ring + card / arrow | tap | Tap own army province = select it (no merge) |
| Long-press | Touch | tooltip peek | tooltip | none | No selection |
| Drag handle / swipe up | Touch (P) | peek -> half -> full | sheet follows finger | none | Swipe down closes |
| Pinch / drag map | Touch | camera | n/a | none | Never selects; does not cancel an armed order |
| Arrow keys / WASD | KB | pan map | n/a | none | Assumed camera keys |
| `Tab` / Shift+Tab | KB | cycle: nothing selected -> own armies; armed -> valid targets (nearest first) | focus ring on map province + tooltip | tick | `Space` selects focused |
| `A` / Shift+A | KB | next / previous alert subject | map flies | tick | See hud.md |
### 7.2 Action inputs
| Input | Platform | Context | Action | Response | Animation | Audio | Notes |
|---|---|---|---|---|---|---|---|
| Tap/click verb | All | verb enabled | run command or open popover | card refreshes, floater `+15` on map | 120ms | coin | Spend feedback in cost line first |
| Tap/click disabled verb | All | disabled | flash ReasonLine | none | shake 120ms | none | |
| `M`/`R`/`H`/`G`/`B`/`C`/`D`/`U`/`W`/`P`/`T` | KB | card open, case has the verb | same as click | | | | Hotkey badge on desktop; ignored in modals |
| `1`-`4`, `[` `]` | KB | army selected | share 25/50/75/100, step down/up | live recompute | none | tick | Inside popovers `1`-`n` pick items |
| `Enter` | KB | Preview | confirm attack | march + battle fx | 450ms | war | Else End Turn (hud.md) |
| `Esc` | All | any | back one layer (3) | | 120ms | back | |
| `I` / tap header | All | card open | toggle drawer | | 200ms | none | |
| Tap "Attack · 2 moves" | Touch | Preview | confirm | | | | Second tap on same target also confirms |
| Tap own source army | Touch | Preview | cancel to armed state | | | | |
**Orders on the map, end to end**
| Step | Touch | Mouse | Keyboard |
|---|---|---|---|
| 1 Select | tap own army | left-click | Tab to army, Space |
| 2 Target | tap highlighted province (own armies: use Move first) | right-click (or hover to preview, click if armed) | Tab through targets |
| 3 Preview | tag + arrow + Order row [Cancel][Attack] | tooltip result line, then tag | tag + Order row |
| 4 Confirm | tap Attack or same target again | right-click again, click Attack | Enter |
| 5 Result | march/impact fx, selection follows army | same | same |
Non-attack moves (own land, empty land, neutral) execute at step 2 with no preview (low risk, 1 move).
### 7.3 State-specific behaviours
| State | Restriction | Reason |
|---|---|---|
| Busy | Verbs, share, order disabled; pan/zoom/Details allowed | Turn on worker thread |
| Preview | Verbs replaced by Order row; picking another target switches preview | One decision at a time |
| Popover open | Number keys and Esc captured; map taps close it | Focus trap |
| Declare-war confirm | Only Confirm / Cancel active | Irreversible, infamy |

## 8. Data Requirements
| Data | Source | Update | Owner | Format | Null handling |
|---|---|---|---|---|---|
| owner, relation (`get_rel`), vassal, occupier, `controller` | TBGame | on refresh | engine | ints -> tag | UNCLAIMED / omit |
| army, general (`gen`), skill | TBGame, TBGenerals | after command, end turn | engine | int, name ★n | chip omitted |
| supply limit, attrition | `supply_limit`, `attrition` | refresh | engine | ints | chip omitted |
| pop, dev, econ, terrain, building (`b_level`, `b_building`, `b_turns`), stab, happy | TBGame | refresh | engine | ints / pips / meters | drawer shows "—" |
| verb eligibility + cost `{ok, reason, gold, moves, men, dp}` | needs `TBGame.can(cmd)` (open Q2) | per refresh | engine | dict | verb hidden if category-invalid |
| combat preview `{win, atk, dfn, send, defenders, hold, lost, enemy_lost}` | `combat_preview` | on target / share | engine | dict | Order row disabled |
| ult ratio / ultimatum eligibility | `TBDiplo` | refresh | engine | float / reason | verb disabled with reason |
| moves, gold, manpower, DP | TBGame | refresh | engine | numbers | n/a |
UI never mutates game state; it emits the commands in section 9.

## 9. Events Fired
| Player action | Event | Payload | Receiver | Notes |
|---|---|---|---|---|
| Recruit / Hire | `command` | `{cmd:"recruit"/"hire", p, amount}` | `main._on_command` -> `TBGame.apply` / `mp.send_command` | `coin` sfx |
| Confirm move / attack | `command` | `{cmd:"move", from, to, troops}` | same | After preview if attack |
| Appoint / Build / Colonize | `command` | `{cmd:"appoint"\|"build"\|"colonize", p, b?}` | same | |
| Diplomacy / Ultimatum / War / Peace | `command` | `{cmd:"nap"\|"ally"\|"breakPact"\|"ultimatum"\|"declareWar"\|"peace", t, p?, kind?}` | same | War needs confirm |
| Open nation | `nation_requested(n)` | `n` | main | |
| Select / close | `selection_changed(p)`, `closed` | `p` | main -> map | |
| Analytics only | `card_opened(case)`, `order_armed`, `order_previewed(win)`, `order_cancelled(reason)`, `share_changed(frac)`, `verb_blocked(verb, reason)`, `drawer_toggled` | small dicts | analytics | Never block on these |
Validation: engine rejects -> `err_*` string -> ReasonLine + shake; no optimistic update.

## 10. Transitions & Animations
| Transition | Trigger | Type | ms | Easing | Interruptible | Reduced motion |
|---|---|---|---|---|---|---|
| Card enter / exit | select / deselect | rise 16u + fade | 160 / 120 | cubic out | Yes | Instant |
| Case change | select another | content cross-fade | 100 | linear | Yes | Instant |
| Drawer / sheet snap | Details / drag | expand | 200 | cubic out | Yes | Instant |
| Order arrow + preview tag | target chosen | draw + pop | 180 / 120 | out | Yes | Fully drawn, no pop |
| Verb error | rejected | shake 4u | 120 | linear | No | Outline flash 1x, no movement |
| Floating +15 / −12 | command result | rise + fade | 1300 | out | n/a | Static 1.5 s |

## 11. Input Method Completeness Checklist
**Keyboard**
- [ ] Every verb has a hotkey and is reachable by Tab / arrows; order follows visual order (header, chips, share, verbs, Details)
- [ ] Targets are reachable with `Tab` and an order can be placed and confirmed without a mouse
- [ ] Focus is always visible; popovers trap focus; Esc layering per section 3 and never quits the game
**Mouse**
- [ ] Hover states on verbs, chips (tooltip), owner link; hit targets >= 32u (verbs 88x48u)
- [ ] Right-click = order; right-click on empty/invalid defined (no-op + ReasonLine); wheel = zoom on map, scroll inside drawer
**Touch**
- [ ] All targets >= 48u with >= 4u spacing (16u around Declare War); no hover-only information (long-press peek)
- [ ] No gesture needed for any verb (drag handle has a button equivalent); no conflict with system back gesture (handle >= 16u above gesture bar)
- [ ] Portrait one-handed: all verbs and share in the lower 45% of the screen
**Gamepad** (not a target, intentional limitation)
- [ ] Focus order is defined and nothing is gamepad-trapped; no on-map cursor is provided (Open Q5)

## 12. Accessibility (Comprehensive)
| Text element | Background | Required | Current | Pass |
|---|---|---|---|---|
| Header name, chips, cost line | paper chip (>= 94% opaque) | 4.5:1 | TBD | [ ] |
| Disabled verb label | paper, 50% | 3:1 (plus reason text at 4.5:1) | TBD | [ ] |
| Preview tag text | dark ink plate | 4.5:1 over any map colour | TBD | [ ] |
| Hotkey badge | verb face | 3:1 | TBD | [ ] |

| Colour-dependent element | Mitigation |
|---|---|
| Relation (war / ally / peace) | icon + word in tag and tooltip |
| Win / lose | WIN/LOSE word + ✓/✗ + numbers; bar has centre divider |
| Shortfall (missing gold) | "needs 2 moves" text + underline, not red alone |
| Targets on map | chevron (move) / crossed swords + hatch (attack) / ring (own) |

**Focus order:** 1 header owner link, 2 chips (read-only, tooltips on focus), 3 share segments, 4 verb slots 1..5, 5 Details, 6 Close. In Order row: 1 share, 2 Cancel, 3 Confirm. Popover: items in list order.

| Announcement (TTS / accessible name) | Timing |
|---|---|
| "Ariège, your province, 33 troops, 5 actions available" | on selection |
| "Recruit, 1 move, 60 gold. Unavailable: not enough gold, needs 20 more" | verb focus |
| "Attack Lérida: you win, hold 87, lose 32. Confirm or cancel" | preview |
| "Command rejected: not enough moves" | on error |
**Motor:** no drag, no timing-dependent or multi-finger action; confirmation by button as well as repeat-tap; hold time adjustable (hud.md 10.4); Declare War isolated. **Cognitive:** <= 4 chips + <= 5 verbs + share + cost = chunked in 4 rows; stable verb slots; reasons always stated; irreversible acts previewed. **Reduced motion / high contrast / text scale 175%:** per hud.md 10; the card reflows by the Overflow column of 5.2. Godot 4.4 has no screen-reader API: TTS + accessible names (hud.md Q5).

## 13. Localization Considerations
Languages: English, Russian, Uzbek (Latin); no RTL, no CJK. All strings via `T()`; every verb carries `label` (<= 2 lines of 8-10 chars), `tooltip` (full), `accessible_name`. +35% budget; Russian is the longest.
| Text | EN chars | Max chars (+35%) | Overflow behaviour | Risk |
|---|---|---|---|---|
| Verb label (Recruit, Colonize, Diplomacy, Ultimatum, Declare war) | 7-11 | 15 (2 lines x 8) | wrap to 2 lines, button grows to 56u; "…" + tooltip | High |
| Province name | <= 22 | 30 | 2 lines then "…" | Medium |
| Relation tag (AT WAR, YOUR PROVINCE) | 8-13 | 18 | chip widens, then "…" | Medium |
| Chip label + value ("Supply 4") | 8 | 11 | label drops to icon + tooltip | Low |
| Cost line ("Recruit +15 · 1 move · 60 g") | 28 | 38 | truncate "…", full in ReasonLine | High |
| Order confirm ("Attack · 2 moves · −32 men") | 26 | 36 | wraps to 2 lines, row grows to 56u | High |
| ReasonLine ("Not enough gold, needs 20 more") | 31 | 42 | wraps 2 lines | Medium |
| Ledger labels | 6-12 | 16 | wrap | Low |
Numbers use locale grouping; "men / g / moves" are units with plural rules (RU 3 forms, UZ 2). No text in images; hotkey badges are not localised.

## 14. Acceptance Criteria
**Performance**
- [ ] Selecting a province shows the card in <= 1 frame of content build + 160ms animation; case changes reuse nodes (no `queue_free` rebuild flicker); no drop below target fps on a mid-range phone
**Layout & rendering**
- [ ] Card is <= 480x160u (D), <= 464x104u (L-phone), <= 180u (P peek) with 5 verbs, in EN, RU, UZ and at 150% text, with no overlap or clipping; drawer adds <= 200u (D)
- [ ] Each of the five cases shows exactly the chips and verbs of section 5.5; hidden vs disabled rule holds
- [ ] Card never covers the selected province centroid; if it would, the map pans to keep it visible
**Orders on the map**
- [ ] Selecting an army marks valid targets without pressing Move; own army provinces are selected, not ordered, unless Move is armed
- [ ] Attack shows tag + arrow + exact numbers before any command is sent; no attack can be sent without Confirm / second tap / second right-click
- [ ] Changing the share while previewing recomputes the result; Esc steps back exactly one layer
- [ ] Non-attack moves into own/empty land complete in one tap/click and the selection follows
- [ ] Declare War requires a confirm dialog naming the infamy cost
**Input**
- [ ] Complete flow (select, target, preview, confirm; recruit; build; colonize; diplomacy) is achievable by touch only, by mouse only, and by keyboard only
- [ ] Hotkeys do nothing when the verb is absent in the case and never fire inside modals or text fields
**Events & data**
- [ ] Every command in section 9 fires exactly once with the documented payload; the card never mutates game state
- [ ] After End Turn or an AI event, the card rebuilds without losing the selection or focus slot
**Accessibility**
- [ ] 4.5:1 contrast for all text; greyscale test keeps relation, win/lose and shortfall distinguishable
- [ ] Every verb states its cost and, if disabled, the reason, visibly and via accessible name
- [ ] Reduced motion removes all card animations; all targets >= 48u on touch profiles
**Localization**
- [ ] No overflow in the longest language at 100% and 150% text; all strings come from `T()`

## 15. Open Questions
| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Q1 Contested: implicit targeting with exclusion of own armies (A, recommended: one tap to order, merge needs Move) vs always-explicit Move arming (B: safer for novices, one extra tap) | creative-director | playtest | Recommend A |
| Q2 Engine needs `can(cmd)` returning ok / reason / cost (gold, moves, men, DP) so disabled verbs and cost lines are accurate before pressing | gameplay-programmer | before build | Required |
| Q3 Should foreign provinces' stability / happiness / supply require Intel (shown as "?")? | game-designer | | Recommend yes if intel exists to spend |
| Q4 Recruit +15 and Hire +40 are fixed one-tap amounts; add a hold-to-repeat or a stepper? | game-designer | playtest | Recommend fixed for now |
| Q5 Gamepad is out of scope; keep the focus order but no on-map cursor? | creative-director | | Recommend yes |
| Q6 Landscape-phone card: handed bottom strip (recommended) vs right column (hud.md Q6) | creative-director | | |
| Q7 Build picker content (levels, upkeep, build turns) and Diplomacy popover list (trade, marriage exist as commands but had no panel entry) | game-designer | | |
