# Interface standard (branch ui/perfect-interface)

Every window follows these rules. Each rule is measured by a test, not by eye; a window is finished when its test passes at 100 % and 200 % text, in English, Russian and Uzbek, on the desktop layout and the compact phone layout.

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

## Tests
`tests/menu_grid.gd` (Settings), `tests/budget_grid.gd`, `tests/decrees_grid.gd`, `tests/nations_grid.gd`, `tests/dialogs_shot.gd` (dialogs on one axis), `tests/btn_widths.gd` (the plate at every width). Run only the test of the window you changed.
