# Compact mode (phone) interface: notes from the owner's device screenshots (S22, Uzbek / English)

Status: the owner cannot play in compact mode, so the compact audit and fixes are mine to do now (visual audit, rate, improve). Later screenshots from the owner will be in desktop mode.
Owner's verdict: "compact is still uncomfortable"; almost everything is too big, bold and overflows.

## From the first five screenshots
1. **Era pick (English, compact).** On the era ring the year and the era name overlap and cannot be read: "1947 / COLD WAR" sit on top of each other at the top of the ring, and "NAPOLEONIC ERA" is crossed by the ring at 1804. The HARD difficulty button is cut off at the bottom of the panel. Tabs (Era / Nation / Play) and the headline are large for a phone.
2. **Title screen (Uzbek).** The title banner ("YANGI O'YIN") is a huge band across the top; the "DAVLAT TANLASH" button is covered by the performance line. The menu card sits over the globe.
3. **Event dialog (Uzbek).** The dialog fills the whole height: tall header band, big title, big choice rows; the performance line runs across it.
4. **Map (Uzbek).** Nation and place names float on the map with no backing. Owner asks: fixed names, or names in a spared box-like space? Compare both and choose what reads better. The rail icons, gauges and dial are large for the screen.
5. **Province dossier (Uzbek).** Everything is bold and large; the gauge rings are cut by the header ruler; building slot names overflow ("QAL'A QUROL-YAROG' OMBORXO…"); the performance line again runs across the gauges. "Almost everything overflows."

## Owner's requests
* Work on the compact interface as a whole: smaller type and spacing, lighter weights, nothing bold and big for its own sake; every panel fits without overflow.
* **Performance display:** "unnecessarily long" ("84 fps · frame 9.9 ms · map tier 1 @210% · mem 0 MB · turn 114 ms"). Shorten it and keep it out of the way of buttons and panels.
* **Names on the map:** try fixed labels / labels in a box and decide which is better.
* **Nation pick in Uzbek shows a flat map**; check the same in Russian (and compare with English, which shows the globe?). Find out whether the view setting or a language-specific path causes it.
* Era ring: year and era name must not overlap at any size.

## To check when work starts
* What "compact" means in code (`phone_ui = "compact"`, `K.is_phone`, `PHONE_STAGE`) and why the layout is still large at 2340 x 1080 (stage 1647 x 760 at DPR 2.66).
* The overflow audit (`tests/ui_overflow.gd`) passes while these screens overflow: it does not cover the era ring, the title, the performance line, the dossier's building slots or the event dialog's height. Extend it with the owner's screens.

## From the next three screenshots (2 compact Uzbek, 1 desktop Russian)
6. **Province card + ring (compact, Uzbek).** The province card already shows the needed figures in a square; a second floating tip ("JIANGXI / Xitoy · Sizning viloyatingiz / Qo'shin 16 · O'rmon") also appears and covers the map and the perf line: **the floating info is not needed** when the card shows it.
7. **Notices (compact, Uzbek).** Two wide notices plus a "+1" chip take the top third of the screen: "almost block the screen". The perf line shows 33 fps, frame 33 ms, turn 252 ms at that moment.
8. **Desktop mode (Russian, 1859 turn 20).** Much smaller and more usable than compact; this is the reference for how big things should be. Overlaps seen here too: the nation name under the crest ("Himachal-Pradesh" map label behind the ruler's name), the "Tibet" label crossing "Войны", the perf line over the date dial ("5 fps · frame 206.7 ms" at that moment).

## Performance report from the device
"Game lags heavily on attacking" (Snapdragon): the overlay showed 33 fps / frame 33 ms / turn 252 ms right after a turn with a war, 84 fps / 5-10 ms when idle. To profile: the attack command and the repaint it triggers on the main thread, the war effects (fx = full) and the turn on the worker thread competing with rendering.

## Key finding: what "compact" is
`phone_ui = "compact"` lays the UI out on a 390 unit tall stage (the demo's phone design); `"desktop"` (the default) uses a 760 unit stage on the same screen, so every element is half the size. The owner's compact screenshots are the 390 stage: that is why everything is huge. Plan: raise the compact stage (about 520), lighten the type (Cinzel 700 caps everywhere reads as bold), and fix the layouts that were tuned for 390.
