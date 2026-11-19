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
