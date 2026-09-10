## What this changes

<!-- One or two sentences. Link the issue it addresses, if any: "Fixes #12". -->

## How it was tested

- [ ] `just test` passes locally (or `dart test` in `packages/fretboard_theory` and `flutter test` in `apps/fretboard_trainer`)
- [ ] `flutter analyze` is clean in `apps/fretboard_trainer`
- [ ] Tried on: <!-- iOS / Android / macOS, or "widget tests only" -->

## Checklist

- [ ] Music-theory changes (chord shapes, tunings, naming) come with a test in `packages/fretboard_theory/test`
- [ ] Lesson ids in `Curriculum` are unchanged, or the change is called out here (they are stored in learner progress)
- [ ] Screens that changed were re-rendered with `just screenshots`
- [ ] `CHANGELOG.md` has a line under **Unreleased** if users would notice this
