# Fretboard Trainer — Project Plan

Android and iOS app for learning the notes and chords on a guitar or bass
fretboard through quick multiple-choice drills and a guided, Duolingo-style
walk-through. See [README.md](README.md) for the product idea.

The layout, tooling and conventions mirror the DCA75 Workbench (Sightings)
project: a pub workspace with a pure-Dart core package that is fully unit
tested, a thin Flutter app on top, Riverpod for state, go_router for
navigation, shared_preferences for settings, a `justfile` and GitHub Actions.

## Layout

```
pubspec.yaml                 Pub workspace root
packages/fretboard_theory/   Pure Dart: pitches, tunings, instruments, chords, drills, curriculum
apps/fretboard_trainer/      Flutter app (iOS, Android; macOS kept as a dev target)
docs/screenshots/            Rendered by `just screenshots`
```

## Phases

| Phase | Outcome | Status |
|---|---|---|
| 0 | Workspace, lints, justfile, CI | done |
| 1 | Theory package: notes, tunings, instruments, chord shapes and naming | done |
| 2 | Drill generation: four question types with sensible distractors | done |
| 3 | Curriculum: per-string units, whole fretboard, open / power / barre chords, drop tuning | done |
| 4 | App: learn path, lesson flow, free drill, settings, progress | done |
| 5 | Polish: sound, timing stats, spaced repetition, more chord families | next |
| 6 | Store release: icons, splash, signing, screenshots | later |

## 1. Theory package (`fretboard_theory`)

- `PitchClass` / `Pitch` (MIDI numbers, C4 = 60), spelled with sharps or flats.
  `staffStep` gives the diatonic position used by the staff widget.
- `Tuning` presets per instrument and string count (guitar 6/7, bass 4/5/6):
  standard, drop, and the whole-step / half-step / two-step transpositions,
  plus DADGAD and open G on six-string.
- `Instrument` = kind + tuning + fret count. Strings are indexed from the
  lowest-pitched string (0); `stringNumber` gives the player's numbering.
- **Chords.** A `ChordShape` stores semitone offsets from the root per string,
  so movable shapes (power chords, E- and A-shape barres) resolve correctly
  in any tuning. Open shapes keep their fingering when the tuning is a uniform
  transposition (E♭, D, C standard) and keep their pitches otherwise (so E in
  drop D becomes `222100`). Every resolved voicing is named from what it
  actually sounds via `identifyChord`, never from a label, so names are right
  in every tuning (slash chords included).
- **Drills.** `DrillGenerator` cycles through the enabled modes and produces
  `Question`s: fret → note, note → fret, chord → name, name → chord.
  Distractors are near neighbors (adjacent semitones, wrong frets on the same
  string, chords sharing a root or quality). Seeded and deterministic.
- **Curriculum.** `Curriculum(kind, strings)` builds the path: one unit per
  string (naturals 0–5, naturals 5–12, sharps and flats, test), the whole
  fretboard, then open chords (guitar), power chords, barre chords (guitar),
  and the drop tuning. Lessons carry their own instrument, so the drop unit
  teaches in drop D while everything else is in standard.

## 2. App (`fretboard_trainer`)

- **Learn** tab: units and lessons, unlocked in order (or all at once from
  Settings). A lesson shows teach cards, then N questions, then a result;
  practice lessons pass at 70%, tests at 80%.
- **Drill** tab: free practice with remembered options (modes, fret range,
  naturals only, strings, chord categories, 10/20/50/endless).
- **Settings**: instrument, string count, tuning, sharps or flats, left-handed,
  theme, unlock-all, reset progress.
- Widgets: `FretboardView` (custom painter, tab-style, nut on the left, lowest
  string at the bottom; mirrors for left-handed players; chord windows),
  `StaffView` (five-line staff with a public-domain treble clef path and a
  hand-drawn bass clef; guitar and bass are drawn an octave up, as written),
  `QuestionView`, `DrillRunner`.
- Progress and settings are JSON / primitives in shared_preferences. No
  backend, no accounts.

## 3. Testing and tooling

- `just test`: 58 theory tests (pitch spelling, tunings, chord naming, shape
  resolution, drill invariants, every lesson generates) and widget tests that
  walk the app.
- `just screenshots`: renders every screen at iPhone size with the system Arial
  fonts into `docs/screenshots/` via golden tests (skipped in CI). Used because
  screen capture and VM-service screenshots are not available in the dev
  sandbox.
- CI (`.github/workflows/test.yml`): analyze + tests on Ubuntu, Android debug
  APK, iOS build without codesign on macOS.
- Debug builds honor `FRETBOARD_ROUTE=/lesson/<id>` to open a screen directly.

## 4. Later

- Audio: play the note or strum the chord on reveal; optional ear-training mode.
- Timing and stats: per-note accuracy heatmap on the fretboard, streaks.
- Spaced repetition on notes the learner misses most.
- More chord families (C, G and D shape barres, triads, inversions) and
  bass-specific arpeggio drills.
- Tab-style rendering option for questions (fret numbers on a tab staff).
- Store assets: icon, splash, privacy policy; iOS simulator runtime for
  device screenshots.
