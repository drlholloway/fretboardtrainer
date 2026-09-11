# Fretboard Trainer task runner (https://github.com/casey/just). `just --list`.

set shell := ["bash", "-cu"]
export PATH := "/opt/homebrew/bin:" + env_var("PATH")

app := "apps/fretboard_trainer"

# fetch dependencies for the whole workspace
get:
    dart pub get

# static analysis everywhere
analyze:
    dart analyze
    cd {{app}} && flutter analyze

# run every test suite
test:
    cd packages/fretboard_theory && dart test
    cd {{app}} && flutter test

format:
    dart format .

run-macos:
    cd {{app}} && flutter run -d macos

run-ios:
    cd {{app}} && flutter run -d ios

run-android:
    cd {{app}} && flutter run -d android

run-linux:
    cd {{app}} && flutter run -d linux

build-linux:
    cd {{app}} && flutter build linux --release

# Linux only: wrap the release bundle as an AppImage (needs appimagetool on PATH)
build-appimage VERSION: build-linux
    ./packaging/appimage/build-appimage.sh {{app}}/build/linux/x64/release/bundle {{VERSION}} dist

build-apk:
    cd {{app}} && flutter build apk --release

build-ios:
    cd {{app}} && flutter build ipa --release

# render every screen to docs/screenshots (macOS: uses the system Arial fonts)
screenshots:
    cd {{app}} && SCREENSHOTS=1 flutter test test/screenshots --update-goldens

# redraw the icon masters (uv fetches Pillow) and regenerate every platform's icon set
icons:
    uv run --with pillow packaging/icon/make_icon.py
    cd {{app}} && dart run flutter_launcher_icons
