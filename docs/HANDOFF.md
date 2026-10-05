# Terra Bellum — hand-off notes

## Getting builds
Every push to a `claude/**` branch or `main` runs `.github/workflows/godot.yml`:
1. **test** — all headless tests (`tools/test_all.sh`: engine, save/load, rulers, diplomacy, decisions, trade, marriage, events, soak, audio, MP server+2 clients) and the JS-oracle check.
2. **export** — Windows `.exe`, Linux binary, **Android debug-signed APK** → artifact `terra-bellum-builds`.
3. **ios** — exports an **Xcode project** (artifact `terra-bellum-ios-xcode-project`). Open it on a Mac, set your Apple Team ID / signing, build to a device.
   The preset ships with the placeholder team id `0000000000` so the project can be generated without an Apple account.

Install the APK: download the artifact from the run page, unzip, copy `TerraBellum.apk` to the phone, allow "install unknown apps".

CI status (verified on GitHub Actions): tests + oracle pass; Windows, Linux and the Android APK build and upload as `terra-bellum-builds`; the iOS Xcode project exports as `terra-bellum-ios-xcode-project`.

## Measuring performance on a real phone
Settings → **Performance readout** shows fps, frame ms, map quality tier and render scale, memory, and the last end-turn time.
Settings → Quality: *Auto* steps the map down by itself when drags are slow; *Low* uses the half-resolution ID texture and 60 % render scale.
Please send me numbers from a weak device (SoC, RAM, readout) and I will tune the tiers.

## Multiplayer server
Render service `terra-bellum-godot-server` (Docker, `server/Dockerfile`) redeploys on every push to the working branch.
Default client URL: `wss://terra-bellum-godot-server.onrender.com` (free plan: first connection after idle can take ~30 s to wake).

## Where things live
See `docs/ARCHITECTURE.md` (layers + UI design system), `docs/REBUILD_PLAN.md` (status table), `docs/RESEARCH.md` (genre analysis + backlog).
Content sources: `tools/events_src.py` + `tools/events_content.py` (scheduled events), `tools/events_random_src.py` (random events), `godot/data/rulers.json` (historical rulers), `godot/data/i18n/names_ru.json` (Russian nation names).
After editing `reference/i18n/*.js` run `node tools/i18n.mjs`.

## Known gaps
- Never run on a physical Android/iOS device (CI proves the export builds, not that it feels right).
- Nation and province names have Russian atlas forms (machine-translated; expect a few odd transliterations).
- Not ported from the legacy game: generals, formable nations, ultimatums/war goals, data-spike lens.
