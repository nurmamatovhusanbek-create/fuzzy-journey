# Terra Bellum — hand-off notes

## Getting builds
Every push to a `claude/**` branch or `main` runs `.github/workflows/godot.yml`:
1. **test** — all headless tests (`tools/test_all.sh`: engine, save/load, rulers, diplomacy, decisions, trade, marriage, generals, ultimatums, honours, supply, events, soak, audio, MP server+2 clients; the script now exits non-zero when any test fails) and the JS-oracle check.
2. **export** — Windows `.exe`, Linux binary, **Android debug-signed APK** → artifact `terra-bellum-builds`.
3. **ios** — exports an **Xcode project** (artifact `terra-bellum-ios-xcode-project`). Open it on a Mac, set your Apple Team ID / signing, build to a device.
   The preset ships with the placeholder team id `0000000000` so the project can be generated without an Apple account.

Install the APK: download the artifact from the run page, unzip, copy `TerraBellum.apk` to the phone, allow "install unknown apps".

CI status (verified on GitHub Actions): tests + oracle pass; Windows, Linux and the Android APK build and upload as `terra-bellum-builds`; the iOS Xcode project exports as `terra-bellum-ios-xcode-project`.

UI smoke tests (random-input monkey on 4 seeds in all three languages, hot-seat flow) run locally with `tools/test_ui.sh` (needs xvfb; not in CI). They caught a broken modal animation and a worker-thread race, so run them after UI changes.

## Measuring performance on a real phone
Settings → **Performance readout** shows fps, frame ms, map quality tier and render scale, memory, and the last end-turn time.
Settings → Quality: *Auto* steps the map down by itself when drags are slow; *Low* uses the half-resolution ID texture and 60 % render scale.
Settings → **Copy diagnostics** puts device, GPU, fps, quality tier, last turn time and game info on the clipboard (also saved to `user://diagnostics.txt`) — paste it into a message.
Please send me numbers from a weak device (SoC, RAM, readout) and I will tune the tiers.

## Multiplayer server
Render service `terra-bellum-godot-server` (Docker, `server/Dockerfile`) redeploys on every push to the working branch.
Default client URL: `wss://terra-bellum-godot-server.onrender.com` (free plan: first connection after idle can take ~30 s to wake).

## Where things live
See `docs/ARCHITECTURE.md` (layers + UI design system), `docs/REBUILD_PLAN.md` (status table), `docs/RESEARCH.md` (genre analysis + backlog).
Content sources: `tools/events_src.py` + `tools/events_content.py` (scheduled events), `tools/events_random_src.py` (random events), `godot/data/rulers.json` (historical rulers), `godot/data/i18n/names_ru.json` (Russian nation names).
After editing `reference/i18n/*.js` run `node tools/i18n.mjs`.

## Game systems added after the research backlog (all `rules >= 1`, rules 0 stays oracle-exact)
Generals (`engine/generals.gd`, 6 % strength per star, ride with full-stack moves) · ultimatums (`TBDiplo.ultimatum`, Yield/Defy prompt for humans, AI yields at ~2.4x strength) · supply limits (`TBGame.attrition`) · honours (`ui/honours.gd`, cross-game achievements stored in settings.cfg) · ruler cameos (`ui/portrait.gd`, procedural) · campaign briefing · AI-attack replay arrows on the map · doctrines (`engine/doctrine.gd`) · hot-seat (`ui/main.gd`, curtain between players) · Codex and advisor tips for the new systems.

## Known gaps
- Never run on a physical Android/iOS device (CI proves the export builds, not that it feels right).
- Uzbek (Latin script) is a third UI language, machine-translated by me: expect rough phrasing; nation/province names and the dated historical events fall back to English or Russian-less English text.
- Nation and province names have Russian atlas forms (machine-translated; expect a few odd transliterations).
- Not ported from the legacy game: formable nations, war goals, data-spike lens.
