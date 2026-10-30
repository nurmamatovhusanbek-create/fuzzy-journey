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
* Nine new modern-era events (2026 to 2037).

## Interface
* Province ring: the centre names the province with its army beneath; the card and map names keep clear of the verbs' names.
* Notices are one shape; gauge figures stay inside their rings.
* High contrast light mode readable on every dialog, card and the HUD.
* Capital stars (big countries at country level), map names on two lines, names stable while the globe turns.
* Tutorial text brought up to date; small desktop windows are no longer tiny.

## Speed and tests
* AI turn about 2 times faster (trade step, loyalty terms, income loop); outcomes identical.
* New checks: realism (rules 3), era audit, light-mode contrast, first minutes screenshots, UI tests run on fresh settings.

## Known
* Google Play still needs Godot 4.5 or newer (target API 35, 16 KB pages, AAB); a trial of 4.5 is waiting for permission to run the editor.
