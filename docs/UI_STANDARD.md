# Interface standard

One interface for the computer and for Android (a phone held sideways gets the desktop layout on a taller stage). Every window follows these rules. Each rule is measured by a test, not by eye; a window is finished when its test passes at 100 % and 200 % text, in English, Russian and Uzbek. Research behind the rules: `docs/UI_RESEARCH_2026_11.md`.

## Type and size (tokens: `ui_tokens.gd`)
| Role | Size at the standard density | Where |
|---|---|---|
| Title | 20 | window titles, big figures |
| Figure | 16 | numbers in tiles and rows |
| Body | 14 | names, sentences, controls |
| Detail | 13 | one-line effect text under a name |
| Caption | 12 | section headings, tile captions (tracked capitals) |
| Floor | 10.5 layout units (`FS_FLOOR`) | nothing is ever set smaller (`K.fs`, `K.fsf`) |

Honest state: the roles are the intended scale; code reads only the floor today, and many captions are set at 10 to 11 units (the floor lifts the smallest). Moving every call to a role (`K.role("caption")`) is the next step of this standard.

The layout stage is divided by the interface size (`UI_STAGE_K`: compact 1.0, normal 0.84, large 0.72), relaxed by `UI_STAGE_LAPTOP` (1.10) on a screen 800 px tall and fading to 1.0 at 1080 px, so a 1080p screen shows 14 px body text and nothing under 11.5 px, and a laptop still fits the Budget, Decrees and Settings windows. Colours come from the token set only (the lint `ui_lint_tokens.gd` refuses a raw colour in `src/ui`); state and severity use `pos`, `neg`, `warn`, `info`.

## Controls: five kinds, never mixed shapes
| Kind | Used for | Notes |
|---|---|---|
| Segmented control | any choice of 2 to 6 options, including Off / On | equal-width cells filling its column; cells wrap to a second row only when they do not fit one row |
| Stepper + figure | a number inside a range (budget shares, troop counts) | two square plates 30 x 28, one value cell, never a round button |
| Slider | a continuous share where the shape of the range matters | track, hatched danger zone, tick scale; always paired with the stepper |
| Button | an action | primary (brass) at most one per container; danger (rust) for irreversible acts |
| List row | navigation between pages or topics | selected row has the brass bar; the same row in Settings categories and How to play |

No drop-downs, no free-floating switches, no round buttons in a row of square ones.

## Geometry
- Unit 8 px. Content margin 20 px. Gaps 8 or 16 px.
- One control height: 28 px (30 on a phone). The notched plate is drawn as one antialiased outline, so every plate has all four corners at every width.
- A settings row is [name + hint] left, one control right in a column of fixed width (300 px); a hairline under the row. A narrow window stacks the control under the name.
- Tables (Budget) use fixed columns; every row is as tall as the tallest, so the pitch is even in every language.
- A scrollbar always holds its place, so a page that scrolls and one that does not keep the same column.

## Hierarchy
1. Window title with its icon and a one-line subtitle.
2. Summary (what the window is about): figures on equal plates of one height.
3. Rows or cards, each with name, effect text (never cut: wrap, do not ellipsize), control.
4. Footer: the secondary action left (Revert, Main menu), the primary right (Done, Resume).

## Information
* Glanceable first: a window opens on a summary (tiles of one height, at most three figures each), then rows, then detail one level down. Two clicks deep at most.
* A tooltip says *why*, never the only copy of something the player needs; a window that talks about a place shows it (a list row lights the country's border on the map, "Show on map" buttons); nothing opens over what it is about without being movable.
* Matters are grouped under who raises them (the Council by minister) and carry a severity bar (neg crisis, warn warning, neutral tip). Effects are listed one per line with the sign and the meaning colour (events, decrees, institutions).
* Sorting and filters persist between openings (Nations, Outliner).

## Tests
`tests/ui_type_floor.gd` (no text under the floor at 1080p, a laptop and 1440p), `tests/ui_cycle1.gd` (hover lighting, the Council grouping, the Raise bar), `tests/ui_icon_names.gd` (every icon asked for has a drawing), `tests/menu_grid.gd` (Settings), `tests/budget_grid.gd`, `tests/decrees_grid.gd`, `tests/nations_grid.gd`, `tests/dialogs_shot.gd` (dialogs on one axis), `tests/btn_widths.gd` (the plate at every width). Run only the test of the window you changed.
