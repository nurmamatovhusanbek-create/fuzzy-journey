# Terra Bellum 1.0.0: releasing on itch.io

Single player is complete and is what ships. Multiplayer shows a **COMING SOON** tag on the title; pressing it opens a short note and starts no network code. To turn online play on later, set `TBRelease.multiplayer = true` (`godot/src/ui/release.gd`) and put the Android `internet` permission back (`export_presets.cfg`, preset Android).

## Build

```bash
# Windows + Android (the Android key stays outside the repository)
TB_KEYSTORE=/path/terrabellum-release.keystore TB_KEYSTORE_PASS='...' tools/build_release.sh
# -> build/dist/TerraBellum-1.0.0-windows.zip, TerraBellum-1.0.0-android.apk, SHA256SUMS.txt
```

`tools/build_release.sh` exports, zips, verifies the APK signature and prints its package, minimum and target API and permissions. Needs Godot 4.4.1 and its export templates, JDK 17+, and the Android SDK (platform-tools, build-tools 34.0.0, platform android-34) configured in the editor settings (`export/android/android_sdk_path`, `java_sdk_path`).

## Android requirements

| Item | This build | What it means |
|---|---|---|
| Package | `com.terrabellum.game` | Never change it: it identifies the app for updates. |
| Version | name `1.0.0`, code `1` | Every upload that replaces an installed app needs a **higher code** (`version/code` in the Android preset). |
| Minimum API | **21** (Android 5.0) | Phones from 2014 on. |
| Target API | **34** (Android 14) | Installs and runs on Android 14, 15 and 16. Android only refuses apps targeting below API 23. |
| Permissions | **none** | Internet and network state are off while multiplayer is off. Nothing to explain on install. |
| CPUs | arm64-v8a and armeabi-v7a | Every current phone and tablet, including 32-bit-userland budget phones. Not x86 emulators. |
| Orientation | landscape (sensor) | The phone shows the desktop-style 1000-unit layout with bigger touch areas. |
| Graphics | OpenGL ES 3.0 (Godot compatibility renderer) | Any phone since about 2015. |
| Signature | APK Signature Scheme v1 + v2 + v3, RSA-4096, valid to 2056 | One key signs every future update. **Lose the key and players can never update in place.** |
| Size | about 80 MB | Both CPU families inside. |

### Not ready for Google Play (itch.io does not need any of this)

Google Play requires newer settings than Godot 4.4.1 can produce:

* target **API 35** (and the following level when Google raises it each August),
* native libraries aligned for **16 KB memory pages** (the 4.4.1 libraries are 4 KB aligned: fine on today's phones, rejected by Play),
* an **AAB** instead of an APK and Play App Signing.

The way there is upgrading the project to Godot 4.5 or newer and re-exporting; the game code needs no changes for it, but the upgrade has to be tested like a release. Check the Play Console "target API" page for the current numbers before submitting.

## Windows requirements

Windows 10 or 11, 64-bit; any GPU with OpenGL 3.3 (about 10 years of hardware); 2 GB RAM (the game peaks near 0.5 GB); about 130 MB of disk; no internet. The executable is unsigned, so SmartScreen shows "Windows protected your PC" once: *More info → Run anyway*. A code-signing certificate removes that; it is optional and costs money. The file icon in Explorer is Godot's default until the build is run through `rcedit` (needs Wine on Linux); the window and taskbar icon are the game's own.

## Upload to itch.io

1. Create the project (kind: **Downloadable**), upload `TerraBellum-1.0.0-windows.zip` (tick **Windows**) and `TerraBellum-1.0.0-android.apk` (tick **Android**).
2. Or with butler (`butler login` once): 
   ```bash
   butler push build/dist/TerraBellum-1.0.0-windows.zip YOURNAME/terra-bellum:windows --userversion 1.0.0
   butler push build/dist/TerraBellum-1.0.0-android.apk YOURNAME/terra-bellum:android --userversion 1.0.0
   ```
3. Page text, tags, system requirements and the screenshot list are in `docs/itch/PAGE.md`; cover and screenshots are in `docs/itch/`.
4. Android players must allow "install unknown apps" for the browser or the itch app; say so on the page (it is in `PAGE.md`).

## What was checked for this release

| Area | How |
|---|---|
| Engine: rules, economy, wars, diplomacy, rulers, events, determinism | `tools/test_all.sh` (30+ suites), oracle against the JS reference, AI-only balance simulation across eras (`tools/sim.sh`) |
| Save and load | round trip continues bit-identically in three eras; damaged file falls back to the previous save; atomic write |
| Abuse and robustness | `tests/security.gd` (47 checks), `tests/fuzz_commands.gd` (thousands of hostile commands), `docs/SECURITY.md` |
| Links and texts | `tools/audit_links.py`: every resource path, every translation key, English / Russian / Uzbek parity |
| Interface | `tools/test_ui.sh`: layouts at desktop, phone-landscape and compact sizes, text scales, three languages, overflow and overlap audit, effects, audio cues |
| The package itself | the exported Windows package was started with its own data, three eras were played for turns, saved and loaded |
| Android package | signature, API levels, permissions and icons read from the APK; **not run on a phone or emulator in this environment: install it on a real device before announcing** |

## Known limits (honest list)

* Multiplayer: coming soon (see above); when it opens, fog of war is not enforced by the server (`docs/SECURITY.md`).
* Windows build is unsigned (SmartScreen notice) and its Explorer icon is Godot's default.
* Android build has not been run on hardware by the build environment.
* Not for Google Play yet (see above).
