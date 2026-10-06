# UX Specification: New Game and Nation Pick Flow

> **Status**: Draft
> **Author**: ux-designer
> **Last Updated**: 2026-10-06
> **Screen / Flow Name**: `NewGameFlow` (era picker, `_begin_pick`, `_on_pick`, `_confirm_pick`, hot-seat)
> **Platform Target**: Android, iOS, Windows; touch-first, mouse/keyboard supported
> **Related UX Specs**: `main-menu.md`, `modal-system.md` (New Game page, Nations panel), `interaction-patterns.md` (P-01, P-10, P-13)
> **Accessibility Tier**: Comprehensive
> **Template**: UX Spec

---

## 1. Purpose and Player Need

**Need.** Choose a time and a nation that will be fun for the next hours, quickly, without reading a manual. **Player goal**: from title to first turn in 4 taps, with a pick made on real information. **Game goal**: era, difficulty, player count and nation for `TBGame.new`.
**Principle**: the map is the hero; the pick is a map gesture; cards confirm and explain (pillars 1-3).

## 2. Player Context on Arrival

| Question | Answer |
|----------|--------|
| Before | Tapped New Game on the title |
| Emotion | Curious, slightly overwhelmed (about 250 nations) |
| Knows | Little about the era; knows a few big names |
| Likely goal | "Play as France / my country / something easy" |
| Afraid of | Picking a hopeless nation; mis-tapping a tiny province on a phone |

## 3. Navigation Position

```
Title → [1 New Game page: era · difficulty · players] → [2 Pick on the map] → [3 Confirm card] → Game
         Page / Wide panel                                map hero + shortlist     not modal       first-turn alert chips
```
Header shows three pips "Era - Nation - Play". Back steps back one stage and **keeps** selections (pick > setup > title). Android Back closes the confirm card first. Hot-seat adds "Player k of n" to the pick stage.

## 4. Entry and Exit Points

| Entry | Data in |
|-------|---------|
| New Game plate | last era, difficulty, players from `cfg` |
| Back from Pick | era/difficulty/players |

| Exit | Result |
|------|--------|
| Play as X (last player) | `TBGame.new(era, difficulty)`, `set_human`, autosave, first-turn alert chips (neighbours, 2 advisor tips); tutorial coach marks on first run |
| Play as X (hot-seat, not last) | seat colour assigned; next player's pick stage |
| Back | previous stage |

## 5. Layout Specification

### 5.1 Stage 1: New Game page (Wide panel on landscape, Page on portrait)

```
┌ [←]  NEW GAME            ◆ Era · ○ Nation · ○ Play ┐   rail = chronology (existing EraRow)
│ 218BC Ancient │ 1804 AD  NAPOLEONIC ERA            │   detail = year, name, blurb,
│ 117   Roman   │ blurb ...                          │   GREAT POWERS as flag chips
│ ...           │ [🏴 Russia 116][🏴 Ottoman 158]... │   (name, provinces), "38 nations"
│ ▶1804 Napol.  │ ────────────────────────────────── │
│ ...           │ Difficulty  [Easy][Normal][Hard]   │   segmented (P-10, filled + check)
│               │ Players     [1][2][3][4]           │   1 = solo, 2-4 = hot-seat
├───────────────┴────────────────────────────────────┤
│ [Back]                         [NEXT: PICK NATION ▸]│
└────────────────────────────────────────────────────┘
```
Portrait: rail first (compact list), tap era to push detail with difficulty/players and footer. The button reads "Pick nation", not "New Game" (it only advances).

### 5.2 Stage 2-3: Pick (map) and confirm card

```
LANDSCAPE                                                PORTRAIT
[← Back]  ◆ Era · ◆ Nation · ○ Play  1804 · Normal  [▤ List]     [←] Pick your nation  [▤]
                         ┌────────── card (right, 360) ──┐      ┌── map hero (60 %) ──┐
        MAP (globe/flat) │ [flag] FRANCE            [✕]  │      │ nation lit, rest 25 % dim
   chosen nation lit,    │ (portrait) Emperor Napoleon 35│      ├─ card (≈220 dp) ────┤
   others dimmed 25 %    │ ▣62 provinces #4/38  ⚔1,724 #2│      │ [flag] FRANCE   [✕] │
                         │ ⚗ Industrial 3.5 #3  Empire   │      │ ruler · 62 #4 · 1724│
                         │ ◆ BALANCED START: 2 stronger  │      │ ◆ Balanced start    │
                         │   neighbours                  │      │ [ PLAY AS FRANCE ]  │
                         │ [  PLAY AS FRANCE  ]          │      ├─ shortlist rail ────┤
                         └───────────────────────────────┘      │ [Powers|Regional|Minor]
 [🎲][flag Russia #1][flag Ottoman #2][flag France #3 ●]...     │ [🎲][🏴][🏴][🏴] →   │
```

| Component | Spec |
|-----------|------|
| Hint slip | one line top centre: "Tap a nation" -> after pick: nation name; hot-seat: "Player 2 of 3" with seat colour chip |
| **Shortlist rail** (new) | horizontal chips, 64 high, bottom edge (thumb zone). Tier segmented above it: **Powers** (top 8 by provinces), **Regional** (9-40), **Minor** (rest, hidden when under 3). Chip: flag, name, rank, provinces. First chip is **Random** (dice glyph, "Surprise me") within the tier. Tap chip = same as tapping that nation |
| Map pick | tap a province: its **whole nation** lights (fill plus 2 px outline), others dim 25 %, camera frames the nation inside the free area (not under the card), 400 ms. Tapping another nation swaps the card content in place: no Back needed, no modal stacking |
| Tap magnet | a tap landing on sea or neutral within 20 dp snaps to the nearest owned province, preferring the **smaller** nation; unclaimed land shows toast "Unclaimed land" (today silent) |
| **Confirm card** | not a modal; map stays live. Contents (6 facts, no more): flag + name; **ruler** (portrait 56, title, name, age); **size rank** "62 provinces, #4 of 38" ; **army** "1,724, #2"; **tech** "Industrial 3.5, #3"; government and temperament; **start-difficulty chip** (shape + text: ▲ Easy / ◆ Balanced / ■ Hard + reason "2 stronger neighbours"). Primary "Play as France" (verb plus object). Card position: right 360 (landscape), above the rail (portrait) |
| List button | opens the Nations panel in **pick mode**: search, filter by tier, sort by size; detail pane footer "Play as X". Row tap flies the camera and fills the card (as `_pick_nation_from_list`) |
| Taken nations (hot-seat) | seat-colour fill plus "P1" badge (number, not colour only); card shows "Taken by Player 1", primary disabled with reason |

**Start difficulty (proposal, game-designer to tune)**: `threat` = land neighbours with army >= 1.3 x yours (same threshold as the briefing). Easy: rank <= 8 and threat <= 1. Hard: rank > 40 or threat >= 3. Else Balanced.

## 6. States and Variants

| State | Trigger | Behaviour |
|-------|---------|-----------|
| Preparing map | after Next | "Preparing map..." with chips disabled, 400 ms minimum |
| Idle | map ready | hint slip, rail, no card |
| Nation chosen | tap | nation lit, card in, primary focused |
| Tier empty (ancient eras) | fewer than 3 | tier hidden |
| Taken / unclaimed | hot-seat / neutral tap | see above |
| Era load failed | missing file | dialog, falls back to Modern (P-19) |
| First run | no `tutorial` flag | rail pre-selects Regional; 3 nations carry a "Good first game" tag (optional, see Q2) |

## 7. Interaction Map

| Input | Action |
|-------|--------|
| Tap nation / chip | select (light, frame, card) |
| Tap card primary / Enter | confirm; double-tap protection: ignored for 300 ms after the card appears |
| Tap X on card, tap empty sea twice, Android Back | dismiss the card (rail stays) |
| Pinch / two-finger drag | zoom / pan the map (unchanged) |
| Mouse | hover outlines nation and shows hover card; click selects; wheel zooms |
| Keyboard | arrow keys move the nation cursor (adjacent nations), Tab goes to the rail, Left/Right browses chips, Enter selects then focuses the primary, Esc dismisses card then goes Back, `R` random |
| Long-press nation (touch) | tooltip with rank and strength; no selection |

## 8. Data and Events

| Data | Source |
|------|--------|
| Provinces, rank, army, tech, government, temperament, ruler | `g.own_count`, `g.army`, `g.tech_level`, `g.era`, `g.regime`, `g.personality`, `g.r_*` (as `_on_pick` today) |
| Great powers per era | `TBModals._era_facts` (extend to flag chips) |
| Neighbour threat | shared-border scan as in `briefing` |
| Seats and colours | `_hot_list`, `HOT_COLORS` |
Events (analytics): `newgame.era`, `newgame.difficulty`, `newgame.players`, `pick.nation {via: map/chip/list/random}`, `pick.confirm`.

## 10-12. Transitions, Accessibility, Input

| Item | Spec |
|------|------|
| Transitions | Stage 1 to 2: panel fades 160 while globe flies to default view; card slides 180 (fade under Reduced motion); nation light fade 120; camera frame 400 |
| Targets | chips 64 x 48 dp min; card primary 56 high; tier segmented 48 |
| Colour | nation highlight = fill plus outline; difficulty = shape plus text; seats = colour plus number |
| Narration | on selection: "France, 62 provinces, rank 4 of 38, army 1,724, balanced start. Play as France button." |
| Focus order | hint slip (skipped), tier, rail chips, map cursor, card (X last), Back, List |
| Keyboard-only | whole flow completable with arrows, Tab, Enter, Esc |

## 13. Localization

| Element | Budget | Rule |
|---------|--------|------|
| Primary "Play as {nation}" | 28 chars | long nation names wrap to 2 lines (e.g., "Central Asian khanates") |
| Chip name | 16 | ellipsis plus tooltip |
| Reason line | 40 | wraps to 2 |
Nation and era names come from data in three languages; verify flags/names at +35 %.

## 14. Acceptance Criteria

- [ ] Title to first turn in 4 taps with remembered era/difficulty (New Game, Pick nation, tap nation, Play)
- [ ] Switching between candidate nations takes 1 tap and no dismiss
- [ ] A nation of 1-3 provinces is selectable on a 540x960 phone with a single tap near it (tap magnet), verified on 10 smallest nations
- [ ] Card shows ruler, size rank, army, tech and start-difficulty; text 4.5:1; fits RU at +35 %
- [ ] Hot-seat: seats cannot pick a taken nation; badges readable in grayscale
- [ ] Back keeps era/difficulty/players; Android Back closes the card before leaving
- [ ] Keyboard-only and screen-reader-narrated completion of the whole flow
- [ ] No modal stacking at any stage

## 15. Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Validate the start-difficulty formula and its thresholds | game-designer | Open |
| Q2: tag three "Good first game" nations per era? Needs curation per era (13 eras) | game-designer | Recommend only for Modern and Napoleonic first |
| Tier cut-offs 8 / 40 for eras with few nations | game-designer | Open |
| Camera framing needs an offset-by-free-rect API in `TBMapView` | ui-programmer | Open |
| Hot-seat: should picks be hidden from other seats until all have chosen? | creative-director | Recommend: no (shared screen, simpler) |
