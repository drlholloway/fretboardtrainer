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

build-apk:
    cd {{app}} && flutter build apk --release

build-ios:
    cd {{app}} && flutter build ipa --release

# render every screen to docs/screenshots (macOS: uses the system Arial fonts)
screenshots:
    cd {{app}} && SCREENSHOTS=1 flutter test test/screenshots --update-goldens

# redraw the icon masters (needs python3 + Pillow) and regenerate every platform's icon set
icons:
    python3 packaging/icon/make_icon.py
    cd {{app}} && dart run flutter_launcher_icons
