# Polish tracker: what changed, before / after, what is next

**Read this first in every new session.** It is the single place that says where the polish work stands, what each step changed (with before / after pictures),
how to run the checks, and what is queued. `docs/ROADMAP_POLISH.md` has the long-form reasoning and mock-up descriptions; this file is the working log.
Keep it current: every step that ships adds a row to section 3 and a block to section 4 in the same commit.

---------------------------------------------------------------------------------------------------------------------------------------------------

## 0. How to edit this file (for the owner)

* **Change a decision**: edit section 1 (Decisions) or the "Notes for next step" line of a queued step in section 5. The next session reads those first and follows them.
* **Reorder / drop / add a step**: edit the table in section 5 (the top `queued` row is what gets built next). Put `DROP` in the status to cancel one.
* **Comment on a picture**: add a line under the step's block in section 4 starting with `OWNER:`; it is treated as a bug report / change request.
* Do not rename step ids (B1, B3 ...); the commits and pictures refer to them.

## 1. Standing rules and decisions

User rules (from the conversation, unchanged unless edited here):
1. Mock-ups / demos are **new file names, pictures only** (no working HTML needed for review). Show a mock-up before building any new look; small tweaks to something already approved need none.
2. Do the work myself; do not wait for permission when told to continue. "Do not mess up": plan first, flags / off switch, parity and tests stay green.
3. Circle borders stay thin except the End Turn dial; **the End Turn dial never changes**.
4. The game must match the Bezel demo where a demo exists (`tools/parity.sh`, `tests/parity.gd`, `node docs/ui_variants/build.mjs`).
5. Run **one test job at a time** (software GL is slow and parallel runs corrupt each other). Godot runs with `XDG_DATA_HOME=/tmp/xdg_m`.
6. Token lint: no raw `Color(...)` literals outside `ui_tokens.gd`. After adding a `class_name` file run `godot --headless --path godot --import`.
7. Commit and push to `claude/ecstatic-gauss-f495v8` only (`git push -q -u origin claude/ecstatic-gauss-f495v8`), never open a PR. Commit trailers:
   `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_013T5AD1pNZct2zWo57gXC64`.

Decisions taken on the owner's behalf while they were away (edit freely):
| # | decision | why |
|---|---|---|
| D1 | Effects default = **Full** (Light on a machine whose map tier starts at low), with the Off / Light / Full switch in Settings -> Display | recommended in the roadmap; Off is pixel-identical to the old behaviour |
| D2 | Title globe palette = **dark Bezel** (not the old bright one) | matches layout B mock the owner approved |
| D3 | Continue save card = **yes** (flag, nation, ruler, turn, year, era) | built |
| D4 | Music taste unknown -> E1 proposes **three sample cues** the owner picks from; until then no music is shipped | avoids imposing a style |
| D5 | Staging time for every dialog = **0.32 s**, close **0.15 s**, any click completes it | roadmap B1 |
| D6 | War declaration keeps the existing **hold-to-confirm** rule (hold time unchanged) and only changes its look; no new confirmation steps | gameplay unchanged |
| D7 | Finale shows **counted-up stats + milestones from the chronicle**; the existing game-over data (`TBModals.game_over`) is the source, nothing new is stored | no save-format change |
| D8 | Turn summary is **non-blocking**, off when nothing happened, and can be turned off in Settings (Effects Off hides the animation only) | avoid noise |
| D9 | Flags that exist only as generated placeholders (e.g. Prussia in the mocks) stay placeholders | content task F3 |

## 2. How to resume (checklist for a fresh session)

```
cd /home/user/fuzzy-journey && git status -sb && git log --oneline | head -5      # branch claude/ecstatic-gauss-f495v8
export XDG_DATA_HOME=/tmp/xdg_m
/opt/godot/Godot_v4.4.1-stable_linux.x86_64 --headless --path godot --import       # after any new class_name file
tools/test_ui.sh                       # UI suite under xvfb (~35 min in the sandbox, run alone). Ends with "UI PASS"
tools/test_all.sh                      # headless suites (engine, sim, net)
godot/tests/title_shots.gd             # -- <out> <w> <h> <save|nosave> [lang]   title stills   (TB_TS=1.5 for text size)
tools/title_dive.sh [out] [flat|globe] [off|light|full]                            # records the Continue dive (mp4 + gif)
node docs/ui_variants/build.mjs && node docs/ui_variants/shoot_popups.mjs /tmp/pb/pop   # pop-up mock-ups
```
Pitfalls learnt:
* `/tmp/xdg_m/settings.cfg` is written by tests (the overflow test leaves **text_scale 1.5** and a language behind): a screenshot script must set `cfg["text_scale"] = 1.0` itself (title_shots does).
* A scratch `tests/_*.gd` must never be committed (check `git status` before every commit).
* `pkill -f <pattern>` can kill your own shell; do not use it. Long jobs: run in the background and poll with short bounded loops (`for i in $(seq 1 55); do ... sleep 2; done`).
* Lambdas that capture nodes freed later (`_clear_overlay` frees the title) print "Lambda capture ... was freed": read the node from a member variable inside the lambda and guard with `is_instance_valid`.
* A push can race a background push of the same branch (`cannot lock ref`): check `git rev-parse HEAD origin/<branch>` after a push that printed an error.
* `TB_NOANIM=1` makes `TBKit.motion_ok()` false (tests that need still pictures); `TB_NOANIM=` (empty) enables animation.

## 3. Status board

Legend: `done` = built, tested, pushed. `mock` = approved mock-up exists, not built. `queued` = planned, no mock needed or mock to be made first.

| id | step | status | commit | flag / off behaviour | tests |
|---|---|---|---|---|---|
| G1 | `TBFx` helper (`src/ui/fx.gd`) | done | 657d14c | `cfg["fx"]` off / light / full | fx_still |
| G2 | Effects setting (Settings -> Display), diagnostics line | done | 657d14c | default Full / Light on low tier | fx_still |
| G3 | `tests/fx_still.gd` gate, `tools/title_dive.sh` recorder | done | 657d14c | | fx_still, title_dive.gd |
| A1 | Title scene: stars, rim, ring with 13 era years, wordmark | done | 657d14c | Off: no drift | fx_still, title_shots |
| A2 | Title menu: Continue card, quiet rows, gliding bracket, campaign card | done | 657d14c | Off: bracket jumps | fx_still, ui_back, monkey |
| A5a | Continue dive (one continuous move) | done | b4368b9 | Light: dissolve only; Off: plain load | title_dive.gd |
| B-mock | Pop-up mock-ups (war, event, battle, treaty, summary, finale, staging) | done | 10f2c85 | | n/a |
| B1 | Dialog staging in `TBPanel.open` (bezel dialogs) | done | faf696e | Off / Reduce motion: the old fade, no staging | staging.gd (+ suite) |
| B3 | War declaration: seal button, face-off card, "War" moment | done | faf696e | Off: no moment (card look is permanent) | war_moment.gd (+ suite) |
| B2 | Event pop-up: illustration band, glyph per class, effect chips | queued | | | |
| B7 | Game-over finale (victory / defeat) | queued | | | |
| B4 | Battle report | queued | | | |
| B5 | Treaty signed | queued | | | |
| B6 | Turn summary sheet | queued | | | |
| B8 | Tooltips / toasts consistency | queued | | | |
| C2 | Conquest sweep on the map | queued (mock first) | | | |
| C4 | Turn passing: terminator sweep, date flip, gauge count-up | queued (mock first) | | | |
| C1 | Armies travel along their route | queued | | | |
| C3 | Battle clash marker on the map | queued | | | |
| C6 | Selection pulse / nation outline breath | queued | | | |
| C5 | Ambient sea / clouds / city glints (Full only) | queued (mock first) | | | |
| A3 | Era picker as a timeline | queued (mock first) | | | |
| A4 | Nation pick with Bezel plates and hover card | queued (mock first) | | | |
| A5b | Begin-game dive (new game) | queued | | | |
| D1-D5 | HUD micro-interactions | queued | | | |
| E1-E4 | Music, ambience, cue set, mix | queued (samples first) | | | |
| F1-F5 | Era mood, tips, portraits / flags, event art, codex | queued | | | |

## 4. Change log with before / after

Pictures are under `docs/screens/`. "Before" = the state at the start of the polish work (`polish_baseline/`), "After" = the build.

### G · Effects foundation
* **What**: `src/ui/fx.gd` (`TBFx.level`, `on(min)`, `dur`, `tween`, `run`, `smooth`); cfg key `fx`; Settings -> Display "Effects"; i18n keys `fx_*` (en / ru / uz); diagnostics prints `fx=`.
* **Rule for every effect**: call `TBFx.on(TBFx.LIGHT|FULL)` or `TBFx.tween/run`; with Off the end state is set at once. A held screen must draw zero frames.
* **Test**: `tests/fx_still.gd` (zero frames drawn + identical still picture for Off / Light / Full + the bracket jumps with Off).

### A1 + A2 + A5a · New title and the Continue dive
| Before | After |
|---|---|
| `polish_baseline/title.png` (text rows inside a bright globe) | `title_built/title_continue.png` (layout B) |

* **Changed files**: `src/ui/title_parts.gd` (new: Orrery ring, CardBtn, RowBtn, SelFrame, Campaign), `src/ui/main.gd` (`show_menu`, `_title_continue`, `_dive_*`, `_enter_loaded`), `src/render/globe.gdshader` + `map_view.gd` (`grid_k` uniform, `jump_to`), `src/engine/save.gd` (meta: `code`, `color`, `cap`, `rk`, `rn`, `rnum`), `data/i18n/*.json` (`title_new_sub`, `title_campaign`, `title_cont_cap`).
* **Layouts**: wide (landscape, height >= 640 and width >= 1.5 x height): globe small in the middle, menu left, campaign card right. Anything else: the old compact composition inside the ring with the same parts.
* **Dive**: 1.9 s on Full (menu fades while the camera already turns; ring opens; at 72 % the game is built under a still that keeps zooming while it dissolves; save read on a thread). Light 0.8 s dissolve. Off: `_load_slot`. Any key / click skips. Videos: `docs/media/title_dive_{flat,globe}_full.mp4`.
* **Not done**: chronicle quotes under the campaign card, wordmark glint, terminator on the globe, music.

### B-mock · Pop-up mock-ups
* Pictures: `popup_mocks/sheet_A_war_event.png`, `sheet_B_battle_treaty_summary_glyphs.png`, `sheet_C_finale.png`, `sheet_D_staging.png` (+ full size). Source `docs/ui_variants/src/b_popups.html`.
* Before pictures for the same dialogs: `polish_baseline/gd_war.png`, `gd_event.png`.

### B1 · Dialog staging
| Before | After |
|---|---|
| `polish_baseline/gd_war.png` (card fades in 0.18 s with a 0.97 -> 1 scale) | `b1_b3/staging_frames.png` (frames at 0 / 66 / 133 / 200 / 300 / 400 ms) |

* **What**: `TBPanel.open` for a bezel **dialog** (modal) now runs `_stage_begin` (deferred, so the caller has filled the body): veil 0 -> its alpha over 0.2 s, the card fades in (0.16 s, from 40 ms) and rises 14 px (0.24 s); on **Full** the header, each body block and the footer then appear one after the other (0.14 s each, spread over 0.32 s). Any mouse press or key completes it (`Guard._input` -> `_stage_finish`).
* **Close**: `Handle.close()` on such a dialog now fades the node out in 0.15 s but it is gone for the game at once (`closing` flag, `tb_handle` / `tb_modal` metas removed, `tb_closing` meta added, mouse and focus ignored; `main._modal_open` skips `tb_closing`). Effects Off / Reduce motion: `root.queue_free()` as before.
* **Not touched**: windows (movable panels), drawers, pages, sheets and the legacy `TBKit.modal` keep their old fade.
* **Files**: `src/ui/panel.gd` (Handle fields `stage`, `stage_end`, `closing`; `_stage_begin`, `_stage_finish`, `_fade_close`, `_ignore_mouse`), `src/ui/main.gd` (`_modal_open`).
* **Test**: `tests/staging.gd` (run with `--fixed-fps 30`): hidden at open, completes by itself, a click completes it, close is immediate for the game and frees after the fade, Off completes in the opening frame.

### B3 · War declaration
| Before | After |
|---|---|
| `polish_baseline/gd_war.png` | `b1_b3/war_1_rest.png`, `war_2_hold.png` (holding 60 %), `war_3_moment_a.png`, `war_3_moment_b.png` |

* **What**: `TBModals.war_confirm` -> rust-edged card (`TBBz.plate_box(12, true, rim)`: new optional `rim` colour tints edge, ground and inner line), the **face-off row** (both flags as medals, rulers from `TBRulers`, a war disc between them), the effect ledger as before, Cancel + the **seal** (`TBWarParts.Seal`: the old hold rule, 0.6 s or Enter twice; ring fills while held; `progress` signal warms the veil toward rust). After the command (`on_yes`) the map turns to the target (`main._fly_to_nation`) and the **War moment** plays (`TBWarParts.Moment`: letterbox bars, rust vignette, both flags + disc pop in, "War", "A declares war on B", date; 2.3 s on Full, 1.2 s banner on Light, none on Off; any click or key ends it; carries `tb_closing` so it never counts as a modal).
* **Files**: new `src/ui/war_parts.gd` (`TBWarParts`: `FaceOff`, `Seal`, `Moment`), `src/ui/modals.gd` (`war_confirm`), `src/ui/bz.gd` (`draw_plate` rim), i18n `war_moment_t`, `war_moment_sub` (en / ru / uz).
* **Behaviour kept**: costs, rows, hold time, the `declareWar` command, the focus on Cancel. The old `K.danger(..."war")` button is no longer used here.
* **Test**: `tests/war_moment.gd` (fixed-fps): the seal is in the card, confirmed closes the card, the moment plays and ends by itself, a key skips it, Off plays none.

*(Add a block per finished step below this line, newest last.)*

## 5. Work queue (top = next). Every step: build behind `TBFx`, run its tests, update sections 3 and 4, commit + push, then take the next row.

Acceptance for every step: (a) Effects Off looks and behaves as before the step; (b) `tests/fx_still.gd` passes; (c) the relevant UI tests below pass; (d) a picture of the result sits next to its mock-up in `docs/screens/<step>/`; (e) this file is updated.

| order | id | what to build | files likely touched | tests to run (one at a time) | notes for next step |
|---|---|---|---|---|---|
| 1 | B1 | (done) | | | |
| 2 | B3 | (done) | | | |
| 3 | B2 | event pop-up: glyph band per event class, strength bar, effect chips with arrows | `modals.gd` (events), new `event_glyphs.gd` | events_ui, ui_modals, ui_overflow | class from `cat` of the event dict; chips come from the choice effects already computed |
| 4 | B7 | game-over finale: stats count up, milestones list, buttons | `modals.gd` `game_over` | gameover_ui, ui_overflow | data = existing game-over stats; no save change |
| 5 | B4 | battle report | `modals.gd`/battle report code | march, ui_modals | numbers already in the report dict |
| 6 | B5 | treaty signed | treaty accept flow | diplo, ui_modals | refusals stay a quiet notice |
| 7 | B6 | turn summary sheet (non-blocking) | `hud.gd`, `alert_ticker.gd` | ui_hud_layout x8, ui_monkey | setting to disable; only when something happened |
| 8 | B8 | tooltip and toast consistency | `map_tip.gd`, `hud.gd` | ui_hud_layout | |
| 9 | C2 | conquest sweep | `map_view.gd`, shader | map_partial, perf_idle, bake, label_shots | **mock first** (before/after pictures + short video) |
| 10 | C4 | turn passing terminator, date flip, gauge count-up | `hud.gd`, `map_view.gd` | perf_idle, ui_hud_layout | End Turn dial untouched; mock first |
| 11 | C1 | armies travel | `map_labels.gd` | march, labels_anim, label_shots | pixel-identical with Off |
| 12 | C3 | clash marker | `map_labels.gd` | label_shots | |
| 13 | C6 | selection pulse | shader | map_partial | |
| 14 | C5 | ambient (Full only, only while the map already redraws) | shader tier | perf_idle (idle frames must stay 0), shader_compare | mock + bench first |
| 15 | A3 | era timeline picker | `newgame.gd`, `menu_parts.gd` | ui_modals (newgame), ui_overflow | mock first (horizontal strip of 13 era cards) |
| 16 | A4 | nation pick plates + hover card | `pick_flow.gd`, `preview_card.gd` | ui_monkey, ui_overflow | mock first |
| 17 | A5b | begin-game dive | `main.gd` `_start_game` | title_dive style recorder | reuse `_dive_*` |
| 18 | D | HUD micro-interactions (D1-D5) | `hud*.gd`, `bz_parts.gd` | ui_hud_layout x8, parity | never the End Turn dial |
| 19 | E | sound: 3 sample cues for the owner, then music bus, ambience, ~20 cues, ducking | `audio.gd` | audio, volume test | owner picks the style from samples; generate offline, small ogg |
| 20 | F | era mood tints, loading tips, portraits / flags for more eras, event art, codex polish | content | | open-ended |

Standing background items (do between steps when idle): the owner's real-machine diagnostics ("Copy diagnostics" from the i3-2100 / HD 2000) are **still not received** - when they arrive,
tune Light / Full from them; lit-space audit; leader portraits; flags for more eras; run `tools/test_all.sh` and the full UI suite after every 3 steps; keep `docs/PERFORMANCE.md` current.

## 6. Open questions for the owner (answer by editing here)

1. Dive default: keep Full on by default (current) or Light until you have seen it on your machine?
2. Music taste (2-3 words per mood: title / peace / war / victory / defeat).
3. Do you want the turn summary (B6) at all, or only the existing toasts?
4. Prussia and other nations without era flags: generate engraved placeholders (F3) or leave the plain generated flags?
