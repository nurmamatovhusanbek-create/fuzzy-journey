# Feedback notes (to be worked through; nothing here is built yet)

## Batch 2025-11-01 (from the phone, Uzbek, Timurid Emirates 1492)

1. **Province ring centre shows the province's worth, not its army.** Today the ring's middle reads the name and the army count (e.g. MARI ✖21). Show what the province is worth instead,
   so the player gets the idea of its value at a glance. (The army stays on the map as the counter pills; only the ring centre changes.) Needs a clear "worth" figure: the
   engine already prices provinces for the peace table (`TBPeace`, dev / economy / population, capital ×4), so the same number can be the base. To decide with the player: one figure or a short breakdown.
2. **How AoC2 handles investing in a province and its accumulation / growth** ("how the province's rate gets higher"). Not yet researched: the war research (docs/WAR_DESIGN.md) covered recruitment, moves,
   war, peace, occupation, morale and supply, not development. To do: research AoC2's investment (development / economy / building points, accumulation over turns, what raises a province's rating),
   compare with our districts model (rules 2: development, economy, building slots) and write what to change. The worth figure in item 1 should follow whatever this finds.
3. **Remove the floating province info.** Said before and still present: the small floating hover card (e.g. "QINGHAI · Tibet · Tinchlik / Armiya noma'lum · Tog'lar") that sits on the map. Remove it.
   To confirm: whether the "VILOYAT MARI" card beside the open ring (stats, "DOSYE") counts as the same thing or stays.

## Batch 2 (same session, phone screenshots at turns 6 and 16). The player said: take notes, do not start until told.

4. **Sending troops must work from inner provinces too.** The troop-count slider (rules 4) has to be available for any province of yours that holds troops, not only border ones. To check on the phone why it
   is missing there (the player's wording: "even in inner provinces").
5. **No forced "leave 1 soldier".** A province may be emptied: the whole army can go. A province with no army shows no army counter at all (today the map is full of "1" counters).
6. **Agreements and pacts need real logic.** A North American country offering a non-aggression pact to the Timurids (a hover card "HUJUM QILMASLIK · BEOTHUK · +28" with a route drawn halfway round the world) makes no sense.
   Build the rules for who proposes what to whom: contact / distance / shared borders, shared enemies or threats, relative power, existing relations, and which agreements are even sensible for the pair;
   the same logic for acceptance, for AI-to-AI and AI-to-player offers. Write it down (docs) before building.
7. **After taking a province, the army in it cannot move again** — neither on to attack nor back into own land. Make it possible (to check what blocks it: a moved-this-turn flag, occupation rules or the picker).
8. **When an attack happens, the camera goes to the province being attacked, with a red arrow from the attacker.** The arrow starts from the attacking country's side. Open question: for the player's own attacks and for AI attacks on the
   player, or all attacks that can be seen.

Also seen in the screenshots: the floating hover card (e.g. "RAJASTHAN · Rajastxon · Tinchlik", "MIN IMPERIYASI · Tinchlik") is still on the map — see item 3, remove it.

## Batch 3 (turn 53 / 64 screenshots). Notes only until the player says go.

9. **An open country card does not refresh.** Send a pact, press End Turn with the Nations / country card still open: the card keeps the old data (relation, the pact button state, answers). It has to update live
   when the state changes (turn end, a command, an answer arriving), without closing or jumping back.
10. **The Xalq (people) gauge shows 101 % / 103 %.** Its tooltip reads "1 689 fighters, +80 per turn · People 1 689 / 1 677 · Growth per turn +80 · one soldier costs 12 g · 18" — the levy pool is above its own cap, so the share passes
    100 %. To fix: the display must never pass 100 %, and the pool should not sit above the cap (find why it gets there: the cap shrinking after growth, recruits returning, conquest). Check the wording of the "at the limit" line too.
11. **Army counters appear too early when zoomed out.** At the scale of the second screenshot (the Caspian / Central Asia on a phone, about a hundred counters at once) the numbers are not needed. Raise the zoom at which counters appear
    (the appearance distance "lower than that" view), calibrated on this phone screenshot, for both globe and flat. Today's gate is the same fit rule used for the province pills (`pills_fit`).
