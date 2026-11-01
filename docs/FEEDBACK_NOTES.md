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
