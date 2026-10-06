# UX Specification: New Game and Nation Pick Flow

> **Status**: Draft
> **Author**: ux-designer
> **Last Updated**: 2026-10-06
> **Screen / Flow Name**: `NewGameFlow` (era picker, `_begin_pick`, `_on_pick`, `_confirm_pick`, hot-seat)
> **Platform Target**: Android, iOS, Windows; touch-first. Units `u` and profiles D/L/S/P as in `hud.md`
> **Related UX Specs**: `main-menu.md`, `modal-system.md` (New Game page, Nations panel), `interaction-patterns.md` (P-01, P-10, P-13)
> **Accessibility Tier**: Comprehensive
> **Template**: UX Spec

---

## 1. Purpose and Player Need

**Need.** Choose a time and a nation that will be fun for the next hours, fast, without a manual. **Player goal**: title to first turn in 4 taps, with a pick made on real information. **Game goal**: era, difficulty, player count and nation for `TBGame.new`. **Principle**: the map is the hero; the pick is a map gesture; cards confirm and explain.
**On arrival**: curious but overwhelmed (about 250 nations), knows a few big names, afraid of a hopeless nation or of mis-tapping a tiny province on a phone.

## 3. Navigation Position

```
Title → [1 New Game page: era · difficulty · players] → [2 Pick on the map] → [3 Confirm card] → Game
         page / wide panel                               map hero + shortlist    not a modal      first-turn alert chips
```
Header shows three pips "Era - Nation - Play". Back steps back one stage and **keeps** selections (pick, setup, title); Android Back closes the confirm card first. Hot-seat adds "Player k of n" to stage 2.

## 4. Entry and Exit Points

| Entry | Data in |
|-------|---------|
| New Game plate | last era, difficulty, players from `cfg` |

| Exit | Result |
|------|--------|
| Play as X (last or only player) | `TBGame.new(era, difficulty)`, `set_human`, autosave; first-turn alert chips (neighbour threat, 2 advisor tips; the Briefing modal is dropped); tutorial coach marks on first run |
| Play as X (hot-seat, not last) | seat colour assigned, next player's pick |
| Back | previous stage |

## 5. Layout Specification

### 5.1 Stage 1: New Game page (wide panel on D/L/S, page on P)

```
┌ [←] NEW GAME                         ◆ Era · ○ Nation · ○ Play ┐
│ 218 BC Ancient │ 1804 AD  NAPOLEONIC ERA                        │  rail = chronology (existing EraRow)
│ 117    Roman   │ blurb ...                                      │  detail = year, name, blurb,
│ ▶1804  Napol.  │ GREAT POWERS [Russia 116][Ottoman 158][UK 31]  │  great powers as flag chips, "38 nations"
│ ...            │ Difficulty [Easy][Normal][Hard]                │  segmented (P-10): filled + check
│                │ Players    [1][2][3][4]   (1 = solo, 2-4 hot-seat) │
├────────────────┴────────────────────────────────────────────────┤
│ [Back]                                  [PICK NATION ▸]          │  verb, not "New Game"
└─────────────────────────────────────────────────────────────────┘
```
On P: era list first; tap pushes the detail with difficulty, players and footer.

### 5.2 Stages 2-3: pick on the map and confirm card

```
D/L/S                                                   P
[← Back] ◆Era ◆Nation ○Play  1804 · Normal      [▤ List]    [←] Pick your nation   [▤]
                             ┌ card (right, 340u) ───────┐   ┌── map hero ~60 % ──────┐
   MAP: chosen nation lit,   │ [flag] FRANCE         [✕] │   │ nation lit, others 25 %│
   others dimmed 25 %        │ [ruler] Emperor Napoleon 35│   ├─ card ~190u ───────────┤
                             │ 62 provinces #4 of 38      │   │ [flag] FRANCE      [✕] │
                             │ Army 1,724 #2 · Industrial │   │ ruler · 62 #4 · 1,724  │
                             │ 3.5 #3 · Empire           │   │ ◆ Balanced start       │
                             │ ◆ BALANCED START          │   │ [  PLAY AS FRANCE  ]   │
                             │   2 stronger neighbours   │   ├─ shortlist rail ───────┤
                             │ [  PLAY AS FRANCE  ]      │   │ [Powers|Regional|Minor]│
                             └───────────────────────────┘   │ [Random][Russia][..] → │
 [Random][Russia #1][Ottoman #2][France #3 ●] ...            └────────────────────────┘
```

| Component | Spec |
|-----------|------|
| Hint slip | one line top centre: "Tap a nation", then the nation's name; hot-seat: "Player 2 of 3" plus seat chip |
| **Shortlist rail** (new) | horizontal chips 64u high in the thumb zone. Tier segmented above: **Powers** (top 8 by provinces), **Regional** (9-40), **Minor** (rest; hidden under 3). Chip = flag, name, rank, provinces. First chip **Random** ("Surprise me", within the tier). Tap chip = tap that nation |
| Map pick | tapping a province lights its **whole nation** (fill plus 2 px outline), dims others to 25 %, frames the nation in the free area (not under the card) in 400 ms. Tapping another nation swaps the card in place: no dismiss, no stacked modals |
| Tap magnet | a tap on sea or neutral within 20u snaps to the nearest owned province, preferring the **smaller** nation; unclaimed land shows toast "Unclaimed land" (today silent) |
| **Confirm card** | not modal, map stays live. Six facts: flag + name; **ruler** (portrait 56u, title, name, age); **size rank** "62 provinces, #4 of 38"; **army** "1,724, #2"; **tech** "Industrial 3.5, #3"; government and temperament; plus the **start-difficulty chip** (shape + text: ▲ Easy / ◆ Balanced / ■ Hard, with the reason). Primary "Play as France" (verb + object, ignored for 300 ms after the card appears) |
| List button | opens the Nations panel in **pick mode** (search, tier filter, sort by size; detail pane footer "Play as X"); row tap flies the camera and fills the card (as `_pick_nation_from_list`) |
| Taken nations (hot-seat) | seat-colour fill plus "P1" badge (number, not colour only); card says "Taken by Player 1", primary disabled with reason |

**Start difficulty (proposal for game-designer)**: `threat` = land neighbours with army >= 1.3 x yours (same threshold as the briefing). Easy: rank <= 8 and threat <= 1. Hard: rank > 40 or threat >= 3. Otherwise Balanced.

## 6. States and Variants

| State | Trigger | Behaviour |
|-------|---------|-----------|
| Preparing map | after Pick nation | "Preparing map..." chips disabled, 400 ms minimum |
| Nation chosen | tap | nation lit, card in, primary focused |
| Tier too small | under 3 nations | tier hidden |
| Taken / unclaimed | hot-seat / neutral tap | as above |
| Era load failed | missing data | dialog, falls back to Modern (P-19) |
| First run | no `tutorial` flag | rail starts on Regional; optional "Good first game" tag (Q below) |

## 7. Interaction Map

| Input | Action |
|-------|--------|
| Tap nation / chip | select (light, frame, card) |
| X on card, Android Back, tap empty sea twice | dismiss card (rail stays); next Back leaves the stage |
| Pinch / two-finger drag | zoom / pan (unchanged) |
| Long-press nation (touch) | tooltip with rank and strength, no selection |
| Mouse | hover outlines the nation and shows the hover card; click selects; wheel zooms |
| Keyboard | arrows move a nation cursor, Tab to rail, Left/Right chips, Enter selects then focuses primary, Esc dismisses card then Back, `R` random |

## 8. Data and Events

| Data | Source |
|------|--------|
| Provinces, rank, army, tech, government, temperament, ruler | `g.own_count`, `g.army`, `g.tech_level`, `g.era`, `g.regime`, `g.personality`, `g.r_*` (as `_on_pick` today) |
| Great powers per era; neighbour threat; seats | `TBModals._era_facts` (extend to flag chips); briefing border scan; `_hot_list`, `HOT_COLORS` |
Events (analytics): `newgame.era / difficulty / players`, `pick.nation {via: map|chip|list|random}`, `pick.confirm`.

## 10-13. Transitions, Accessibility, Localization

| Item | Spec |
|------|------|
| Transitions | stage 1 to 2: panel fades 160 ms while the globe flies to the default view; card slides 180 ms; nation light 120 ms; frame 400 ms; reduced motion: fades 80 ms |
| Targets | chips 64x48u min, card primary 56u high, tier segmented 48u |
| Colour | highlight = fill plus outline; difficulty = shape plus text; seats = colour plus number |
| Narration | "France, 62 provinces, rank 4 of 38, army 1,724, balanced start. Play as France button." |
| Focus order | tier, rail chips, map cursor, card (X last), Back, List |
| Localization | "Play as {nation}" budget 28 chars, long names wrap to 2 lines ("Central Asian khanates"); chip name 16 (ellipsis plus tooltip); reason line 40 (wraps); names come in 3 languages at +35 % |

## 14. Acceptance Criteria

- [ ] Title to first turn in 4 taps with remembered era/difficulty (New Game, Pick nation, tap nation, Play)
- [ ] Switching between candidate nations takes 1 tap, no dismiss; no modal stacking at any stage
- [ ] Each of the 10 smallest nations is selectable on a 540x960 phone with one tap near it (tap magnet)
- [ ] Card shows ruler, size rank, army, tech, start difficulty; text 4.5:1; fits RU at +35 %
- [ ] Hot-seat: taken nations cannot be picked; badges readable in grayscale
- [ ] Back keeps era/difficulty/players; Android Back closes the card first
- [ ] Whole flow completable by keyboard only and by narration

## 15. Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Validate the start-difficulty formula and thresholds; tier cut-offs 8 / 40 for small eras | game-designer | Open |
| "Good first game" tag on 3 nations per era needs curation (13 eras): Modern and Napoleonic first? | game-designer | Recommend yes |
| Camera framing needs an offset-by-free-rect API in `TBMapView` | ui-programmer | Open |
| Hot-seat: hide earlier picks from later seats? | creative-director | Recommend no (shared screen) |
