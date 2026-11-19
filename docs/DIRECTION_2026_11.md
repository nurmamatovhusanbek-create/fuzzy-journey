# Direction, November 2026: nations that change, a world that moves

The player's verdict: the game can only conquer and trade, nothing gains, nations cannot become other nations, the interface still has far to go. No real players exist yet, so legacy can be cut. Working method: research a part, plan, build, criticise, repeat, all stitched into one game.

## Cycle 1: identity (built): lineages
Research: EU4's formable nations are a decision with territorial and government conditions that changes name, flag and a few ideas; players call it "lacking ceremony". Our version: `data/lineages.json` (25 stages in 13 lines, built from the era files by `tools/lineages/build.py`; the core of a stage is the land its tag held in history), conditions (year, government, share of the core, gold, moves), claims as a casus belli on the core, a lasting bonus by weight, an AI that proclaims too, a path strip and cards on the Realm page, a ceremony. Critique after building: the ceremony is a plain dialog, the bonus is flat percentages, the lines exist only where the era files carry the tags.

## Cycle 2: gains (research done, building now): institutions
Research on mission and focus trees: players praise the direction they give, and criticise them as railroads, modifier dispensers, detached from the game's own systems, with an AI that cannot use them. So: no scripted per-country trees. What gives real, systemic gain without a script: **institutions**, the advances of an age (banking, printing, navigation, gunpowder state, joint stock, enlightenment, industry, railways, electricity, computing) that appear in one historical place, spread province to province (faster through trade, development and an embracing owner), and that a state may **embrace** for a lasting gain, or fall behind. The AI plays by the same rules; conquering a birthplace, trading with the advanced and developing your land all matter.

## Cycle 3: the desktop interface (planned)
One interface for computer and Android: the compact layout and its tests go. Rebuild the long grey ledgers into visual screens (Treasury hub, Chronicle), keep the emblem icons, give moments (proclamation, an institution arriving) a presence.

## Cycle 4: strip the legacy (planned)
Rules 0-4 branches, old-save compatibility and the JS oracle go; the architecture stays: data files, headless engine, one `apply` for every change, events as data.

## Where it stands (written after the third cycle, honestly)
Built and tested: lineages, institutions, estates, reform of the government, ambitions on the Goals page, advisor tips, twelve events that read these systems (`inst_has`, `inst_behind`, `est_below`, op `loyalty`). They are stitched: embracing an institution moves the estates; an estate's loyalty moves income, levies, stability, research; the government form decides the estates' weights and what names of a line are open; a name formed gives a bonus and claims. Everything is data (`data/lineages.json`, `institutions.json`, `estates.json`, `events/random.json`) read by one engine module each, changed only through `apply`.

What is still weak, said plainly:
* **Balance is untested by play.** The effects are mild on purpose (a few percent); no run by hand has judged whether a player feels them. Numbers: `TBEstates` constants, `data/*.json`.
* **The AI embraces institutions rarely** (one embrace in four seeds over fifteen years): the spread is slow and an AI that never reaches 25 % never embraces, so the lag penalty falls on it. Fine as history, but it makes the player's lead large.
* **The compact phone layout is unreachable but not deleted**: the setting, the stage and the tests are gone; the `is_phone` branches in about twenty UI files are dead code. Cycle 4 removes them with the rules 0-4 paths.
* **Uzbek and Russian text I wrote for all of this has not been read by a native speaker.** Glossary decisions are still open (`docs/UZ_STYLE.md`).
* **The Treasury hub and the Chronicle** are not rebuilt yet; only the Realm page became two pages (Government / Ledger) and the Goals page gained its Ambitions.

## Cycle 4, first step (done) and what is left
Done: the JS oracle is gone from the suite, the CI workflow and the README (the game plays rules 5; `reference/engine-js` stays only because `tools/bake.mjs` reads it for the map bake).
Left, deliberately not done in one go: the `rules < 5` branches (about 600 conditions in 60 files, 35 tests build games at rules 0 to 4, most others rely on the default of 3). Collapsing them is mechanical but touches every engine file and rewrites those tests; it should be its own change with the whole suite as the safety net, file by file (`game.gd`, `turn.gd`, `diplomacy.gd`, `ai.gd`, `commands.gd` hold two thirds). Until then new games are rules 5 and the lower rules only run in the tests that name them.
