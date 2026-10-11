# Bezel demo 2 — the functions the first demo lacked

Source `src/b_demo2.html` → `bezel_demo2.html` (copy delivered as `bezel_all_functions.html`). `bezel_demo.html` (build 11) is untouched and stays the
parity reference for the game's first views. Everything below is reachable in the demo (open a screen with `?s=<name>` or from the menu).

| # | Function | Where |
|---|---|---|
| 1 | Alliance (4 envoys, odds dial), royal marriage (3), ultimatum (2, defiance = war), peace terms at war: white peace / cede land (25% score) / vassalise (50%) | Nations → Diplomacy buttons |
| 2 | Nations search, sort (relation / army / A–Z), filter (all / neighbours / friends / foes), Rankings tab (army / provinces / economy bars) | Nations |
| 3 | Generals (appoint 50 g, stars, +6% each), supply limit bar, doctrine (martial / mercantile / administrative) | Dossier, Decrees |
| 4 | Covert operations: intel meter, steal gold / sabotage / incite unrest, odds dial, caught = relations | Nations card |
| 5 | Budget: inflation row and tax > 60 warning; Council: ruler card (skills, trait), infamy and coalition meter (12 / 22), rebels with Reconquer, rebel alert | Budget, Council |
| 6 | Goals: five ways to win with progress rings, regional unification cards | Goals |
| 7 | Save and load (4 slots), Settings (language, text size, map style, sound, high contrast, reduced motion, colour-blind, confirm mode, read aloud), Codex, Honours, tutorial tour, new-campaign pick (era, nation, world aggression), hot-seat hand-over | Menu (gear), `?s=pick`, `?s=hotseat` |

The game port of each follows `docs/BEZEL_PARITY.md`: copy the demo's numbers, not "something similar".

## District panel and taller windows (build 12b)
* Desktop panels start at y 150 and are 994 tall (was 190 / 860): Nations, Dossier, Budget, Decrees, Council, Goals, Settings fit without scrolling at 1920x1180. Phone keeps its own sizes.
* Pressing a province opens the Dossier = **District**: gauges, INVESTMENT (Development 1-5, Economy 1-5, direct purchase, 2 turns, 1 move, projects 1/2), the BUILDING slot (nine buildings as tiles with level pips, a detail strip with effect / cost / turns / the reason when blocked, Upgrade, Demolish), ledger, command (general) and supply.
* Math (to be ported to the engine): development step gain = DEV_INCOME[d+1] - DEV_INCOME[d] (2,3,4,5 -> 1,3,6,10,15); cost = round(24 x gain x 0.93) (about 30-turn payback with 2%/turn inflation); economy step gain = 0.4 x development x 0.93, cost = 24 x gain; development capped by floor(tech)+1; at most 2 simultaneous projects; one building slot per province, replacing = demolish first.

## Proposals are answered next turn (alliance, royal marriage)
Pressing Alliance or Marriage opens a small card with the **likelihood only** (a seamless decline-to-accept colour bar, the percentage and a word), and **Send proposal**.
The envoys are spent at once; the button then reads "Proposed · next turn"; the court answers at the start of the next turn (accepted or declined, with a notice and an Annals entry).
Pact, peace, trade, ultimatum and spy operations still resolve at once. Engine work to port it: a `proposals` list (from, to, kind, turn sent), resolved in turn start with the same acceptance function that
the AI already uses (`TBAI.accepts_pact`), then a chronicle event. The odds shown are the acceptance score now; the answer uses the state next turn.

## Decisions so far
* Status palettes 1 (Navy & brass) and 2 (Ink & ivory) are kept for now (`bezel_palette.html`); the rest are dropped.
* Type options page: `bezel_fonts.html` (seven display + reading pairs, EN / RU / UZ, size slider). Extra faces live in `src/fonts_extra.css`.
* Fonts: pair 2 chosen (Cormorant SC for titles / captions / buttons, EB Garamond for reading). `docs/ui_variants/theme.py` re-skins a built demo with it (and with palette p1 or p2):
  `python3 theme.py bezel_demo2.html out.html p1`. Palette p1 = Navy & brass, p2 = Ink & ivory (colour tables inside theme.py).
* Likelihood bar decided: notched plate (chamfered, brass hairline), decline = diagonal red lines `#B31B1B` (1.5 line / 8 gap) on the dark track, accept = solid brass gold, numbers on their parts (a share under 14% puts its number above), no marker line. Palette: navy deep royal `#011F5B`, brass, red `#B31B1B`.
* **Every request to a court is answered next turn** (pact, alliance, marriage, peace, ultimatum, and spy operations): a card with the likelihood bar and **Back / Send**; Send spends the cost, the button becomes "Proposed · next turn", and at the start of the next turn the court answers with a persistent notice that carries the **country's flag**: light blue inner plate when accepted, red when declined (stays until clicked). No dial, no instant stamp.
* Pressing a court button (pact, alliance, marriage, peace, ultimatum, spy operation) **sends it at once, like Envoy**: no card, no confirmation. The button shows the likelihood (the percentage); the answer arrives next turn as a flag notice (soft blue glow from all edges when accepted, soft red when declined).
