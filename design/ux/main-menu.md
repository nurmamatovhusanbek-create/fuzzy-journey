# UX Specification: Main Menu (Title Screen)

> **Status**: Draft
> **Author**: ux-designer
> **Last Updated**: 2026-10-06
> **Screen / Flow Name**: `TitleScreen` (`main.gd show_menu`, `TBMenuParts`)
> **Platform Target**: Android, iOS, Windows; touch-first, mouse/keyboard supported
> **Related GDDs**: none (`design/game-brief.md`)
> **Related UX Specs**: `nation-pick.md` (next flow), `modal-system.md` (Saves, Settings, Honours, Menu containers), `interaction-patterns.md`
> **Accessibility Tier**: Comprehensive
> **Template**: UX Spec

---

## 1. Purpose and Player Need

**Need.** Get back into the campaign in one tap, or start a new one, while the first frame already says "history, cartography, a staff table at night".
**Player goal**: resume or begin a game within 5 seconds of launch. **Game goal**: route to the right flow (Continue / New / Load / Online) and surface settings and honours without clutter.
**Keep (player loves it)**: the turning globe inside the graduated bezel ring, title set inside the ring. **Change**: entries become plates (affordance and contrast), the list shrinks to 4, tools move to a row.

## 2. Player Context on Arrival

| Question | Answer |
|----------|--------|
| Doing before | Just launched, or left a game via Menu |
| Emotion | Anticipation; returning players want speed |
| Load | Near zero |
| Knows | Whether a save exists (Continue subline tells them which) |
| Likely goal | Continue (returning) / New Game (first time) |
| Afraid of | Starting over by mistake; losing a save |

**Target feeling**: a lit table at night; one obvious next step.

## 3. Navigation Position

```
Title (root)
 ├── Continue → Game (autosave)           ├── Honours (Wide panel / Page)
 ├── New Game → New Game page → Pick      ├── Settings (Wide panel / Page)
 ├── Load → Saves (Load tab)              └── How to play (Codex + tutorial replay)
 └── Multiplayer → lobby
```
Modal behaviour: the title is the root, not modal. Panels opened from it follow `modal-system.md`. Back at root: first press toast "Press Back again to exit" (2 s), second quits. Esc on desktop does the same (no accidental quit).

## 4. Entry and Exit Points

| Entry | Source | Notes |
|-------|--------|-------|
| Launch | OS | after splash; autosave read for the Continue plate |
| Menu hub > Main menu | Game | L2 confirm "Leave game? Progress since turn N is lost" with [Save and exit] |
| Game over > Main menu | Game | |
| Pick or setup Back | New game flow | selections kept |

| Exit | Destination | Data out |
|------|-------------|----------|
| Continue | Game at autosave | slot `auto` |
| New Game | New Game page | defaults = last era/difficulty from `cfg` |
| Load | Saves page | slot |
| Multiplayer | `mp.open_menu()` | |

## 5. Layout Specification

### 5.1 Wireframe (CD landscape and CP portrait)

```
LANDSCAPE 1280x720                         PORTRAIT 540x960
     ╭─ graduated bezel ring (turns) ─╮            ╭── bezel (min(w-24, 0.62h)) ──╮
    ╱  ┊ ┊  T E R R A   B E L L U M ┊ ┊ ╲          │   TERRA BELLUM  (38)        │
   │      ───── ◆ ─────  tagline            │      │   ─── ◆ ───  tagline        │
   │   ┌────────────────────────────┐       │      │  ┌───────────────────────┐   │
   │   │ ▶ CONTINUE  France·T12·1804│ ●     │      │  │ ▶ CONTINUE  France... │   │
   │   ├────────────────────────────┤       │      │  ├───────────────────────┤   │
   │   │   NEW GAME                 │       │      │  │   NEW GAME            │   │
   │   │   LOAD                     │       │      │  │   LOAD                │   │
   │   │   MULTIPLAYER              │       │      │  │   MULTIPLAYER         │   │
    ╲  └────────────────────────────┘  ╱      ╲  └───────────────────────┘ ╱
     ╰────────────────────────────────╯       (tools row below ring, thumb zone)
  [Honours 5/19] [Settings] [How to play] [EN|RU|UZ]            v0.9.3 (build 412)
```

| Zone | Content | Size | Notes |
|------|---------|------|-------|
| Globe + bezel | live map, spin 0.12 rad/s; bezel with 120 ticks, outer double arc, 4 fixed lubber marks | CD: min(w,h) x 0.88; CP: min(w-24, 0.62h) | globe dimmed by a flat disc (alpha 0.78) so text never sits on bright land |
| Title block | wordmark Cinzel 54 / 38, ornament rule, tagline caps 12 | top third of ring | one ornament rule stays (decoration budget) |
| Entry plates | max 4, stacked, 340 x 56 (CD) / 300 x 56 (CP) | centre / lower ring | dark glass fill alpha >= 0.8, 1 px brass border; primary plate brass-filled |
| Tools row | 4 icon chips, 48 dp, each with text label | below ring (CP) / bottom edge (CD) | thumb zone in portrait, safe-area aware |
| Version | caps 12, dim | bottom right | real version string, not "godot build" |

### 5.3 Entry list

| # | Entry | Shown when | Action | Plate subline |
|---|-------|-----------|--------|---------------|
| 1 | **Continue** (primary if shown) | an autosave exists and loads | loads `auto` | "France - Turn 12 - 1804 AD"; unreadable save: plate disabled, subline "Autosave unreadable" |
| 2 | **New Game** (primary if no Continue) | always | New Game page | none |
| 3 | **Load** | always; disabled with reason "No saves yet" when none | Saves > Load | "3 saves" |
| 4 | **Multiplayer** | always | lobby | "Offline" chip if no network |
Tools: **Honours n/19**, **Settings**, **How to play** (Codex + tutorial replay), **Language** (EN / RU / UZ, one tap, applies live). **Removed from the title**: Hot-seat (moves to the New Game page as the Players selector), Codex as a separate entry.

### 5.4 Information hierarchy
1 Title and primary plate, 2 other plates, 3 tools row, 4 version. Nothing else on screen: pillar 4.

## 6. States and Variants

| State | Trigger | Change |
|-------|---------|--------|
| First run | no saves | no Continue; New Game primary and focused; tutorial offered on first game start |
| Returning | autosave valid | Continue primary and focused |
| Autosave corrupt | meta fails | Continue disabled with reason; New Game primary |
| Loading a save | tap Continue/Load | plates disabled, busy ring on the plate, 400 ms minimum |
| Panel open | Honours/Settings/How to play | spin stops, ring dims to 35 %, focus trapped in panel |
| Reduced motion | setting | globe and bezel static (stills show a pleasing meridian) |
| Language changed | tap chip | title rebuilt in place |

## 7. Interaction Map

| Input | Action | Response |
|-------|--------|----------|
| Tap / click plate | activate | press tint 60 ms, `tap` sound; plate flanking diamonds (kept) mark hover **and focus** |
| Hover plate | highlight | brass border, diamonds extend |
| Up / Down / Tab | move focus | focus ring 2 px; initial focus = primary plate |
| Enter / Space | activate | |
| `C` / `N` / `L` | Continue / New / Load | shown in tooltips |
| Left / Right in tools row | move | |
| Esc / Android Back | first: toast, second: quit | P-20 step 7 |
| Drag on globe | spin by hand, resumes after 3 s | nice-to-have |

## 8. Data Requirements

| Data | Source | Missing |
|------|--------|---------|
| Autosave meta (nation, turn, year, version) | `TBSave.meta("auto")` | hide Continue |
| Save count | `TBSave` slots | "No saves yet" |
| Honours count | `TBHonours.count(cfg)` | 0/19 |
| Language, reduced motion | `cfg` | defaults |
| Version / build | project setting | "dev" |

**Events (analytics only)**: `menu.continue`, `menu.new_game`, `menu.load`, `menu.multiplayer`, `menu.honours`, `menu.settings`, `menu.lang {code}`.

## 10. Transitions

| Transition | ms | Reduced motion |
|------------|----|----------------|
| Plate hover/focus | 80 | none |
| Title to New Game page | globe slows to a stop 400 ms, Page/Wide panel fades in 160 | instant |
| Continue to Game | camera flies to capital 800 ms (existing) | cut |

## 11-12. Accessibility and Input Checklist

- [ ] Plate text 4.5:1 on its plate regardless of globe position; ring ticks 3:1 and decorative (not announced)
- [ ] Every plate and tool chip focusable with a visible ring; tab order: plates, tools, language
- [ ] Narration (opt-in TTS): "Continue. France, turn 12, 1804." on focus
- [ ] Targets 48 dp; tools row labels visible (never icon-only)
- [ ] No flashing; spin stops under Reduced motion; spin pauses whenever a panel is open
- [ ] Back/Esc behaviour as section 3; focus returns to the opener when a panel closes

## 13. Localization

| Element | EN | Budget | Rule |
|---------|----|--------|------|
| Plate label | 10 | 18 | wraps to 2 lines; plate grows to 64 |
| Sublines | 24 | 34 | ellipsis |
| Tool labels | 8 | 14 | wrap under icon |
| Title "TERRA BELLUM" | 12 | fixed wordmark | not translated |
RU not upper-cased; Uzbek apostrophes in "O‘zbekcha" need font fallback check.

## 14. Acceptance Criteria

- [ ] Plate text contrast 4.5:1 at every globe rotation angle (sampled at 8 angles)
- [ ] Entry count <= 4 plates plus 4 tools; Hot-seat not on title
- [ ] First interactive frame under 1 s after splash on min-spec Android; Continue loads in under 2 s
- [ ] Title and plates fit inside the ring at 540x960, 800x360 physical, 1280x720, 1920x1080 in EN/RU/UZ
- [ ] Keyboard-only: launch, Continue, Settings, back all work; Back-twice-to-quit verified on Android

## 15. Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Approve moving Hot-seat into New Game page and dropping the title entry? | creative-director | Recommended: yes |
| Rejected: era dial on the bezel (panels hide it, drag gesture fights panel scroll). Revisit as a pick-screen flourish? | creative-director | Recommend no |
| Does a flat dark disc under the title hide too much of the globe? Alternative: plates only, no disc. | art-director | test both |
| Real version string and build number source | producer | Open |
