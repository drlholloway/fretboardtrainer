# Changelog

All notable changes to Fretman (Fretboard Trainer). The section for a tagged version
becomes the GitHub Release notes.

## Unreleased

## 0.2.0 — 2026-09-11

### Added
- **Octave shapes** unit on the learning path, right after the two lowest
  strings: two strings up and two frets higher (E→D, A→G), three frets higher
  across the B string (D→B, G→E), the long reaches (E→G, A→B, D→E) and the
  same fret on the two E strings. Each lesson shows the shape on the
  fretboard, then asks you to find a note's octave. Bass gets the shapes
  that exist on four strings. The unit is new in the middle of the path;
  existing progress is kept and it simply becomes the next thing to do.
- **Octave shapes** question type in the free drill.
- The Fretman icon on the Learn screen and in Settings → About.
- A [wiki](https://github.com/drlholloway/fretboardtrainer/wiki) with
  installation, first steps, the learning path, drills, chords and tunings,
  settings and troubleshooting.

### Fixed
- **Next lesson** on the result screen now opens the next lesson instead of
  staying on the previous lesson's result.

## 0.1.0 — 2026-09-10

First release. The app is called **Fretman** (subtitle: Fretboard Trainer);
its icon is Mothman on a fretboard, eyes on the twelfth-fret inlays.

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
- Android release builds are signed with the Fretman release key; the
  Android toolchain is Gradle 9.7.1, AGP 9.4.0 and Kotlin 2.4.20.
