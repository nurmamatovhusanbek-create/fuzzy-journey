#!/bin/bash
# Builds the release packages for itch.io and checks them. Usage: tools/build_release.sh [windows] [android] [linux]   (no argument = windows android)
# Android signing (never commit these): TB_KEYSTORE=/path/terrabellum-release.keystore  TB_KEYSTORE_PASS=...  [TB_KEYSTORE_ALIAS=terrabellum]
# Needs: Godot 4.4.1 with its export templates, JDK 17+, Android SDK (platform-tools, build-tools 34, platforms 34) set in the editor settings, zip.
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
VERSION=$(grep -oP '(?<=config/version=")[^"]+' godot/project.godot)
OUT=build/dist; mkdir -p "$OUT" build/windows build/android build/linux
targets=${@:-windows android}
unset XDG_DATA_HOME                                   # the export templates live in the default Godot data folder
(cd godot && "$GODOT" --headless --path . --import >/dev/null 2>&1) || true

export_one() { (cd godot && "$GODOT" --headless --path . --export-release "$1" "$2" 2>&1 | grep -aE "ERROR|Signed|export: end" | grep -v "status < 0" ) || true; }

for t in $targets; do
  case $t in
  windows)
    rm -f build/windows/TerraBellum.exe
    export_one "Windows Desktop" ../build/windows/TerraBellum.exe
    [ -s build/windows/TerraBellum.exe ] || { echo "!! windows export failed"; exit 1; }
    rm -f "$OUT/TerraBellum-$VERSION-windows.zip"
    (cd build/windows && cp ../../docs/itch/README_WINDOWS.txt . 2>/dev/null; zip -q -9 "../../$OUT/TerraBellum-$VERSION-windows.zip" TerraBellum.exe $( [ -f README_WINDOWS.txt ] && echo README_WINDOWS.txt ))
    echo "windows: $OUT/TerraBellum-$VERSION-windows.zip";;
  android)
    : "${TB_KEYSTORE:?set TB_KEYSTORE (release keystore path)}"; : "${TB_KEYSTORE_PASS:?set TB_KEYSTORE_PASS}"
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$TB_KEYSTORE" GODOT_ANDROID_KEYSTORE_RELEASE_USER="${TB_KEYSTORE_ALIAS:-terrabellum}" GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$TB_KEYSTORE_PASS"
    rm -f build/android/TerraBellum.apk build/android/TerraBellum.apk.idsig
    export_one "Android" ../build/android/TerraBellum.apk
    [ -s build/android/TerraBellum.apk ] || { echo "!! android export failed"; exit 1; }
    BT=$(ls -d "$HOME"/Android/Sdk/build-tools/* | sort -V | tail -1)
    "$BT/apksigner" verify build/android/TerraBellum.apk 2>&1 | grep -v JAVA_TOOL || true
    badge=$("$BT/aapt" dump badging build/android/TerraBellum.apk)
    echo "$badge" | grep -E "^package|sdkVersion|targetSdkVersion|native-code"
    echo "$badge" | grep -q "uses-permission" && echo "!! the APK asks for permissions (multiplayer is off in this release)" || echo "permissions: none"
    cp build/android/TerraBellum.apk "$OUT/TerraBellum-$VERSION-android.apk"
    echo "android: $OUT/TerraBellum-$VERSION-android.apk";;
  linux)
    export_one "Linux" ../build/linux/TerraBellum.x86_64
    (cd build/linux && rm -f "../../$OUT/TerraBellum-$VERSION-linux.zip" && zip -q -9 "../../$OUT/TerraBellum-$VERSION-linux.zip" TerraBellum.x86_64)
    echo "linux: $OUT/TerraBellum-$VERSION-linux.zip";;
  esac
done
(cd "$OUT" && sha256sum TerraBellum-$VERSION-* > SHA256SUMS.txt && cat SHA256SUMS.txt)
