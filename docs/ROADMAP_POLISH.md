# Roadmap: atmosphere, animation and pop-ups

Status: **Path G and the title screen (A1, A2, A5 in part) are built; see section 6. The rest is still a plan.** Written after looking at the game as it is (screenshots in `docs/screens/polish_baseline/`).
The rule for every step below: **a step ships only when its tests pass, its picture is checked against the mock-up, and the game still plays exactly as before with the effect switched off.**

## 1. Where the game stands

| area | what is there | what is missing |
|---|---|---|
| In-game interface | Bezel look, ported from the demo and tested for parity (HUD, rail, panels, modals, notices, tooltips) | it is silent and still: windows fade in (0.16-0.22 s) and that is nearly all the motion the interface has (13 tweens in total) |
| Title screen (`main.gd show_menu`, `menu_parts.gd`) | the globe inside a turning ring, a wordmark, four text rows, a tools row | it uses the *older* look (bright yellow, flat text), not the Bezel look of the game; nothing says "grand strategy"; menu rows are plain text; no music; the globe floats in a void |
| Journey into a game | title -> era list -> nation pick on a flat map -> briefing -> game | every hop is a hard cut; the nation pick is a different, plainer screen than the title; the era list is a text list |
| Pop-ups | events, war confirm, battle report, ultimatum, treaty terms, game over; good structure and wording | they appear all at once; no staging, no sense of weight (a declaration of war looks like a settings dialog); outcomes are shown as chips only |
| Map feedback | markers fade and pop, hover and selection fade, routes draw themselves in, march dashes, attack / capture rings | armies jump instead of travelling; a conquered province changes colour in one frame; nothing marks the turn passing; no sea, cloud or light life; battles are a ring and a number |
| Sound | a dozen synthesised cues (tap, coin, alert, war, win, turn, event); buses exist (Music / SFX / UI) | **no music at all** ("the score that does not exist yet"); no ambience; few cues for the things that matter (a province falling, a treaty signed, a turn ending) |
| Flavour | 13 eras, 250+ nations, events, rulers | no era mood; leader portraits and flags exist only for some eras; no loading tips |

## 2. Principles and guard rails (how we do not mess up)

1. **Parity stays.** The Bezel demo is the spec for the in-game interface. A change that the demo does not have goes behind a flag and is shown to you as a picture first. `tools/parity.sh` must still score the same on the states that exist.
2. **Untouchable:** the End Turn dial (drawing and behaviour), the circle-border thinness rule, notched plates, the engine, saves, multiplayer protocol. Animation never changes game state.
3. **Mock-ups first.** For every visible change: 3-4 pictures (HTML demo shot or Godot screenshot), you pick, then it is built. No code for a look you have not seen.
4. **Motion budget.** A still screen must still draw **zero** frames (`tests/perf_idle.gd` already gates this). Every effect has a start and an end; ambient motion (sea shimmer, drifting light) is optional, off on the low tier, and off with "Reduce motion". The HUD bitmap cache (`bake.gd`) already steps aside for anything that animates.
5. **One switch.** A single setting "Effects: Off / Light / Full" (default by hardware tier, like the map quality) plus the existing Reduce-motion; every effect asks `K.motion_ok()` first. "Off" must be pixel-identical to today.
6. **Small, reversible commits**, one idea each, tests run, pushed. A path can be stopped after any step without leaving the game half-changed.
7. **Cheap on a weak laptop:** effects are canvas draws and short tweens, not new shaders over the whole map, unless a step says so and the sandbox bench shows the cost.

## 3. The paths

Each path is independent; the order in section 4 is a suggestion. "Mock" = what I show you first. "Checks" = how I know it did not break anything.

### Path A - The title screen and the way into a game ("atmosphere")
Goal: the first ten seconds should say *"a chronicle of empires"*, in the same Bezel language as the game.
* **A1 Title scene.** Keep the globe in its ring (you said it is fine) but give it a world: a deep star field with slow parallax, a terminator (day / night edge) crossing the globe so it is lit from one side, a faint atmosphere rim, drifting brass dust, a vignette. The ring gets Bezel engraving (ticks, a compass crown, a slow sweep hand). The wordmark becomes engraved brass (Cinzel, a light glint passing along it every ~12 s). Mock: 3 compositions.
* **A2 Menu as plates.** Rows become Bezel notched plates (the game's own button kit): *Continue* shows the save as a small card (flag, nation, year, turn), *New game*, *Load*, *Multiplayer*; hover = brass edge + glint, press = inset; the focused row is clearly marked for keyboard and gamepad; the tools row gets the Bezel medallions. Entering a sub-screen slides the plates away instead of cutting.
* **A3 Era picker as a timeline.** A horizontal strip of 13 era cards (date, name, mood colour, three signature flags, a tiny globe snapshot of that world) instead of a text list; the right side keeps difficulty / players. Selecting an era turns the background globe to a place typical of that era.
* **A4 Nation pick.** Same plates and typography as the game (today it is a plainer screen); hover on the map lights the nation with the game's own highlight and shows a small card (flag, ruler, rank, difficulty); the bottom strip of powers keeps working.
* **A5 The dive.** "Begin" plays the camera move from the teaser (globe -> country) as the transition into the game, then the HUD fades in and the briefing opens. Skippable with any key; instant when Reduce motion is on.
* **A6 Music + ambience for the title** (see Path E).
Checks: `ui_menu`, `ui_pick`, `ui_look`, overflow tests at the four sizes and three languages, phone-landscape screenshot, keyboard walkthrough (`ui_monkey`), idle-frame gate on the title (the ring may animate; it already does).

### Path B - Pop-ups and dialogs with weight
Goal: moments that matter *feel* like moments, without slowing the player down.
* **B1 Common choreography** in `TBPanel` (one place, every dialog gains it): the veil dims the map over 0.2 s, the card rises and settles, content blocks reveal in sequence (header, text, chips, choices) over ~0.25 s total, buttons get hover / press micro-motion, closing is the reverse and faster. Never blocks input; any click completes it.
* **B2 Event pop-up** gets a header illustration slot (a brass engraving glyph per event class: plague, court, rebellion, trade, discovery...), choices that preview their effect chips with up / down arrows, and a soft stinger.
* **B3 War declaration** is a ceremony, not a form: the hold-to-confirm button fills like a seal, the two flags face each other, the card tints rust; on confirm a short "ink stamp" and the map pans to the front.
* **B4 Battle report** animates: both armies' bars drain, casualties count down, the winner's flag rises; the same on the map with the clash marker (Path C).
* **B5 Treaty / pact / trade accepted** show a signing moment (two seals meeting) and a notice; refusals are quiet.
* **B6 Turn summary** ("what happened while you waited"): a compact sheet after End Turn, only when something happened, rows that are tappable to go to the place.
* **B7 Game over** (victory / defeat): a full-screen finale with the realm's final statistics counting up and the chronicle scrolling; "play on" / "main menu".
* **B8 Tooltips and toasts**: consistent delay, fade, and edge-aware placement; toasts stack and slide.
Mock: B3 and B7 first (the biggest change); B1 is mostly timing so it is shown as a short video, like the teaser.
Checks: `ui_modals`, `ui_bezel_events`, `ui_bezel_screens`, `ui_overflow`, the bitmap-cache test (`bake.gd`), reduced-motion path.

### Path C - The map comes alive
Goal: what happens on the map is visible and satisfying, at no cost while nothing happens.
* **C1 Armies travel.** A marker glides along its route instead of jumping (the standing orders already know the path), with a short dust trail; in the Routes lens nothing moves.
* **C2 Conquest.** A province that changes hands recolours with a sweep from the point of conflict (a ring of new colour spreading over ~0.4 s) instead of one frame; capital capture gets a flare.
* **C3 Battle.** A clash marker (crossed swords glyph, a flash, a small shake of the pill, damage numbers) where the fight is, in addition to today's attack arrow.
* **C4 Turn passing.** A thin light terminator sweeps across the globe during End Turn, the date flips (the date *text*, not the End Turn dial), and gauge numbers count to their new value with a delta pop.
* **C5 Ambient (optional, Full only):** a slow shimmer on open sea, a few clouds drifting over the globe, city glints on capitals; implemented as one extra pass behind a quality tier, only drawn while the map is already redrawing for another reason (so a still screen stays free).
* **C6 Selection and hover polish:** a soft pulse on the selected province, the nation outline "breathing" once when you pick a country.
Mock: C2 and C4 (before / after pictures plus a short video). Perf: sandbox bench per effect, gate "idle frames == 0".
Checks: `map_partial`, `perf_idle`, `bake`, `label_shots`-style before / after with effects off = identical.

### Path D - HUD micro-interactions
Goal: the interface answers every touch.
* **D1** Gauges: value count-up, delta pop (+12 flies up and fades), low-treasury pulse.
* **D2** Rail tabs and medallions: hover glint, press inset, the tab that is open stays lit; tab switch has a short slide (the toggle behaviour is already in).
* **D3** Notices: the alert ticker slides in, countdown flags tick (the 7 s expiry already exists), a notice that turns critical shakes once.
* **D4** Lens bar: the red pointer glides between lenses; legend fades.
* **D5** Command ring: verbs fan out from the centre instead of appearing.
Constraint: the End Turn dial itself is not touched; things around it may animate. The HUD bitmap cache automatically goes live while a piece animates and caches again when it is still.
Checks: `ui_hud_layout`, `ui_bezel`, `ui_cmdcard`, parity.

### Path E - Sound and music
Goal: the game has a voice. All synthesised or generated here (no third-party files, no licences).
* **E1 Music bus alive:** a slow generated score per mood (title, peace, war, victory, defeat), cross-fading; era-flavoured instrumentation (plucked / bowed / brass pad, hand drums for the ancient and mongol worlds, brass swells for the Napoleonic, a cold pulse for the Cold War). Generated offline into small `.ogg` files (a few MB) with a script in `tools/`, or synthesised at start-up if the size matters.
* **E2 Ambience:** wind over the globe on the title; sea / crowd murmur at close zoom (optional).
* **E3 Cue set:** ~20 more cues: province lost / won, treaty signed, war declared, building finished, gold low, event arrives, notice appears, hold-to-confirm fill, page turn for Annals.
* **E4 Mix and settings:** the three sliders already exist; add "ducking" (music lowers under pop-ups) and a mute-on-focus-loss.
Checks: `audio.gd` test, volume-slider test, no clipping (the limiter exists), file size budget.

### Path F - Flavour and content that carries the mood
* **F1 Era mood:** each era gets an accent tint for the title backdrop, loading screen and chronicle headers (the in-game palette stays the Bezel palette).
* **F2 Loading / transition tips:** one line of flavour or a rule hint on every big transition.
* **F3 Leader portraits and flags** beyond the three eras that have them (the open items in the notes); engraved-style portraits generated in one consistent treatment.
* **F4 Event art:** the engraving glyph set for events (shared with B2).
* **F5 Codex polish:** entries get an engraving each; the tutorial gets a short animated pointer.

### Path G - Foundation for all of the above (do first)
* **G1 `TBFx` helper:** one tiny module for "run this effect if motion is allowed, with this duration and easing, cancel on skip", so every step uses the same rules (and Reduce motion / the effects switch work in one place).
* **G2 Effects setting** (Off / Light / Full) in Settings, default from the hardware tier; documented in the diagnostics line.
* **G3 Test harness:** `tests/fx_still.gd` (a still screen draws no frames with effects on), screenshot "effects off equals today" comparison, and a short-video recorder (the teaser recorder) so every animation can be shown to you before it is accepted.
* **G4 Mock-up workflow:** the HTML demo gains `b_title.html` / `b_modals_fx.html` style mock-ups (pictures only, new file names, as agreed).

## 4. Suggested order

| phase | content | why this order | size |
|---|---|---|---|
| 0 | Path G (helper, switch, harness) | everything else depends on it; zero visible change | small |
| 1 | Path A1 + A2 (+ E1 title music) with mock-ups first | the first thing a player sees; isolated from the in-game parity work, so low risk | medium |
| 2 | Path B1 + B3 + B7 | the biggest "weight" gain for the least code (one common choreography) | medium |
| 3 | Path C2 + C4 + C1 | makes turns visible; needs the perf bench | medium |
| 4 | Path A3 - A5 | era timeline and the dive, once the title is settled | medium |
| 5 | Path D, rest of B, rest of C, E2-E4 | polish pass | many small steps |
| 6 | Path F | content-heavy; can run beside anything | open-ended |

After each phase: full headless suite + UI suite, parity scores unchanged, a short video of the new motion for you, one commit per step, pushed.

## 5. What I need from you
1. The order: start with phase 0 and 1 (title + menu), or another path first?
2. Title direction: keep the ring-and-globe composition (my recommendation) or something different (a flat atlas table, a map on a desk)?
3. Effects default: on for everyone with an off switch (recommended), or off by default?
4. Music taste: tell me 2-3 words per era mood if you have a preference; otherwise I propose cues and you choose from samples.

## 6. Progress log

### Built: Path G foundation + the new title screen (layout B "Orrery", button style 4)
* `src/ui/fx.gd` (`TBFx`): one place that decides whether an effect may run. Setting **Effects: Off / Light / Full** (Settings -> Display, saved as `cfg["fx"]`; a new install starts on Light when the map tier starts at low, otherwise Full; shown in the diagnostics line). Reduce motion still wins over everything. Off = the screen is exactly what it was before the effect existed: the selection bracket jumps, Continue is a plain load, stars do not drift.
* `tests/fx_still.gd` (in `tools/test_ui.sh`): a held title draws **zero** frames and looks identical pixel for pixel with Off, Light and Full; with Off the bracket jumps.
* Title (`src/ui/title_parts.gd`, `main.gd show_menu`): Bezel palette and dark land; stars, atmosphere rim, the brass ring with the **thirteen era years** (the save's era at the top); wordmark in two lines; the **Continue card** (flag, nation, turn, year) with quiet rows below; **one selection bracket** that glides to the focused entry (hover, arrows, controller) and flashes on press; your **campaign card** on the right (flag, nation, ruler, turn, year and era); the graticule is faint on the title (`grid_k` shader uniform, 1.0 in a game). Portrait, phone and 4:3 windows keep the compact composition (everything inside the ring) with the same parts.
* New save meta (`code`, `color`, `rk`, `rn`, `rnum`) so the title can show the flag and the ruler; old saves still load and show a globe glyph instead of the flag.
* **The dive**: Continue dissolves the menu, the ring opens and fades, the globe turns to your capital and swells; at the end a still of that frame is held while the game is built underneath, the still dissolves and the interface fades in. Any key or click skips. Light: the menu and ring dissolve and the still dissolves (no camera dive). Off: a plain load. Recorded by `tools/title_dive.sh [outdir] [flat|globe] [off|light|full]` (movie writer + ffmpeg).
* Not done yet from section 3: terminator and drifting dust on the globe, the wordmark glint, chronicle quotes under the campaign card, music, the era picker as a timeline (A3), nation pick (A4).
