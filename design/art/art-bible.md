# Art Bible: Terra Bellum

> **Status**: Draft v1 (UI refinement scope: interface, map markers, map lenses)
> **Owned By**: art-director
> **Last Updated**: 2026-10-06
> **Art Director Sign-Off (AD-ART-BIBLE)**: Not yet reviewed
> **Inputs**: `design/game-brief.md` (pillars, player feedback), current `godot/src/ui/*`, screenshots of the current build
> **Creative-director decisions applied**: refine the paper table (not a new skin); fix "too decorative" and "not game-like enough";
> feel = Total War / Hearts of Iron IV command table; accessibility tier = Comprehensive.
> **Scope note**: the nine template sections are kept in order. Section 5 = *Units, standards and map markers*; section 6 =
> *Map and terrain visual language*. There are no characters or environments to model; the map shader is owned by technical-artist.

---

## 1. Visual Identity Statement

**Anchor (one line):** *Dark table, pale documents: plain paper, hard ink, one brass highlight. A mark exists only if it is an order, a number or a boundary.*

**The split that fixes "paper but game-like"** (decision, because it resolves most arguments):
- **Furniture is dark and flat.** Top bar, dock, toasts, tooltips, map legend, alert chips: umber-black plates, cream text, brass accents. These are the persistent command layer (the "HoI4/Total War strip").
- **Documents are pale and flat.** Province panel, order previews, modals: laid-paper fill, ink text. These are read, decided on, and dismissed.
- **Ceremony is the only place paper gets dressed.** One "hero sheet" per screen at most (event, ultimatum, era, game over, chronicle) may carry the grain, ragged cut and corner guards. Nothing else does.

| # | Principle | Design test ("when X is ambiguous, choose Y") | Pillar |
|---|-----------|-----------------------------------------------|--------|
| 1 | **Structure over ornament** | *Delete test:* remove the element; if the player can still make the same decision, it was decoration, so delete it. Between an ornament and 8 px of whitespace, choose whitespace. | 5 |
| 2 | **The map is the hero, orders live on it** | *Verb test:* if a verb can be a map gesture with an on-map preview (arrow, ring, chip), it is, and the panel only confirms or explains. Between a bigger panel and a clearer arrow, choose the arrow. | 1, 2 |
| 3 | **Quiet until it matters, never colour alone** | *Squint + greyscale test:* blur 50 % and drop to greyscale (then deuteranopia). You must still find the primary action, the highest-priority alert and the group boundaries. If a meaning survives only as hue, add a shape or label; if three things shout, demote two. | 3, 4 |

---

## 2. Mood & Atmosphere

Single tonal world: *a staff officer at a map table at night*. The map is lit; the room is dark; paper is the lamp-lit working surface.

| State | Emotional target | Light and colour | Descriptors | Energy | What the UI does |
|-------|------------------|------------------|-------------|--------|------------------|
| Planning (map idle, default) | Calm, slightly dangerous focus | Cool navy table, warm paper islands, one brass accent | still, measured, legible, quiet | Contemplative | Only bar + dock + one legend; alerts as small chips. No pulses. |
| Giving orders (armed move/attack) | Intent, commitment | Same, but valid targets get brass rings, invalid recede to 40 % | precise, taut, deliberate | Measured | Orders arrow follows the finger/cursor; command card shows "armed" (brass outline); preview chip at the target. |
| War / danger (hostile contact, revolt, supply loss) | Cold alarm, not panic | Red appears only as 2 px edges, hatching and chip bars; never as a screen tint | tense, clipped, urgent | Alert (still ≤ 1 pulse / 2 s) | Alert chips climb the priority stack; war-state gonfalons gain red outline + swords pip. |
| Turn resolving | Weight of the machine turning | Seal sweeps; numbers roll; everything else still | procedural, inevitable | Measured, 1–2 s | Input blocked visibly (seal busy ring). Roll deltas with ▲▼, then settle. |
| Ceremony (event, ultimatum, treaty, era) | A document placed in front of you | Scrim 72 % table-navy; the hero sheet is the brightest thing on screen | formal, hushed, consequential | Contemplative | The one dressed sheet. Choices are command cards with consequence lines. |
| Victory / defeat / game over | Closure, a stamp | Wax stamp (the only other wax object) on a hero sheet; victory brass edge, defeat oxblood edge | final, dignified, sober | Contemplative | Stats ledger; no confetti; no extra particles. |
| Menu / title | The table before play | Globe on the bezel ring, brass wordmark, nothing else lit | anticipatory, quiet | Contemplative | Only screen allowed the Cinzel 900 wordmark and bezel ring; menu items are plain text rows. |

---

## 3. Shape Language

### 3.1 UI shape grammar
- **Cut, not round.** Every plate, card, button, input and chip is a rectangle with a **4 px 45° chamfer** on all four corners (panels and hero sheet: 6 px). Rationale: reads as engraved military furniture, differs from every rounded mobile UI, and costs one 8-point polygon.
  - Exceptions (hero/round shapes, a deliberate short list): End Turn seal, count badges, flag-dot pips, slider thumb, map gonfalon pip. Circles mean *count / commit / handle*; nothing else is a circle.
  - Chips of height ≤ 28 px use **2 px chamfer** (4 px looks gnawed at small size).
- **Hero vs supporting shapes.** Hero: the map, End Turn seal, selected province, orders arrow, gonfalon. Supporting: plates and chips (flat, rectilinear, quiet). Anything that is not hero must not use a gradient, bevel, glow or texture.
- **Affiliation is shape-coded** (see section 5): own = thick outline, ally = double line + link pip, war = red outline + swords pip, foreign = 1 px outline.
- **Direction.** Horizontal reading rails: title left, figures right-aligned in Mono, actions at the bottom or right. No centred stacks except menus and modals' titles.

### 3.2 Border weights (whole pixels only; never 0.7/0.9)
| Use | Weight | Colour token |
|-----|--------|--------------|
| Hairline divider (grouping aid, never relied on alone) | 1 px | `hair` |
| Control / plate border | 1 px | `rule` (paper) or `rule-dark` (bar) |
| Emphasis (selected row bar, active tab underline, brass accent bar) | 3 px | `oxblood` / `brass` |
| Focus ring | 2 px ring + 2 px gap + 1 px inner contrast ring | see 4.5 |
| Map: nation border / province border / selection | 2 px / 1 px (fades in near zoom) / 3 px + 1 px ink | shader params (section 6) |
| Orders arrow | 4 px core + 2 px casing each side | section 5 |

Maximum **one** double border per screen (the hero sheet). No inner "inset" rules on plates.

### 3.3 Shadow rules
One flat, hard shadow, no blur, no stacking: **elevation 0** = bar/dock/chips/flat rows (none); **elevation 1** = panels, cards, popups: one polygon offset (0, 3 px) at black 26 %; **elevation 2** = modals/hero sheet: one polygon offset (0, 6 px) at black 32 %. Pressed controls lose their shadow and shift content 1 px down. Text halo shadows exist **only** on map labels (section 6).

### 3.4 Spacing scale and sizes (4/8 px steps; logical px)
Scale: `4 · 8 · 12 · 16 · 24 · 32 · 48`. Use 4 inside a chip, 8 between items in a group, 16 between groups, 24 panel/modal outer padding on landscape, 16 on phone portrait.

| Item | Standard | Notes |
|------|----------|-------|
| Minimum touch target | **48 × 48** (hit area; the visual may be smaller with hit-slop) | Desktop pointer min 32 high. Targets ≥ 8 px apart. |
| Button / tab height | 44 desktop, 48 touch; min width 96 | |
| List row / command card | 48 / 56 min; 40 row only at Compact density | |
| Top bar height | 48 desktop, 44 phone | Safe-area inset added on top for notch/cutout. |
| Dock | 56 wide rail (landscape) / 56 high rail (portrait) | |
| Side panel | 360 wide landscape (≥ 1280), 340 at 960; bottom sheet in portrait, max 62 % height | One panel at a time; opening a new one replaces it (never stack). |
| Modal | landscape max 920 × (viewport − 96), two columns above 720 wide; portrait full-width bottom sheet, max 92 % height | Footer is pinned. |

### 3.5 Density levels (Settings > Interface size)
| Level | Row | Text scale | Notes |
|-------|-----|------------|-------|
| Compact | 40 | 100 % (floor sizes in 5.1) | Pointer-first desktop only; touch targets stay 48 via hit-slop |
| Standard (default) | 48 | 100 % | |
| Large | 56 | 125 %, optional 150 % text-only | Layout reflows; nothing may clip. Dock labels default on. |

Text scale (100 / 125 / 150 %) is independent of density; at 150 % every screen must still reflow without horizontal scroll or clipped buttons (buttons grow in height before they truncate).

---

## 4. Colour System

### 4.1 Rules
- Two grounds: **paper** (documents) and **bar** (furniture). Every token has a value per ground; a semantic colour is never used on the wrong ground.
- Chromatic budget per panel: neutrals + brass + **at most two** semantic hues visible at once.
- Contrast targets (Comprehensive): body and caption text ≥ 4.5 : 1 everywhere (≥ 7 : 1 in High Contrast); large/bold text, icons, control boundaries, focus indicators and map markers ≥ 3 : 1. Ratios below are WCAG 2.x measured (script in Appendix A), not estimated.
- **Colour is never the only carrier**: each semantic colour has a glyph or shape (4.4).

### 4.2 Paper ground (documents). Backgrounds: `paper-0 #EFE3C6`, `paper-1 #E2D2AC`, `paper-2 #D3C095`
| Token | Hex | Role | On paper-0 | On paper-1 | On paper-2 |
|-------|-----|------|-----------:|-----------:|-----------:|
| `paper-0` | #EFE3C6 | Panel / sheet fill | n/a | n/a | n/a |
| `paper-1` | #E2D2AC | Control, inset, command-card fill | 1.17 (vs p0) | n/a | n/a |
| `paper-2` | #D3C095 | Pressed / selected row. Only ink-0, ink-1, oxblood text allowed on it | 1.4 | n/a | n/a |
| `ink-0` | #231A11 | Primary text | 13.42 | 11.45 | 9.57 |
| `ink-1` | #54442F | Secondary text, captions, units | 7.34 | 6.26 | 5.23 |
| `ink-off` | #7C6C4F | Disabled text and icons only (exempt from 4.5; ≥ 3 kept) | 4.00 | 3.41 | 2.85 |
| `oxblood` | #7A1D17 | Titles, key figures, selected underline | 8.17 | 6.97 | 5.83 |
| `brass-ink` | #735010 | Brass text on paper, "own" | 5.71 | 4.87 | 4.07 (non-text only) |
| `rule` | #7F6A46 | 1 px control borders (non-text, needs 3 : 1) | 4.06 | 3.47 | n/a |
| `hair` | #B9A57C | Hairline dividers (decorative; grouping also by space) | 1.89 | n/a | n/a |

### 4.3 Bar ground (furniture). Backgrounds: `bar-0 #120D09` (bar, dock), `bar-1 #231A12` (chip, plate), `bar-2 #33261A` (hover/pressed); map table `#060A14`
| Token | Hex | Role | On bar-0 | On bar-1 | On bar-2 |
|-------|-----|------|---------:|---------:|---------:|
| `cream` | #F3E9D2 | Primary text on bar | 16.00 | 14.17 | 12.14 |
| `smoke` | #C2B79F | Secondary text on bar | 9.72 | 8.61 | 7.38 |
| `brass-lt` | #F2C552 | Accent, own, active icon, orders (move) | 11.85 | 10.49 | 8.99 |
| `rule-dark` | #8A7340 | 1 px bar borders (non-text) | n/a | 3.75 | n/a |

### 4.4 Semantic colours, glyph backup, and measured contrast
Five hues carry eight meanings; the hostile and friendly hues are shared with a different glyph (so the palette stays small).

| Meaning | Paper hex | on p0 | on p1 | Bar hex | on bar-0 | on bar-1 | Shape / icon backup (mandatory) |
|---------|-----------|------:|------:|---------|---------:|---------:|----------------------------------|
| Positive | `pos` #0C6254 | 5.70 | 4.86 | #72D9C0 | 11.41 | 10.10 | ▲ triangle-up glyph and "+" sign |
| Negative | `neg` #9A2417 | 6.24 | 5.32 | #FF8A78 | 8.42 | 7.46 | ▼ triangle-down glyph and "−" (U+2212) sign |
| Warning | `warn` #7F4C00 | 5.61 | 4.78 | #F2B84B | 10.79 | 9.56 | Outlined **triangle with "!"**; as a chip, amber *fill* #F2B84B with ink-0 text (9.56 : 1) |
| Info | `info` #245785 | 5.93 | 5.06 | #7DB3E8 | 8.72 | 7.72 | Filled **circle with "i"** |
| War / hostile | = `neg` | | | = bar `neg` | | | **Crossed swords** glyph; hatched edge on map; text "War" |
| Ally / pact | = `info` | | | = bar `info` | | | **Linked-rings** glyph; double line on map; text "Ally" |
| Own | `brass-ink` #735010 | 5.71 | 4.87 | `brass-lt` #F2C552 | 11.85 | 10.49 | **Heavy 2 px outline** + brass bar; label bold. (Stars are reserved for generals, never for "own".) |
| Foreign / neutral | `foreign` #4F5662 | 5.80 | 4.95 | #A9B1BE | 8.94 | 7.92 | 1 px outline, no pip |

Rules: **warning amber is never plain text on paper alone** (it fails the deuteranopia test against negative, ΔE 5.1); it is a filled chip or carries the triangle. Sign (+/−) and glyph accompany every delta, so a red/green-blind player reads the same thing.

**Colour-blind verification** (Machado 2009 simulation at severity 1.0, CIE76 ΔE; ≥ 20 passes without backup, lower needs the backup above):
| Pair (paper) | Protan | Deutan | Tritan | Verdict |
|--------------|-------:|-------:|-------:|---------|
| pos vs neg | 25.6 | 42.2 | 93.5 | Pass (teal-green chosen over green on purpose) |
| pos vs warn | 37.9 | 47.3 | 61.6 | Pass |
| neg vs warn | 16.4 | **5.1** | 32.6 | **Needs backup**: triangle/fill rule above |
| info vs neg (ally vs war) | 57.3 | 74.1 | 92.4 | Pass |
| info vs foreign | 21.1 | 25.0 | 18.4 | Marginal under tritan: ally always has the link glyph |
| Bar: pos vs neg (#72D9C0 vs #FF8A78) | 22.7 | 34.3 | 97.4 | Pass |
| Bar: brass (own) vs info (ally) | 94.2 | 96.5 | 62.6 | Pass |
| Bar: brass vs warn | 4.1 | 2.9 | 7.0 | **Needs backup**: own is an outline + bar, warn is a triangle/fill; never adjacent without glyph |

### 4.5 Action colours and focus (measured)
| Element | Fill | Text | Ratio | Boundary |
|---------|------|------|------:|----------|
| Primary button | `brass` #D9A93C (hover #E6B94C, pressed #BF9230) | ink-0 | 7.90 / 9.30 / 6.00 | 1 px `brass-ink` #735010 (5.71 vs p0) |
| Danger button / End Turn wax | `wax` #8E1E16 (hover #A3281A, pressed #741710) | #FBF3E0 | 8.09 / 6.61 / 10.15 | 1 px #5B120D |
| Secondary button | `paper-1` | ink-0 | 11.45 | 1 px `rule` (3.47 vs p1; 4.06 vs p0) |
| Segmented selected cell | `ink-0` | cream | 14.17 | n/a |
| Toast / tooltip text | `bar-0` / `bar-1` | cream | 16.0 / 14.17 | 1 px `rule-dark` |
| Hover fill on paper rows/cards | #EADFBE | ink-0 / ink-1 | 12.87 / 7.04 | n/a |

**Focus ring (keyboard, switch access, future gamepad):** neutral and hue-independent, so it never collides with semantics. On paper: 2 px `ink-0` ring, 2 px gap, 1 px `paper-0` outside (ink-0 vs p0 = 13.42). On bar and map: 2 px `cream` ring (16.0 on bar-0, 16.4 on map navy) with a 1 px `bar-0` outer line. Ring is never clipped by the parent (draw in the parent's overflow or inset 2 px).

### 4.6 World palette and where UI diverges
- **Map table** `#060A14` (sea/background), graticule `cream` at 8 %. Land is desaturated in the political lens (nation fill L* 55–68, chroma ≤ 45) so ink and cream labels, gonfalons and arrows pop. The UI palette is **not** used for land; the only cross-over is brass for "own/selection".
- Wax red `#8E1E16` is used for exactly: End Turn seal, Danger buttons, game-over stamp. It does not mean "alert" (alerts use `neg` text/bars).
- **Lens ramp rule (new):** every sequential lens ramp must be monotonic in luminance so it survives colour blindness. Measured: Population 0.017→0.774 OK; Army 0.010→0.688 OK; Economy 0.017→0.861 OK; **Stability 0.093→0.319→0.580→0.414 fails** (last stop darker than the third). Replace with `[#7A1F1F, #C9632E, #E6C04A, #BDEBC4]` (L 0.052→0.742, deutan steps ΔE 35/26/50). Categorical lenses (governments, buildings, terrain) must be backed by a pattern or legend order; do not rely on hue to separate more than 5 classes.

### 4.7 High-contrast variant (Settings > Accessibility > High contrast; also auto-suggest when OS requests it)
Rules: no texture, no ragged edge, no corner guards, **no shadows** (replaced by a 2 px outline), borders 2 px, hairlines removed, semantic glyphs enlarged 1.25×, map halos 3 px.
| Token | Normal | High contrast | HC contrast |
|-------|--------|---------------|-------------|
| `paper-0` / `paper-1` | #EFE3C6 / #E2D2AC | #FFF9E8 / #F5E8C8 | n/a |
| `ink-0` / `ink-1` | #231A11 / #54442F | #0E0904 / #2B2013 | 18.85 / 15.14 on p0 (16.29 / 13.09 on p1) |
| `oxblood`, `rule` | #7A1D17, #7F6A46 | #5E100B, #3A2C1A | 12.84 / 12.84 (p0) |
| `pos`, `neg`, `warn`, `info`, `foreign` (paper) | see 4.4 | #0B5A33, #85100A, #6B3F00, #0F4A80, #3E4550 | 7.91, 9.62, 8.55, 8.64, 9.19 on p0 (≥ 6.84 on p1) |
| `bar-0` / `bar-1` | #120D09 / #231A12 | #000000 / #1A1109 | n/a |
| `cream`, `smoke`, `brass-lt` | see 4.3 | #FFFFFF, #E8DFC8, #FFD65A | 21.0, 15.82, 15.02 on #000 |
| bar `pos/neg/warn/info/foreign` | see 4.4 | #8DF0B4, #FF9D8C, #FFC95C, #8CC4FF, #C8D0DC | 15.26, 10.45, 13.76, 11.46, 13.51 |
| `rule-dark` | #8A7340 | #C9A445 | 7.87 on bar-1 |
| Primary button | #D9A93C / ink-0 | #FFD65A / #0E0904 | 14.17 |
| Danger button | #8E1E16 / #FBF3E0 | #85100A / #FFFFFF | 10.12 |

---

## 5. Units, Standards and Map Markers

Everything on the map is drawn in one Control `_draw` with cached polygons (section 8). Draw order: terrain/borders (shader) < labels < orders arrows < gonfalons < selection rings < HUD.

### 5.1 Army gonfalon (zoom-disclosed; numbers appear only when readable)
| Zoom tier | Marker | Size (screen px) | Shows |
|-----------|--------|------------------|-------|
| Far (globe overview; average province < 14 px) | Dot | 8 | Nation colour + 1 px ink ring. Only own armies, armies at war with you, and the selected one. No numbers. |
| Mid (province 14–40 px) | Pennant | 20 × 14, three strength sizes ×1 / ×1.2 / ×1.4 (< 20 / 20–99 / ≥ 100) | Nation colour band + outline-affiliation code. No number. |
| Near (province > 40 px) | **Gonfalon** | 36 × 30 (+ 4 px crossbar) | Number. |

**Gonfalon anatomy (Near):** 4 px `ink-0` crossbar; 32 × 26 body filled `paper-0`; 6 px **nation-colour band** along the top of the body; bottom edge a 6 px deep swallowtail (V notch); number in JetBrains Mono 700 14 px `ink-0` centred (13.42 : 1 always, because the number sits on paper, never on the nation colour; nation colours reach only 3.1–4.6 : 1 against ink or cream). Outline by affiliation:
| Affiliation | Outline | Pip (6 px, top-right) |
|-------------|---------|-----------------------|
| Own | 2 px `brass-lt` + 1 px ink outer | none (default) |
| Ally | double 1 px `info` line (2 px gap) | linked rings |
| At war with you | 2 px bar `neg` | crossed swords |
| Foreign / neutral | 1 px `ink-0` | none |
| Selected (any) | + 3 px `cream` ring with 1 px ink outer; lifts 4 px with the elevation-1 hard shadow | n/a |
| Has orders / moved | spent: nation band desaturated to grey; has unspent moves: 5 px brass dot at bottom-left | n/a |
Stacked armies in one province collapse to one gonfalon plus a "+n" tab (never overlapped gonfalons).

**Stars are exclusive to generals:** 1–3 brass `★` (8 px, brass-lt fill, 1 px ink outline) above the crossbar. **Capitals change from a star to a 10 px ring with a filled 6 px square** (so a star always means "general"). *(Needs the map-marker owner; see open questions.)*

### 5.2 Orders arrows (the "orders on the map" layer)
| Kind | Core | Head | Dash | Label chip |
|------|------|------|------|-----------|
| Move (committed) | 4 px `brass-lt` | filled triangle 12 long × 10 wide | solid | turns-to-arrive in Mono 700 12 on a 20 × 16 `paper-0` plate at the midpoint |
| Move (planning / preview, follows cursor) | 4 px `brass-lt` | same | dashed 8 on / 6 off; marching 24 px/s only when motion enabled | none until hover |
| Attack | 4 px bar `neg` | **double chevron** head 14 × 12 | solid when committed, dashed when preview | strength pair "119 : 32" |
| Casing (always) | 2 px #060A14 at 85 % on both sides | n/a | follows core | n/a |

Measured: brass-lt vs light land (#D8CBA0) is only 1.01 : 1, so **the casing carries legibility** (casing vs that land 12.2 : 1; brass-lt vs map navy 11.3 : 1). Never draw an arrow without casing. Attack differs from move by head shape and dash, not just hue. Maximum 1 preview arrow + committed arrows; a committed arrow fades 120 ms when its order resolves.

### 5.3 Targeting and on-map preview
- **Armed state** (player pressed Move/Attack or dragged from a gonfalon): valid targets: 2 px `brass-lt` outline + 12 % tint; invalid provinces dim to 40 %; a 4 px gonfalon ghost shows the share (25/50/75/100 %) at the cursor.
- **Order preview chip** anchors beside the target province (never bottom-centre): a `paper-0` plate (document), 260 px wide: verb + place (Alegreya 700 15); strength bar with own = `brass-ink` vs defender = `neg` and **both numbers printed** on the bar ends; outcome line with glyph (▲ "Victory, hold 87, lose 32" / ▼ "Defeat") in Alegreya 700 14; Cancel (secondary) and Attack (danger, left glyph swords). The 50 % mid-tick on the bar is the only decoration.
- Hover on map province (desktop) and long-press (touch): **map tooltip plate** (dark): owner flag, province name, army, one status chip. Never more than 4 lines.

### 5.4 Flags and nation chips
Flag chip 28 × 20 (square corners, 1 px `ink-0` outline) in lists; 24 × 16 in chips; nation colour square 12 × 12 for lens legends. Ruler portrait cameo leaves the top bar and lives in the Nation card.

---

## 6. Map and Terrain Visual Language

The map is rendered by a GPU shader (owner: technical-artist); this section gives parameters in **screen px** so borders do not thicken when zoomed.

### 6.1 Lenses
Ten lenses exist; **pin 4 for one-tap** (Political, Diplomatic, Military, Terrain), the rest in a "More" flyout. Lens strip sits with the dock (not in the top bar); active lens has the brass accent bar (3 px) and a filled icon. Switching = 180 ms cross-fade; the legend swaps with it.
| Lens | Fill | Legend |
|------|------|--------|
| Political (default) | Nation colours, desaturated; neutral land `#8A93A3` at 55 % | None |
| Diplomatic | Relation to you: self #46C36B, peace #8A93A3, war #D94A3A, pact #4AB8C1, ally #4A86D8, marriage #C46AD0; **plus pattern backup**: war = 45° hatch (2 px lines every 6 px), ally = solid + double border, pact = dotted border; relation never by hue alone | Swatch + pattern + word |
| Economic / Military / Population / Stability | Monotonic luminance ramp (4.6) | Gradient bar 12 px high, 3 ticks, "low/high" text ≥ 12 px |
| Governments / Buildings | Categorical; legend ordered by luminance; show building glyph on near zoom | Swatch + label grid |
| Terrain | Hypsometric tint, hillshade ≤ 20 %, no nation fills; nation borders kept at 1 px | Swatch + label |
| Wars (front) | Contested edges drawn 3 px `neg` with hatch | Swords pip + text |

### 6.2 Borders and selection (screen px)
Coast: 1.5 px #060A14 at 85 %. Nation border: **2 px** `ink-0` at 85 %. Province border: **1 px** `ink-0` at 35 %, fading out at Far zoom. Contested/war edge: 2 px bar `neg` with a 4 px dash pattern over the nation border. Hovered province: 2 px `brass-lt`. Selected province: 3 px `cream` + 1 px `ink-0` outside; fill brightened 8 %. No glow, no animation on selection (reduce-motion safe).

### 6.3 Labels
- **Nation names:** Cinzel 700, tracked +6 %, `cream`, size by nation screen extent (min 12, max 28), 2 px #060A14 halo at 85 % (3 px in High Contrast). Cream vs halo = 16.4 : 1, so it reads on any land tone.
- **Province names:** Alegreya 500, 12–14 px, `cream`, same halo; Near zoom only.
- **Capitals:** marker + name in Alegreya 700.
- Collision: nation > capital > province; skip, never overlap; labels avoid HUD rects (existing `keepouts()`); no curved text. Never place labels over an orders arrow head.
- Uzbek/Russian names are longer: allow two-line wrap of nation labels at ≤ 14 chars per line; if still colliding, drop to the first word.

### 6.4 Overlays and surfaces
Dark furniture on the map (legend, lens strip, alerts, toasts, tooltips); pale paper only for panels, order chips and modals. Sea: three deep-navy bands (#0B1A33 → #060A14), graticule 1 px cream at 8 %. No sepia filter, no map-edge vignette (it competes with the HUD plates).

---

## 7. UI/HUD Visual Direction

### 7.1 Screen anatomy (landscape; portrait notes in brackets)
```
[ top bar: flag+nation · date/turn · RESOURCE CHIPS ........ ]   [ALERT CHIP STACK (right, max 3 + "+n")]
[dock 56]                 THE MAP                        [context panel 360, replaces itself]
[toasts]      [order preview chip at target]                  [END TURN seal, bottom-right]
```
(Portrait: dock along bottom beside the seal; context panel becomes a bottom sheet; alert stack under the top bar.) Spatial rule: **status top, navigation left/bottom, context right, commit bottom-right**; the same positions on every screen.

### 7.2 Typography (embedded fonts only; sizes are logical px at Standard density, scaled by text scale)
| Role | Font / weight | Phone (portrait ≥ 540) | Desktop | Notes |
|------|---------------|------------------------|---------|-------|
| Wordmark (title screen only) | Cinzel 900 | 44 | 56 | One use |
| Panel / modal title | Cinzel 700 | 20 | 22 | Caps; ≤ 28 chars; `oxblood` on paper, `brass-lt` on bar |
| Nation name (top bar, map) | Cinzel 700 | 16 | 17 | Tracked +6 % |
| Body / list text | Alegreya 500 | **15** | **14** | Min for reading text; ink-0 |
| Emphasis / buttons / tabs / row names | Alegreya 700 | 15 | 15 | Sentence or title case, not caps |
| Consequence / detail line | Alegreya 500 | 13 | 13 | ink-1; floor for secondary text |
| Caption / unit / label | Alegreya 700, caps, tracked +6 % | 12 | 12 | **Absolute floor 12 at 100 %**; ≤ 14 chars; ink-1 |
| Figures (resources, costs, stats) | JetBrains Mono 700 | 16 | 16 | Tabular; right-aligned; ink-0 / cream |
| Delta under a figure | JetBrains Mono 400 | 12 | 12 | Always signed and glyph-prefixed (▲ +608 / ▼ −42) |
| Flavour / quotes / event body | Alegreya 400 italic | 15 | 15 | Ceremony sheets only |
| Tooltip / toast | Alegreya 500 | 14 | 14 | cream |

- **Number style:** Mono everywhere a number is compared; thousands: space-free abbreviation from 10 000 (`12.4k`, `1.2M`), full value in tooltip; true minus U+2212; signs and units always shown; do not set numbers in Cinzel.
- **Caps usage:** only Cinzel titles, and caption labels of ≤ 14 chars. Never caps for sentences, button labels, or any string that can exceed one line. Cyrillic: do not force uppercase on captions; use Alegreya 700 sentence case, no tracking.
- **Languages:** EN/RU/UZ strings run up to +35 %: buttons grow in height (never truncate verbs with "…"), figure columns have fixed width independent of caption length, captions on chips hide under 720 px width (icon + number remain). Cyrillic: Cinzel has no Cyrillic, so titles fall back to Alegreya SC Cyrillic 700; raise that fallback title +1 px to match Cinzel's apparent size. Uzbek Latin: use the Latin subset's modifier letter turn-comma (U+02BB) in o‘ / g‘ and U+02BC for tutuq; verify glyph presence before shipping (open question 5).
- **Line height** 1.25 for body, 1.1 for titles. Max line length in panels 40 characters (panels are narrow anyway), in event text 62.

### 7.3 Iconography grammar
- Grid **24 × 24**, live area 20 × 20 (2 px padding), snap strokes to the pixel; optical size ladder 16 / 20 / 24 / 32.
- Stroke by size: 16 → 1.5 px, 20 and 24 → 2 px, 32 → 2.5 px. **Square caps, mitre joins, 45° and 90° angles preferred**, corner chamfers match the UI cut (no round caps).
- **Outline = available/default; filled = active/selected/on.** Disabled = outline in `ink-off`/`smoke 40 %`. Do not change an icon's silhouette between states; only fill and colour.
- Single colour per icon. A semantic icon takes its semantic colour only when standalone (alert chips, deltas); inside buttons it takes the text colour.
- Core set exists (coin, men, swords, scroll, book, eye, flag, globe, scales, coins, trophy, lamp, save, gear, crown, skull, pin, flask, hourglass, chevrons, back, close, shield, dove, star). **Add**: triangle-up/down (deltas), warning (triangle "!"), info (circle "i"), link (ally), supply, revolt, lock (cannot afford/blocked), check, filter (lens), arrow-head, general-star (reserved), capital (ring + square).
- **Alert shape code** (priority order): ▲ filled red triangle = crisis (war, revolt); ▲ outlined amber = warning; ◆ brass diamond = offer/opportunity; ● blue circle = information/count. Priority also sorts the stack (crisis first).
- Dock icons are flat 24 px glyphs on a 40 × 40 square, **no medallion rings, no rim highlights**.

### 7.4 Motion rules
| Interaction | Duration | Easing | Notes |
|-------------|----------|--------|-------|
| Hover / press feedback | 80 / 60 ms | linear | Fill step only; no scale |
| Panel enter / exit | 160 / 120 ms | out-cubic / in-cubic | 12 px slide + fade from its edge |
| Modal enter / exit | 180 / 120 ms | out-cubic / in-cubic | Scrim fades; sheet rises 8 px; **no scale bounce** |
| Toast / alert chip enter / exit | 160 / 120 ms | out-cubic | Chip persists until handled; toast dwell = max(4 s, 40 ms per char) ≤ 8 s |
| Number roll | ≤ 400 ms | exponential ease-out | Then ▲/▼ glyph holds for 2 s (the flash is optional extra) |
| Lens switch | 180 ms | linear cross-fade | |
| Marching dashes (preview arrow) | continuous 24 px/s | linear | Only while a preview is active |
| End Turn resolving | sweep until done | linear | The one allowed continuous loop |

Rules: no overshoot, no bounce, no parallax on UI; nothing flashes more than 3 times per second (and attention pulses are ≤ 1 per 2 s, ≤ 3 cycles). **Reduce-motion** (Settings toggle; default from OS if readable): all tweens become instant state swaps or a 1-frame fade; marching dashes become static dashes; pulses become a static brass ring; number roll becomes an instant change with the ▲/▼ glyph; globe auto-spin off; seal sweep becomes a static "busy" ring with text. Information is never conveyed only by motion.

### 7.5 Component visual spec
**Global state rules** (apply to every control unless a row overrides):
| State | Rule |
|-------|------|
| Default | As specified below |
| Hover (pointer) | Fill steps one level lighter (paper: #EADFBE; bar: `bar-2`); text unchanged; 80 ms |
| Pressed | Fill one level darker (paper-2 / bar-2), content +1 px down, shadow removed |
| Disabled | Fill `paper-1` at 60 %, text/icon `ink-off`, no hover/press response; **a one-line reason is shown beneath or in the tooltip** ("Needs 3 diplomacy") |
| Focus | Focus ring from 4.5 (2 px ring + 2 px gap + 1 px contrast ring) |
| Selected | Filled indicator (bar or fill) **plus** a non-colour cue (filled icon, check, or underline) |

| Component | Fill / border / cut | Shadow | Text and content | Notes and overrides |
|-----------|---------------------|--------|------------------|---------------------|
| **Top bar** | `bar-0` at 94 %, flat. Bottom 1 px `rule-dark`. No texture, stitching, studs or gradient | Elev 0 | Flag 28 × 20; nation Cinzel 700 16 cream; date Mono 700 16 `brass-lt` with turn caption 12 `smoke`; then chips | Height 48 (phone 44). **Phone portrait shows 5 items max** (gold, manpower, moves, diplomacy, date); intel, provinces, tech, infamy move to the Nation ledger (tap nation name). Wraps to a second row never; overflow chip "⋯" opens the ledger. |
| **Resource chip** | `bar-1`, 2 px chamfer, 32 high, no border; 8 px side padding | Elev 0 | 20 px outline icon `brass-lt` · Mono 700 16 cream · optional signed delta Mono 12 in bar semantic colour with ▲/▼ | Gap 4 between chips (stacked-chips look). Hover/tap: `bar-2` + tooltip with breakdown. **Alert state** (e.g. negative income): 1 px bar `neg` border + ▼. Hit area 48 via slop. |
| **Alert chip** | `bar-1`, 2 px chamfer, 36 high, 4 px left bar in priority colour | Elev 0 | 20 px shape glyph (7.3) · Alegreya 700 14 cream, one line, ellipsis allowed (full text on tap) | Stack under the right side of the top bar, max 3 + "+n" chip; sorted by priority; handled alerts fade 120 ms. Tap: pan map to cause and open the relevant context panel. |
| **Dock / lens icon button** | Transparent on `bar-0` rail; 40 × 40 visual square, 4 px chamfer; 48 × 48 hit | Elev 0 | 24 px outline icon cream; label Alegreya 700 12 `smoke` beneath (default on at Large density and on first run; toggle in Settings) | Hover: `bar-2`. Active: `bar-2` + **3 px brass bar** on the rail-facing edge + **filled** brass-lt icon. Badge: 16 px circle (the count exception) top-right, glyph by alert shape code, number Mono 700 11. |
| **Primary button** | `brass` #D9A93C, 1 px `brass-ink`, 4 px chamfer; 44/48 high, min 96 wide, 16 px side padding | None | Alegreya 700 15 ink-0 (7.90 : 1) | **One per container.** Hover #E6B94C, pressed #BF9230. |
| **Secondary button** | `paper-1`, 1 px `rule`, 4 px chamfer | None | Alegreya 700 15 ink-0 | Default for everything that is not the single primary. |
| **Danger button** | `wax` #8E1E16, 1 px #5B120D, flat (no wax texture, no ring, no wobble) | None | Alegreya 700 15 #FBF3E0 (8.09 : 1) + 20 px glyph (swords / skull) at left | Declare war, attack, break pact. Irreversible actions add a confirm step. |
| **Panel (context)** | `paper-0` flat, 1 px `rule`, 6 px chamfer, 16 px padding. **No grain, no ragged edge, no corner guards, no double rule** | Elev 1 | Header 56: title Cinzel 700 20 oxblood + caption; close 48 hit at right; sections separated by a caption + space (no ornament rule) | 360 wide, replaces itself, never stacks. Structure: header, command cards, ledger rows, meters. |
| **Command card (order)** | `paper-1`, 1 px `rule`, 4 px chamfer; 56 high; left 32 × 32 glyph tile (outline icon, 2 px chamfer) | None | Title Alegreya 700 15 ink-0; consequence line Alegreya 500 13 ink-1 ("+15 men"); right: cost chip Mono 700 14 with 16 px coin glyph | Hover #EADFBE. **Armed** (map gesture started): 2 px `brass-ink` outline + brass 3 px left bar. Recommended action: brass 3 px left bar only. Unaffordable cost: `neg` text + lock glyph + reason. Verbs that are map gestures (Move, Attack, Recruit target) *arm* the map instead of acting. |
| **Tooltip** | `bar-0` at 96 %, 1 px `rule-dark`, 4 px chamfer | None | Title Alegreya 700 14 `brass-lt`; body Alegreya 500 14 cream; max 280 wide, max 4 lines | Desktop delay 350 ms; touch long-press 400 ms. **Never the only copy of information.** |
| **Toast** | `bar-0` at 96 %, 1 px `rule-dark`, 4 px chamfer, 4 px left bar by meaning; min 40 high, max 360 wide | Elev 0 | 20 px meaning glyph · Alegreya 500 14 cream, max 2 lines | Stack bottom-left beside dock, max 3. Tap to dismiss. Critical conditions are alert chips, not toasts. |
| **Modal (plain)** | `paper-0` flat, 1 px `rule`, 6 px chamfer, 24 padding. Settings, budget, lists, nation card | Elev 2 | Title bar (Cinzel 700 22 oxblood, close 48); scrolling body; **pinned footer**: primary right, secondary left | Scrim `#060A14` at 72 %. Two columns above 720 wide. |
| **Modal (hero sheet)** | `paper-0` + the one paper grain (±4 % luminance), ragged edge amplitude ≤ 1.5 px, double rule (1 px ink at 45 % + 0.5 px inset), 6 px brass corner guards | Elev 2 | Event body Alegreya 400i 15; choices are command cards | **Only event, ultimatum, treaty, era, game over, chronicle.** Max 1 per screen. Game over adds the wax stamp. |
| **List row** | Transparent; bottom 1 px `hair`; 48 high (40 Compact) | None | Name Alegreya 700 15 ink-0 left; figure Mono 700 14 ink-0 right (oxblood only for the key figure) | Hover `paper-1`. Selected `paper-2` + 3 px `oxblood` left bar + filled check. Focus ring inset 2 px. |
| **Tab / segmented** | Tab: transparent; 44 high; text Alegreya 700 15; inactive ink-1, active ink-0. Segmented: 4 equal cells, 1 px `rule`, 4 px chamfer | None | Active tab: **3 px `oxblood` underline, square ends (no notch)**. Segmented selected cell: `ink-0` fill + cream text (14.17 : 1) | Hover `paper-1`; pressed `paper-2`. Counts as badge Mono 12. Send-share 25/50/75/100 uses segmented. |
| **Slider** | Track 4 px `paper-1` with 1 px `rule` outline; filled part `ink-0`; thumb 24 px circle `brass` with 1 px `ink-0` (hit 48) | None | Value Mono 700 14 right; min/max Mono 12 `ink-1` | Ticks 1 px × 6 px at stops. Focus ring on thumb. Disabled: thumb `paper-1`, no fill. Keyboard step = tick. |
| **Meter** | Track 8 px `paper-1` + 1 px `rule`; fill 8 px semantic colour; threshold ticks at 30 and 50 only (the decision points) | None | Value Mono 700 14 always printed; low state (< 30) fill gets 45° hatch (2 px lines every 6 px) and ▼ | Colour thresholds: ≥ 50 `pos`, 30–49 `warn`, < 30 `neg`. Hatch + number mean colour is never required. |
| **End Turn seal** | The single wax hero: 80 px circle (72 portrait), `wax` + wax grain, 2 px `brass` ring. **Drop the 48-tick bezel and rim highlights** | Elev 2 | Chevrons glyph + Alegreya 700 12 caps caption `#FBF3E0` | Attention state (unresolved crisis alerts): static brass ring + diamond count badge. Busy: sweeping arc. Pulse only until first press (reduce-motion: static ring). Disabled: wax at 40 %. |

### 7.6 Decoration budget (the core rule set)
| # | Rule | Limit |
|---|------|-------|
| D1 | Paper grain / texture | Only the **hero sheet** and **End Turn wax**. None on controls, chips, cards, bars, panels, plain modals, tooltips. |
| D2 | Ragged / hand-cut edges | Only the hero sheet. Everything else is clean chamfer. |
| D3 | Ornament rule (— ◆ —) | **0** on panels, cards, toasts; **max 1** per hero sheet (under the title) and title screen. Groups are separated by a caption plus 16 px space, or one `hair` line. |
| D4 | Corner guards, studs, stitching | Hero sheet only (4 × 6 px). None on any element < 200 px wide. Leather stitching and bar studs are retired. |
| D5 | Double / inset border | Hero sheet only. Everything else is one 1 px border. |
| D6 | Shadows | One hard shadow per surface, levels 0–2 (3.3). No aged margins, no concentric strokes. |
| D7 | Wax | **One** wax object per screen: End Turn seal (or the game-over stamp). Danger buttons are flat. |
| D8 | Brass | **One** brass-filled element per container (the primary). Brass elsewhere is a 3 px bar, an icon tint or text. |
| D9 | Medallions, rings, rim highlights, glows, gradients | Banned in HUD. Only the lens/legend ramps and the map shader may use gradients. |
| D10 | Icon + caption + number + delta in one control | At most 3 of the 4 (icon, number, delta, and a caption only if width allows). |
| D11 | Chromatic hues per panel | Neutrals + brass + at most 2 semantic hues. |
| D12 | Draw primitives per decorated element | Chip/button ≤ 4, panel ≤ 12, hero sheet ≤ 40. |

Per-screen allowances at a glance:
| Screen | Hero sheet | Wax | Ornament rule | Texture | Brass-filled |
|--------|-----------:|----:|--------------:|--------:|-------------:|
| Map HUD (default) | 0 | 1 (seal) | 0 | seal only | 0 |
| Map + province panel | 0 | 1 | 0 | seal only | ≤ 1 |
| Plain modal (settings, budget, nations) | 0 | 1 (seal under scrim) | 0 | seal only | 1 |
| Ceremony (event, ultimatum, game over) | 1 | 1 (seal / stamp) | 1 | sheet + seal | 1 |
| Title / menu | 0 | 0 | 1 | 0 | 0 |

**Migration from the current build** (what to retire, keep, change):
| Current | Decision |
|---------|----------|
| `TBFrame` SHEET on every panel (ragged edge, 3-layer shadow, aged margins, double rule, corner guards) | Split: new flat **PLATE** (panels, plain modals) + **SHEET** kept for hero only |
| `TBFrame` CHIT ragged + textured on every button/toast/tooltip | Replace with flat chamfered PLATE; buttons drop texture and ragged edge |
| `TBFrame` LEATHER with studs/stitching on top bar | Replace with flat `bar-0`; drop leather texture (also saves a 256 × 256 texture) |
| `TBFrame` WAX on buttons | Keep only for End Turn; Danger = flat oxblood |
| Dock medallion (rings, rim highlight, caption outline) | Flat 40 square icon button with brass active bar |
| Seal 48-tick bezel | Single brass ring |
| `OrnamentRule` on panel headers and modals | Remove from panels; keep one on hero sheets |
| Mono 10 px caps captions | Alegreya 700 12 px caps |
| Controls drawn with 0.7–0.9 px strokes | Whole-pixel strokes |
| Slider bead image per colour (`bead_tex`) | `draw_circle` thumb, no Image |
| Province panel with long list of equal buttons | Command cards (title + consequence + cost), map gestures arm the map |
| Top bar of 10 readouts with ruler cameo | 5 chips (phone) / 7 (desktop); rest in Nation ledger |

---

## 8. Asset Standards

Everything is procedural; there are no image assets. "Assets" means tokens, StyleBox kinds, glyph definitions, procedural textures and fonts.

### 8.1 Files and naming
- One token source: `ui_tokens.gd` (class `TBTokens`): `const` colours named `PAPER_0`, `INK_0`, `BAR_1`, `POS`, `NEG`, ... plus a `HC` dictionary with the same keys (4.7). `TBTokens.mode` switches Normal/HC; **no raw `Color(...)` literals in `src/ui/`** (lint by grep).
- StyleBox kinds (in `frame.gd`): `PLATE` (flat chamfer; params: fill, border, cut, elevation), `SHEET` (hero), `BAR`, `SEAL`. Glyph ids snake_case (`warning`, `link`); `TBGlyph` is the only icon source; stroke and size ladder from 7.3.
- Component scripts keep `TB` prefix; states are an enum (`DEFAULT, HOVER, PRESSED, DISABLED, FOCUS`), not ad-hoc booleans.

### 8.2 Textures and fonts
| Item | Standard |
|------|----------|
| Procedural textures | **Two only**: paper (256² simple-noise FBM + grain) and wax (256²). Both generated once, lazily on first use of a hero sheet / seal, cached. Leather texture removed. Total UI texture memory ≤ 1 MB (current plan 2 × 256 KB). Generation ≤ 150 ms desktop / ≤ 400 ms low-end Android; may run on a thread behind the first frame. |
| Texture use | Textured polygons: UVs 1 texel = 1 px, repeat on, only on hero sheet and seal. Never stretch the grain. |
| Fonts | Load once, cached in a static dictionary (as today). Faces in use: Cinzel 700 and 900 (wordmark only), Alegreya 400i / 500 / 700 (+ Cyrillic 400i / 500 / 700), Alegreya SC Cyrillic 700 (title fallback), JetBrains Mono 400 / 700 (+ Cyrillic). Drop Cinzel 500 from use. `FontVariation` for tracking is created **once per (font, spacing)**, not per call. |
| Glyphs / icons | Pure `draw_*` primitives from `TBGlyph`; ≤ 12 line segments per icon; no per-icon textures. |

### 8.3 Render and performance limits (Godot 4.4, GL Compatibility)
| Metric | Limit |
|--------|-------|
| Frame budget (UI only) | ≤ 2 ms desktop 1080p; ≤ 4 ms low-end Android (2 GB RAM) at 30 fps floor, 60 fps target |
| Steady-state HUD canvas draw calls | ≤ 40 (batched), of which textured polygons ≤ 3 (seal + at most one open hero sheet) |
| Primitives | Chip/button ≤ 4; panel ≤ 12; hero sheet ≤ 40 (matches D12) |
| Control nodes | HUD ≤ 150; any modal ≤ 300; lists > 30 rows use pooled rows or pagination |
| Map markers | ≤ 400 gonfalons per frame, drawn from **one** `_draw` with cached polygons; Far zoom culls to ≤ 60; arrows ≤ 3 draw calls each (casing, core, head) |
| Redraw policy | `queue_redraw()` on state change only. Allowed per-frame redraw: seal busy/pulse, rolling numbers, marching dashes, and only while visible and motion is enabled |
| Allocations | **No per-frame allocations** in `_process` / `_draw` of always-visible controls: no `PackedVector2Array`/`Array` literals, no `%` string formatting, no `Color(...)` construction, no `ragged()` calls. Cache polygons keyed by rect size at `resized`; format strings only on value change. |
| Shaders | None in the UI layer (the map shader is separate). No `BackBufferCopy`, no blur/glow, no `CanvasGroup`, no SubViewport for UI effects. Alpha lives in the colour, not `modulate` on large containers. |
| Pixel crispness | Axis-aligned rects/lines on whole pixels (+0.5 for 1 px lines); antialiased polylines only for diagonals and circles. No sub-pixel stroke widths. |
| Scaling | Stretch mode `canvas_items`, base 1280 × 720 expand, text scale 100/125/150 %, safe-area insets honoured on phones. |

### 8.4 Art-vs-technical trade-offs recorded
| Art preference | Technical limit | Chosen |
|----------------|-----------------|--------|
| Paper grain and hand-cut edges on every surface | Per-surface textured polygons + per-draw polygon allocation break batching on low-end GL Compat | Hero sheet and seal only |
| Individual wax-stamp buttons | Textured wobble polygons per button | Flat danger button; one wax seal |
| Image-based slider beads and engraved bezels | No image assets; Image creation per colour | Vector thumb and ring |
| Rich shadows | Multi-pass alpha polygons | One hard shadow per surface |

### 8.5 Validation
Screenshot matrix before merge of any UI change: 540 × 960, 1080 × 2340 (scaled to 2340 × 1080 landscape), 1280 × 720, 1920 × 1080; Standard and Large; EN / RU / UZ; Normal and High contrast; plus a greyscale and deuteranopia pass of the top bar, province panel, an alert stack and the diplomatic lens. Contrast script (Appendix A) must pass in CI against `TBTokens`.

---

## 9. Reference Direction

| Reference | Take (specific) | Avoid |
|-----------|-----------------|-------|
| **Hearts of Iron IV** (campaign UI) | Stacked resource chips in one bar; strong functional grouping; orders as arrows on the map; the alert strip sorted by priority | Icon soup, grey-on-grey text at 10 px, 20+ always-visible figures |
| **Total War** (campaign map, Rome II / Three Kingdoms) | Army banners on the map with strength; command cards that state cost and consequence; clear disabled reasons | Ornate frames, 3D bevels, skeuomorphic scrollbars; hiding verbs three screens deep |
| **NATO APP-6 / staff-map symbology** | Affiliation encoded by frame shape and outline weight; strength as a printed number; hostile/friendly beyond hue | Copying APP-6 icons literally (we use gonfalons and our own glyphs) |
| **Engraved atlas cartography** (e.g. Bartholomew, 19th-c. world atlases) | Label hierarchy by size and tracking; thin graticule; restrained halos | Sepia filter, torn-paper edges, map-edge vignette |
| **Mini Metro / Into the Breach** (flat tactical UIs) | Shape-redundant coding, extreme restraint, a single accent for the thing you can act on | Pure minimalism with no material identity; we keep paper, ink and brass |

---

## Open questions (genuine)
1. **Phone top bar chip set.** Which 5 chips stay on a 540 px portrait bar (proposal: gold, manpower, moves, diplomacy, date)? Needs ux-designer sign-off with play-test data.
2. **Dock labels.** Default-on labels (proposed) use space; do players of this genre prefer icon-only with long-press? Test at Standard density.
3. **Capital marker change** (star to ring+square) touches the map render and data owners.
4. **OS settings readout.** Can we read Android/iOS reduce-motion and font-scale in Godot 4.4 without a plugin? Otherwise they are manual toggles only.
5. **Uzbek apostrophe glyphs.** Confirm U+02BB / U+02BC exist in the embedded Alegreya and Cinzel Latin subsets; if not, fall back to U+2018/U+2019 and note it.
6. **Colour-blind nation palettes.** Do we generate a CVD-optimised nation palette variant (shader palette swap), or rely on borders, labels and flags?
7. **Screen-reader support.** Comprehensive tier implies it; Godot 4.4 has no AccessKit integration (arrives in later 4.x). Art-bible provides accessible names only; engine support is a producer decision.
8. **Pillar trade-off (flag for creative-director).** Pillar 2 says verbs live on the map; the province panel still hosts command cards that *arm* map gestures and confirm. We kept the panel as an explainer/confirmer; if the creative-director wants zero panel verbs, move recruit/build to a radial/long-press menu.

---

## Appendix A: contrast script (WCAG 2.x relative luminance)
```python
def lin(c): return c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4
def lum(h):
    r,g,b = (int(h.lstrip('#')[i:i+2],16)/255 for i in (0,2,4))
    return 0.2126*lin(r)+0.7152*lin(g)+0.0722*lin(b)
def ratio(a,b):
    la,lb = sorted((lum(a),lum(b)), reverse=True)
    return (la+0.05)/(lb+0.05)
# examples measured above: ratio('#231A11','#EFE3C6') = 13.42 ; ratio('#0C6254','#E2D2AC') = 4.86
# CVD: Machado 2009 matrices (severity 1.0) on linear RGB, then CIE76 dE in Lab (D65).
```
