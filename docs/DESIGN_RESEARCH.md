# Design research log — "the cartographer's table"

Goal: an interface and map that look and feel like *this* game (a campaign fought over an old atlas), readable at every
zoom, never overflowing, comfortable on a phone and on a desktop. Method: name the problem, list options, prototype the
plausible ones, compare screenshots against explicit criteria, keep the winner, keep the loser as a fallback.

## Findings from audits
| Audit | Tool | Result |
|---|---|---|
| Overflow / clipped text / off-screen controls across 5 resolutions × 19 screens | `tests/ui_lint.gd` | only the perf readout overflowed phones; most clipping risk is hidden inside scroll areas, so screens are also reviewed as contact sheets (`tests/ui_sheet.gd`) |
| Random-input crashes | `tests/ui_monkey.gd` | found a broken modal animation and a worker-thread race (fixed) |
| Close-zoom map quality | `tests/ui_zoomq.gd` | the 4096×2048 id texture shows diamond-shaped edges once a texel spans several pixels |

## Q1 — Province edges at close zoom
Options: (A) bigger id texture (64 MB, rejected for phones) · (B) vectorised border polylines (heavy: projection + AA in
CPU, fills would not match) · (C) shader-side reconstruction: quadratic B-spline weights over a 3×3 neighbourhood choose
the winning id, a faint low-frequency domain warp removes straight runs, line weight grows with zoom.
**Chosen C** (only when a texel covers ≥2 px). Fallback: B.

## Q2 — Army numbers while zooming out
Options: (A) numbers stay at every zoom · (B) numbers vanish with zoom (levels) · (C) one banner per nation · (D) numbers only on
hover/selection · (E) pennants whose size encodes strength, digits only close up.
Criteria: clutter, information value, stability during zoom, tap targets.
Result so far: B (stars → key stacks → all) removed the clutter; the glyph itself is being redesigned (E).

## Q3 — Visual language
Options: (A) navy lacquer + brass + chamfered frames (the previous "war table") · (B) cartographer's table: laid paper
documents, ink, brass corner guards, wax seal, umber leather instrument strip, medallion dock · (C) nautical chart.
Criteria: matches theme (history, maps), distinctive, readable (contrast), cheap to render procedurally, consistent with
the parchment map theme.
**Chosen B**: documents are paper (sheet, chit, wax), furniture is umber leather and brass. Fallback: A (git history).

## Q2 result — army glyph (prototype E vs. shield)
Prototyped both with `tests/ui_plaque.gd` (TB_PLAQUE=0 shield, 1 paper gonfalon) at zoom 1.6 / 3 / 6 / 12 on the standard map.
Shield: strong contrast but a dark lozenge repeated 40× reads as noise and has nothing to do with the paper interface.
Gonfalon (cream cloth, owner-colour header, ink figures, swallow-tail hem, brass studs = rank, red hem at war, grey for foreign):
most legible digits on every lens, consistent with the sheets. **Chosen: gonfalon** (`plaque_style` 1). Fallback: shield
(`TB_PLAQUE=0`). Distance behaviour is unchanged: zoom-level disclosure (stars → key stacks → all).

## Q4 — Things that overlap
Map text (province names, stars, plaques) used to run under the dock, the ribbon, the End-Turn seal and the side panel.
Chosen: the HUD publishes the rectangles it covers (`TBHud.keepouts` → `TBMapView.keepout_fn`) and every label pass treats them
as occupied space. No label is drawn where the interface would hide it.

## Q5 — Panel actions
Wrapped rows of different-width buttons looked ragged and the panel overflowed when two columns were forced. Chosen: one
column of full-width buttons (clear tap targets, no overflow at any width); figures follow below.

## Q6 — Wide windows for pop-ups
Tested on landscape ≥ 820 px: Settings (7 choice rows, previously a scrolling 440 px column with Back below the fold), Honours
(19 rows) and Decisions. Two-column layouts of 780–920 px show everything at once: Settings and Decisions need no scrolling,
Honours shows 18 of 19, and the action buttons are pinned in the footer. **Chosen: wide two-column sheets on landscape,
single column on portrait and short phones** (fallback: the single column, unchanged). Candidate next: nations list, codex.

## Q7 — Weight diet (too bold)
Findings from screenshots: every button, title and map label used Cinzel 700, army figures were JetBrains Mono 700, chit
borders were 1.1 px at 55 % ink with a heavy drop shadow and rough edges, sheet rules 1.4 px, brass guards 13 px, and the wax
button's grain was stretched into streaks. Changes: display face 500 (700 only for the big title), figures regular, borders
0.8–1.0 px at 30–45 %, shadows halved, corner guards 9 px, calmer paper grain, grain scaled in pixels so it never stretches,
map-label outlines kept readable but lighter (3 px at 75–80 %). Fallback: the 700 weights are one-line changes in `TBKit`.

(continued below as decisions are made)
