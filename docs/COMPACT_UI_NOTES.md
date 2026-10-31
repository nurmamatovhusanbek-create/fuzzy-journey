# Compact mode (phone) interface: notes from the owner's device screenshots (S22, Uzbek / English)

Status: **notes only, work has not started** (the owner will say when). More screenshots are coming; add them here.
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
