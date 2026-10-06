# UX Specification: Main Menu (Title Screen)

> **Status**: Draft
> **Author**: ux-designer
> **Last Updated**: 2026-10-06
> **Screen / Flow Name**: `TitleScreen` (`main.gd show_menu`, `TBMenuParts`)
> **Platform Target**: Android, iOS, Windows; touch-first, mouse/keyboard supported. Units `u` and profiles D/L/S/P as in `hud.md`
> **Related UX Specs**: `nation-pick.md` (next flow), `modal-system.md` (Saves, Settings, Honours containers), `interaction-patterns.md`
> **Accessibility Tier**: Comprehensive
> **Template**: UX Spec

---

## 1. Purpose and Player Need

**Need.** Get back into the campaign in one tap, or start a new one, while the first frame already says "history, cartography, a staff table at night". **Player goal**: resume or begin within 5 seconds of launch. **Game goal**: route to Continue / New / Load / Online; surface Settings and Honours without clutter.
**Keep (the player loves it)**: the turning globe inside the graduated bezel ring, title set inside the ring. **Change**: entries become plates (affordance, guaranteed contrast), the list shrinks to 4, tools move to one row.
**Context on arrival**: just launched or left a game; low cognitive load; returning players want speed, first-timers want one obvious step; they fear starting over by mistake.

## 3. Navigation Position

```
Title (root)
 ├── Continue → Game (autosave)           ├── Honours (wide panel / page)
 ├── New Game → New Game page → Pick      ├── Settings (wide panel / page)
 ├── Load → Saves (Load tab)              └── How to play (Codex + tutorial replay)
 └── Multiplayer → lobby
```
The title is the root, not modal. Panels follow `modal-system.md`. Back at root: first press toast "Press Back again to exit" (2 s), second quits; Esc on desktop behaves the same (no accidental quit).

## 4. Entry and Exit Points

| Entry | Notes |
|-------|-------|
| Launch (after splash) | autosave meta read for the Continue plate |
| Menu hub > Main menu, Game over > Main menu | Menu hub shows an L2 confirm "Leave game? Progress since turn N is lost" with [Save and exit] |
| Back from setup / pick | selections kept |

| Exit | Destination |
|------|-------------|
| Continue | Game at autosave (camera flies to capital, 800 ms) |
| New Game | New Game page, defaults = last era/difficulty/players from `cfg` |
| Load / Multiplayer / Honours / Settings / How to play | Saves / `mp.open_menu()` / panels |

## 5. Layout Specification

### 5.1 Wireframe

```
LANDSCAPE (D/L/S)                                  PORTRAIT (P)
    ╭── graduated bezel ring (turns) ──╮             ╭── bezel: min(w-24, 0.62h) ──╮
   ╱  ┊     T E R R A  B E L L U M    ┊ ╲            │   TERRA BELLUM (38u)       │
  │       ───────── ◆ ─────────          │           │   ─── ◆ ───  tagline       │
  │    ┌──────────────────────────────┐  │           │  ┌──────────────────────┐  │
  │    │▶ CONTINUE  France·T12·1804 AD│  │           │  │▶ CONTINUE  France...  │  │
  │    │  NEW GAME                    │  │           │  │  NEW GAME            │  │
  │    │  LOAD                        │  │           │  │  LOAD                │  │
  │    │  MULTIPLAYER                 │  │           │  │  MULTIPLAYER         │  │
   ╲   └──────────────────────────────┘ ╱            ╰──┴──────────────────────┴──╯
    ╰──────────────────────────────────╯             [Honours][Settings][How to play][EN|RU|UZ]
[Honours 5/19] [Settings] [How to play] [EN|RU|UZ]                       v0.9.3 (build 412)
```

| Zone | Content | Size | Notes |
|------|---------|------|-------|
| Globe + bezel | live map, spin 0.12 rad/s; 120 ticks, double outer arc, 4 fixed lubber marks (existing `Bezel`) | D/L/S: 0.88 x min(w,h); P: min(w-24, 0.62h) | flat dark disc under text, alpha 0.78, so text never sits on bright land |
| Title block | wordmark Cinzel 54u / 38u, one ornament rule (the menu's only ornament), tagline caps 12u | top third of ring | not translated |
| Entry plates | max 4, stacked; 340x56u (D) / 300x56u (P) | inside ring | dark glass alpha >= 0.8, 1 px brass border; primary plate brass-filled; flanking diamonds (kept) on hover **and focus** |
| Tools row | 4 chips, 48u, text labels always | below ring (P) / bottom edge (D/L/S) | thumb zone in portrait, inside safe area |
| Version | caps 12u, dim | bottom right | real version, not "godot build" |

### 5.3 Entry list

| # | Entry | Shown when | Action | Plate subline |
|---|-------|-----------|--------|---------------|
| 1 | **Continue** (primary if shown) | an autosave loads | loads `auto` | "France - Turn 12 - 1804 AD"; unreadable: disabled, "Autosave unreadable" |
| 2 | **New Game** (primary if no Continue) | always | New Game page | none |
| 3 | **Load** | always; disabled with reason "No saves yet" | Saves, Load tab | "3 saves" |
| 4 | **Multiplayer** | always | lobby | "Offline" chip when no network |

Tools: **Honours n/19**, **Settings**, **How to play** (Codex + tutorial replay), **Language** (EN / RU / UZ, one tap, live). **Removed from the title**: Hot-seat (becomes the Players selector on the New Game page), Codex as its own entry. Information hierarchy: title and primary plate, other plates, tools, version; nothing else (pillar 4).

## 6. States and Variants

| State | Trigger | Change |
|-------|---------|--------|
| First run | no saves | no Continue; New Game primary and focused; tutorial offered at first game start |
| Returning | valid autosave | Continue primary and focused |
| Autosave corrupt | meta fails | Continue disabled with reason; New Game primary |
| Loading | tap Continue/Load | plates disabled, busy ring on the plate, 400 ms minimum |
| Panel open | Honours / Settings / How to play | spin stops, ring dims to 35 %, focus trapped in panel |
| Reduced motion | setting (default follows OS) | globe and bezel static |

## 7. Interaction Map

| Input | Action | Response |
|-------|--------|----------|
| Tap / click plate | activate | press tint 60 ms, `tap` sound |
| Hover plate | highlight | brass border, diamonds extend |
| Up / Down / Tab | move focus | 2 px focus ring; initial focus = primary plate |
| Enter / Space | activate | |
| `C` / `N` / `L` | Continue / New / Load | in tooltips |
| Esc / Android Back | first: toast, second: quit | P-20 step 7 |
| Drag on globe | spin by hand, resumes after 3 s | nice to have |

## 8. Data and Events

| Data | Source | Missing |
|------|--------|---------|
| Autosave meta (nation, turn, year, version) | `TBSave.meta("auto")` | hide Continue |
| Save count, honours count | `TBSave`, `TBHonours.count(cfg)` | "No saves yet", 0/19 |
| Language, reduced motion | `cfg` | defaults |
Events (analytics only): `menu.continue / new_game / load / multiplayer / honours / settings / lang {code}`.

## 10-12. Transitions, Accessibility, Input

| Item | Spec |
|------|------|
| Transitions | plate hover/focus 80 ms; title to New Game: globe eases to a stop 400 ms, page fades in 160 ms; reduced motion: cuts |
| Contrast | plate text 4.5:1 at every globe angle; ticks 3:1 and decorative (not announced) |
| Focus order | plates top to bottom, tools left to right, language last; ring visible; returns to the opener when a panel closes |
| Narration (opt-in TTS) | "Continue. France, turn 12, 1804." on focus |
| Targets / motion | 48u; labels never icon-only; no flashing; spin stops under Reduced motion and while any panel is open |
| Localization | plate label 10 chars EN, budget 18 (wraps, plate grows to 64u); subline budget 34 (ellipsis); RU not upper-cased; check "O‘zbekcha" font fallback |

## 14. Acceptance Criteria

- [ ] Plate text contrast 4.5:1 at every globe rotation angle (sample 8 angles)
- [ ] At most 4 plates plus 4 tools; Hot-seat not on the title
- [ ] First interactive frame under 1 s after splash on min-spec Android; Continue loads in under 2 s
- [ ] Title and plates fit inside the ring at 540x960, 800x360, 1280x720, 1920x1080 px in EN/RU/UZ
- [ ] Keyboard-only: launch, Continue, Settings, back; Back-twice-to-quit verified on Android

## 15. Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Approve moving Hot-seat into the New Game page and dropping the title entry? | creative-director | Recommended: yes |
| Rejected: era dial on the bezel (panels hide it; drag fights panel scroll). Revisit as a pick-screen flourish? | creative-director | Recommend no |
| Flat dark disc under the title vs plates only: how much globe does it hide? | art-director | test both |
| Real version string and build number source | producer | Open |
