# Contributing to Fretboard Trainer

Thanks for your interest. Fretboard Trainer is a small project maintained by one
person, so the most useful contributions are focused ones: a clear bug report
with a screenshot, a musically wrong answer with the notes it should be, a fix
with a test, or a new chord shape with its source.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to help

- **Report a bug.** Use the *Bug report* issue form. Say which instrument and
  tuning were set; most behaviour depends on them.
- **Report a wrong note or chord.** Use the *Wrong note or chord* form. The
  question, the instrument and tuning, and the notes you expected are enough
  to turn it into a test.
- **Suggest a feature.** Use the *Feature request* form. Check the "Later"
  section of `PLAN.md` first; it may already be planned.
- **Add a chord shape** to `ChordLibrary` in
  `packages/fretboard_theory/lib/src/chords.dart`, with a test that pins its
  tab and name in standard tuning.

## Development setup

Requirements: Flutter stable 3.47 or newer. iOS needs Xcode; Android needs
the SDK (platform 36) plus JDK 17 or newer.

```sh
git clone https://github.com/drlholloway/fretboardtrainer.git
cd fretboardtrainer
dart pub get
just test                      # theory tests plus the widget tests
just run-macos                 # or run-ios / run-android
just screenshots               # re-render docs/screenshots after UI changes
```

Without `just`: `dart test` in `packages/fretboard_theory`, and `flutter test`
/ `flutter run` in `apps/fretboard_trainer`.

The layout is described in the README. In short: `fretboard_theory` is pure
Dart with no Flutter (notes, tunings, chords, drills, curriculum) and
`apps/fretboard_trainer` is the Flutter app.

## Pull requests

1. Open an issue first for anything beyond a small fix, so the approach can be
   agreed before you spend time on it.
2. Branch from `main`. Keep a PR to one change.
3. Add or update tests. Theory changes need a test in
   `packages/fretboard_theory/test`.
4. Run `dart format .`, `flutter analyze` in `apps/fretboard_trainer`, and
   `just test`. CI runs the same, plus an Android and an iOS build.
5. Do not rename lesson ids in `Curriculum` without saying so; they are stored
   in learner progress.
6. Add a line under **Unreleased** in `CHANGELOG.md` if users would notice the
   change.
7. Fill in the PR template.

## Style

American spelling in code, UI text and docs. Chord names come from
`identifyChord`, never from a hard-coded label.

## Licensing of contributions

Fretboard Trainer is licensed under [PolyForm Shield 1.0.0](LICENSE). By
submitting a contribution you agree that it is licensed under the same terms
and that Cryptid Effects may include it in any edition of Fretboard Trainer,
including a commercial one. Please do not submit code copied from projects
under incompatible licenses.

## Questions

Open an issue with the *question* label.
