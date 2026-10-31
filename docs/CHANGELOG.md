# Changes since 1.0.0 (proposed version 1.1.0, Android version code 3)

Everything below is on branch `claude/ecstatic-gauss-f495v8`; saves from 1.0.0 still load. Rules 3 is the default for new games; rules 0 to 2 are unchanged and rules 0 still matches the JavaScript reference bit for bit.

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
