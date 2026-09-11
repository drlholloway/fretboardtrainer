# Fretman for Linux (x86-64)

Fretboard Trainer: learn the notes and chords on a guitar or bass fretboard.

This is the plain tarball build. The Releases page also has an AppImage
(`fretboardtrainer-linux-x64-<version>.AppImage`: make it executable and run it)
and a Flatpak bundle (`fretboardtrainer-linux-x64-<version>.flatpak`: brings its
own GTK, installs with `flatpak install --user <file>`).

## Requirements

- A 64-bit Intel/AMD Linux with GTK 3 installed
  (Debian/Ubuntu: `sudo apt install libgtk-3-0`; Fedora: `sudo dnf install gtk3`).

## Install

1. Extract the archive anywhere, e.g. `~/Apps/fretman`.
2. Run `./fretboard_trainer`.

Settings and lesson progress are stored in
`~/.local/share/dev.laneholloway.fretboard_trainer/`.

Help and how-tos: https://github.com/drlholloway/fretboardtrainer/wiki
