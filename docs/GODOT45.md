# Godot 4.5 trial (Google Play path)

Run 2026-10-31 on a copy of the repository (`godot/`, `tools/`, `reference/`) with the stock Linux editor 4.5.stable (876b29033). The project in the repository stays on **4.4.1**; nothing in `project.godot` or the export presets was changed.

## Result: pass

| Check | Godot 4.5 result |
|---|---|
| Engine suite (`tools/test_all.sh`: rules, realism, events, saves, sims, era audit) | all pass |
| JS reference oracle (rules 0, four scenarios) | 4 of 4 MATCH, bit-identical |
| UI suite (`tools/test_ui.sh`: 77 steps, incl. contrast on 18 light-mode screens, overflow at 150 % and 200 % text in en / ru / uz at 1080p and S22, monkey runs, label stability) | UI PASS, 0 failures |
| Engine warnings / deprecation messages in the logs | none |

No source change was needed to run on 4.5.

## What this does not prove

* The Android export itself was not built: that needs the 4.5 export templates, the Android build template regenerated for 4.5, and the signing key, none of which belong in this environment.
* Rendering was checked under software OpenGL (xvfb), not on a phone GPU.

## Why 4.5 matters for the release

Google Play requires target API 35, 16 KB page alignment and an AAB. Godot 4.4.1 cannot produce these; 4.5 can. itch.io (Windows + APK) does not need the move.

## To adopt (owner's decision)

1. Install the 4.5 editor and the matching export templates together.
2. Open `godot/` once (re-import), set `config/features` to 4.5, reinstall the Android build template (Project, Install Android Build Template) and set target SDK 35.
3. Export an AAB, then run `tools/test_all.sh` and `tools/test_ui.sh` once more with the 4.5 binary and test the build on the S22.
