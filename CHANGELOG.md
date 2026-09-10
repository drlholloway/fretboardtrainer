# Changelog

All notable changes to Fretboard Trainer. The section for a tagged version
becomes the GitHub Release notes.

## Unreleased

### Added
- App icon: Mothman on a fretboard, eyes on the twelfth-fret inlays. iOS,
  Android adaptive and macOS icon sets generated from it.

## 0.1.0 — 2026-09-10

First usable build.

### Added
- **Drill**: fret → note, note → fret, chord → name and name → chord questions,
  with fret range, natural-notes-only, string and chord-family filters, and
  10 / 20 / 50 / endless runs.
- **Learn** path: one unit per string (naturals 0–5, naturals 5–12, sharps and
  flats, test), the whole fretboard, open chords, power chords, barre chords
  and drop D. Bass skips the open and barre units. Lessons unlock in order.
- **Settings**: guitar (6 or 7 strings) or bass (4 to 6), tuning presets
  (standard, drop, E♭ / D / C standard, DADGAD, open G), sharps or flats,
  left-handed fretboard, theme, unlock-all, reset progress, tip link.
- Chords are named from the notes they sound, so names stay right in any
  tuning; open shapes keep their pitches in drop tunings (E in drop D is
  `222100`).
- macOS build for development, opening in a phone-sized window.
