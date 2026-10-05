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

(continued below as decisions are made)
