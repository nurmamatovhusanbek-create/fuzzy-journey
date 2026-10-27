# Districts: development, buildings and investment (research and design)

## What Age of Civilizations II does (fan guides; the wiki pages were behind a Cloudflare check, so figures are from player guides)
* **Development** is a number per province, raised by spending gold on the province's *Development* tab. It is a project that takes several turns (a guide
  reports +10-30 income showing up while it builds). Steps are percentages (100 -> 120 -> 150 -> 200...), and a province should not be developed far past its
  **population**: once development is close to population the extra income per investment drops. "Match development to population, then grow population."
* Income has two parts: **tax** follows population, **production** follows economy and development (development creates jobs; pops fill them).
* **Buildings** per province: fortress (defence), watchtower (sees neighbours), port, library (research from population), farm (population growth),
  workshop (production), armoury (cheaper recruiting), supply camp (less upkeep). A province can hold several (a guide builds library *and* workshop in the
  same province). Building and investing spend gold and **movement points**.
* Each province carries an **administration cost** (rises with distance from the capital), which is the brake on endless expansion.
Sources: steamcommunity.com/sharedfiles/filedetails/?id=2173941053, gameplay.tips/guides/3427-age-of-civilizations-ii.html, cheatbook.de age-of-civilizations-2 guide.

## Other games (general design knowledge, not looked up here)
EU4 ties building slots to a province's development; HOI4 limits buildings per state by slots; Civ districts compete for tiles. The shared idea:
**slots grow with development, so a rich province can hold more, and what you put in a slot is a real choice.**

## Our model (demo `b_demo2`, to be ported)
* Development 1-5, income `DEV_INCOME = [0,1,3,6,10,15]` per half-year, capped by technology (`floor(tech)+1`).
* **Job fill** = `min(1, pop / POP_NEED[d])`, `POP_NEED = [0,30,70,130,220,350]` (demo scale): income of level d = `DEV_INCOME[d] x fill(d)`. Developing past the
  population is a poor buy; the panel says so ("only 78% of the new jobs can be filled") and farms become the way to grow.
* Cost of a development step = `24 x (DEV_INCOME[d+1]-DEV_INCOME[d]) x 0.93` (about a 30-turn payback with 2%/turn inflation, *before* the pop limit);
  economy step = `24 x 0.4 x development x 0.93`. 2 turns, 1 move each.
* **Building slots** = `1 + floor(development / 2)` (+1 in the capital). Several different buildings per province, each with its levels. A new building costs
  `+20% per building already there`. One construction per province at a time. Demolish frees the slot (the level is lost).
* **Movement points** are the per-turn brake (1 per project, +1.5 per turn up to 6) instead of a fixed project cap.
* **Done (rules 2, docs/MODEL.md section 7).** Numbers differ from the demo's: game costs and pop scale (see MODEL.md). Notes from the original plan follow.
* Engine work (was still to do): `building[p]`/`b_level[p]` become per-province lists, direct investment replaces the random roll in `turn.gd`, job fill enters
  `income()`, then re-run `tools/sim.sh`.
