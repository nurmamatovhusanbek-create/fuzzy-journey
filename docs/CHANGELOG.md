# Version 1.6.1 (Android code 9): new icons

* **Every icon redrawn** as an engraved plate emblem (67 drawings, `docs/ICONS.md`): period objects in brass, bone, vermilion and Tyrian purple by what they mean, none in the game's own status colours. Settings > Display > Icons: colour by meaning, all brass, or the classic line icons. Colour-vision and high-contrast modes always use brass.
* The province ring is one brass instrument: its verbs are drawn in the ring's own brass and ivory, never in the meaning colours (those belong to icons that stand alone: alerts, lists, cards, the rail).
* The province ring, the left rail, the build picker, alerts, cards and the codex all use them; orders that had no icon of their own (hire, develop, settle, spread, muster, general, release) have one.

# Version 1.6.0 (Android code 8): what the research asked for

Rules 5 (real people, gold and soldiers at 10/20/30:1, `docs/RULES5_REALISM.md`) is the default. On top of it, from `docs/RESEARCH_2026_11.md`:
* **Spread and Muster**: every nation starts with its army in the capital; one order marches it out to the front, another raises levies in every front province at once. The AI spreads its armies too, and an advisor alert says so until you do.
* **Undo** (Ctrl+Z or the game menu): up to twelve orders back, closed by the end of the turn or anything that rolls the dice.
* **Alert settings**: tips can be switched off one by one (Settings > Alerts); crises always show.
* **Breakdown tooltips**: a province's stability and people list the engine's own terms.
* **Outliner** (F7): what is under way, armies and marches, wars, pinned provinces. A People section on the Realm page. Nations list sorts by standing and technology.
* **State works**: six lasting works a full treasury can build, priced in turns of the realm's own output (player and AI).
* **AI aims**: a state that declares war picks an aim (the enemy's whole land, its border provinces, a vassal, a humbling) and fights for it; the aim shows on the nation's card to its enemy and to anyone with agents.
* **Release a vassal**, united historic regions become home land and pay 2 % more, three new lenses (growth room, levy pool, army per head, behind More), codex entries for all of it.
* **Held land** (rules 5): land your army holds but has not annexed gets the same ring as your own (Move, Build), you can put a port, fortress, watchtower or supply camp up in it (a port there is a landing base for marches), and an army in it is drawn and ordered like one at home.
* **War camera**: the globe draws out for the first battle of a war only; later battles leave your zoom alone and pan only when the fight is out of view.
* **Beyond the horizon**: an attack from the far side of the globe shows a red curved arrow coming in from the rim, in the direction of the attacker.
* **Title**: the Play morph is one continuous movement (the wordmark never leaves, the globe moves on one curve, the live globe dissolves in where it coincides with the title globe); both stages come in with an entrance and run at full frame rate while they move.
* Fixes: a data race in the vision mask, const tables in the engine made safe for the turn thread (corrupted memory in a stress run), sub-pixel text positions off so baked and live text match.

# Changes since 1.0.0 (proposed version 1.1.0, Android version code 3)

## Rules 4 war systems (in progress)
- Saves of rules 4 games loaded as nothing (the rules limit was 3): fixed, and the round-trip test now covers rules 4.
- Army morale and war exhaustion, supply reach, sieges of fortified provinces, a war score earned in the field, occupation income and resistance, and a peace table where the winner ticks land, gold, a vassal or disarmament and sees what the other side will accept. Details in docs/WAR_DESIGN.md section 14.
- Work loss no longer counts an enemy host standing in your province as your own men.

Everything below is on branch `claude/ecstatic-gauss-f495v8`; saves from 1.0.0 still load. Rules 3 is the default for new games; rules 0 to 2 are unchanged and rules 0 still matches the JavaScript reference bit for bit.

## Fixes after the compact-mode round (map and orders)
* A conquered province shows the occupier's flag and army (the badge, army totals and the army cycle follow the controller, not the old owner).
* A war front no longer traps the selection: the first tap on an own army next to a selected enemy province picks it as the attacker, the second selects it.
* Army pills: none at country scale; your own, wars and allies first, everyone once a province is wide enough for a pill; at the closest zoom the pill stays at 92 % and the figures at 11 px or more.
* How many soldiers: the move preview carries a troop picker (slider, typed number, 25/50/75/100 % presets) and the odds follow it; Recruit and Hire open a card with the same picker and the live price before anything is spent.
* Routes lens on the flat map: straight lines the short way round the sideways wrap, drawn in every copy of the world that reaches the screen; the lens no longer hashes its two big arrays every frame.

## Rules and logic (new games)
* Quarrels spread: hurting a friend of a nation costs you with that nation, less than with the friend; trade routes need a steady income, gold and people; a route lapses when either side is bankrupt or the courts hate each other.
* A court holds only `2 + sqrt(provinces) + era / 2` alliances.
* Victories must be held for several turns; alliance hegemony is an honour (Concert of Nations), not an ending.
* Veteran colonies (spare people to stability and population) and embassies (envoys and gold to cool a grudge and gain intelligence).
* Buildings follow the land: ports need a coast, farms need soil and rain.
* Terrain follows the geography (mountain ranges, forests, steppe, marsh).
* Ruler names fit the country (14 name spheres); the modern world finally has real capitals.
* Nine new modern-era events (2026 to 2037); fifteen for the ancient and Roman eras (Trasimene, Raphia, Chen Sheng, the Han founding, Baideng, the last Maurya, the Maccabees, the Land Law; the Pantheon, the Western Regions, the Red Sea trade, Ctesiphon, the Marcomannic wars, the eunuchs, the revolt in Syria). Ancient: 18 of 28 events fire in 100 turns (was 12 of 20); Roman: 14 of 26 (was 9 of 19). Nineteen more for the medieval (the Coronation Charter, the Anarchy, the Second Crusade, the Crusaders at Constantinople, the Great Kurultai, Las Navas de Tolosa, Runnymede), Mongol (the Red Turbans, the Golden Bull, Louis the Great, the Peasants' Revolt, Kosovo Polje, the conqueror at the Indus) and Timurid eras (Horodlo, the madrasa at Samarkand, Timbuktu, movable type, the Wars of the Roses, Belgrade).
* Uzbek: all 180 scheduled history events (title, text, choices) now have Uzbek text (only 9 did, the rest showed English), and 544 nation names are in Uzbek on the map and in lists (Fransiya, Rossiya imperiyasi, Usmonlilar imperiyasi). Names without a form stay in English. The provinces of Central Asia (Uzbekistan, Kazakhstan, Kyrgyzstan, Tajikistan, Turkmenistan, Afghanistan: 63) have Uzbek names too (Toshkent, Samarqand, Buxoro, Farg‘ona, Qoraqalpog‘iston).

## Interface
* Province ring: the centre names the province with its army beneath; the card and map names keep clear of the verbs' names.
* Notices are one shape; gauge figures stay inside their rings.
* High contrast light mode readable on every dialog, card and the HUD.
* Capital stars (big countries at country level), map names on two lines, names stable while the globe turns.
* Tutorial text brought up to date; small desktop windows are no longer tiny.
* At 200 % text the End Turn dial no longer prints its word over the number and keeps its whole label on screen; the province ring's verbs are no longer cut to "MOVE AR…".
* Long words (Russian, Uzbek) are set a size smaller instead of being broken in the middle; long event choices no longer lose their first lines at large text.

* Research no longer stalls late in the game: levels above 2.5 cost far less (190 points at 4.0, was 521), so a modern nation gains about 0.2 of a level in 40 years at the default budget (was 0.04). Earlier eras are unchanged. The budget screen's research line says how long the next level takes.

## Speed and tests
* AI turn about 2 times faster (trade step, loyalty terms, income loop); outcomes identical.
* The overflow audit used to run Russian and Uzbek in English (the game reloaded the saved language over the test's); fixed, and it now also opens the longest scheduled event of each language. Re-run: clean at 100 %, 150 % and 200 % text, 1080p and the S22 stage.
* New checks: realism (rules 3), era audit, light-mode contrast, first minutes screenshots, UI tests run on fresh settings.

* A history event that is more than three years overdue is skipped: a save made before an event was added no longer fires it years late (a 1.0.0 modern game would have met the 2026 to 2037 events in 2044).
* Saves made by 1.0.0 (rules 2) load with this version and play on: three fixtures (`godot/tests/fixtures/save_v100_*.tbs`) are loaded and played 100 turns by `tests/old_saves.gd` in the engine suite.

## Known
* Google Play still needs Godot 4.5 or newer (target API 35, 16 KB pages, AAB); the 4.5 trial passed (see `docs/GODOT45.md`); the project stays on 4.4.1 until you decide.
