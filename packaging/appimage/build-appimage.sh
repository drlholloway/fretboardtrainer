#!/bin/sh
# Wraps the Flutter Linux release bundle as an AppImage.
#   packaging/appimage/build-appimage.sh <bundle dir> <version> [output dir]
# Needs appimagetool on PATH (or APPIMAGETOOL pointing at it). GTK 3 is
# expected from the host, as is usual for Flutter AppImages.
set -eu
BUNDLE="$1"; VERSION="$2"; OUT="${3:-.}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOOL="${APPIMAGETOOL:-appimagetool}"
APPDIR="$(mktemp -d)/Fretman.AppDir"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/512x512/apps" "$APPDIR/usr/share/metainfo"
cp -r "$BUNDLE/." "$APPDIR/usr/bin/"
install -m755 "$ROOT/packaging/appimage/AppRun" "$APPDIR/AppRun"
install -m644 "$ROOT/packaging/appimage/fretman.desktop" "$APPDIR/usr/share/applications/fretman.desktop"
install -m644 "$ROOT/packaging/appimage/fretman.desktop" "$APPDIR/fretman.desktop"
install -m644 "$ROOT/apps/fretboard_trainer/assets/icon/icon_512.png" "$APPDIR/usr/share/icons/hicolor/512x512/apps/fretman.png"
install -m644 "$ROOT/apps/fretboard_trainer/assets/icon/icon_512.png" "$APPDIR/fretman.png"
install -m644 "$ROOT/packaging/flatpak/dev.laneholloway.Fretman.metainfo.xml" "$APPDIR/usr/share/metainfo/fretman.appdata.xml"
mkdir -p "$OUT"
ARCH=x86_64 VERSION="$VERSION" "$TOOL" --appimage-extract-and-run -n "$APPDIR" "$OUT/fretboardtrainer-linux-x64-$VERSION.AppImage" 2>/dev/null \
  || ARCH=x86_64 VERSION="$VERSION" "$TOOL" -n "$APPDIR" "$OUT/fretboardtrainer-linux-x64-$VERSION.AppImage"
ls -la "$OUT"/fretboardtrainer-linux-x64-"$VERSION".AppImage
