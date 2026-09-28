# Changelog

All notable changes to Fretman (Fretboard Trainer). The section for a tagged version
becomes the GitHub Release notes.

## Unreleased

### Added
- **Every place a note lives**: a new kind of question where more than one
  answer is right. A note is shown (fretboard path) or played (ear path),
  and you select every place on the neck that sounds exactly it, then
  Check. It counts only if you find them all and nothing else; the same
  note name an octave away is there to catch you out. After Check every
  place is played in turn so you hear it is the same note.
  - Fretboard path: a new unit, *Every place a note lives*, right after
    *The whole fretboard* (natural notes, every note, test). If you have
    already passed the whole fretboard it becomes your next lesson;
    everything you have done stays done.
  - Ear path: a new unit, *The same note, other strings*, right after
    *Find the note by ear*.
  - Both question types are in the free drill too.

### Changed
- The Linux AppImage is now `Fretman-<version>-x86_64.AppImage`, named like
  the Sightings one, and carries update information: AppImageUpdate (or
  any tool that reads it) can update it in place from the Releases page.
- **Find the note by ear** now covers every string the same way: frets 0–5,
  then 0–12, from the lowest string to the highest, with the test across
  all of them. Lessons you finished in 0.4.0 stay finished (their ids are
  kept); the new lessons slot in where they belong.

## 0.4.0 — 2026-09-27

### Added
- **Ear training**, a second path on the Learn tab: switch between
  **Fretboard** and **Ear** at the top. You hear notes and answer on the
  fretboard, so each sound is tied to where your hand goes. Guitar and bass
  both get it.
  - *The open strings*: one open string plays; pick which it is. The lower
    strings first, then the higher ones, then all of them, then a test.
  - *Find the note by ear*: the open string plays, then a note on the same
    string, sometimes the open string again; pick the fret, or open. The
    low string frets 0–5, then 0–12, then the next string, then a test.
  - *Octaves, fifths and fourths*: a note you can see plays, then one
    higher on the same string; pick where it is. The fifth and octave
    first, then the fourth, then a test across three strings.

  Every lesson starts with cards where you tap to hear the examples, every
  question has **Play again**, and after you answer the fretboard shows the
  notes and the explanation names the interval.
- The three ear question types (**Hear → String**, **Hear → Fret**, **Hear an
  interval**) are also in the free drill, and spaced repetition brings back
  the strings, frets and intervals you miss.

### Changed
- The Learn tab remembers which path you were on.
- Ear training needs sound: with sound off the Ear path says so and offers
  to turn it on, and on iPhone and iPad it reminds you to check the silent
  switch, since iOS doesn't let apps see it.

## 0.3.0 — 2026-09-22

### Added
- **Sound.** After each answer you hear the note, the two notes of an
  octave shape, or the chord strummed, played on real instruments: a
  classical guitar recorded one string at a time by the University of Iowa
  Electronic Music Studios, so a note sounds like the string it is on, and
  a Jazz bass from Karoryfer Samples. A speaker button replays it after a
  wrong answer. On iPhone it mixes with whatever else is playing and
  follows the silent switch. Settings → Sound turns it off.
- **Stats tab.** Your day streak, your best run of right answers, and the
  fretboard as a heatmap: green where you are solid, red where you miss,
  switchable to how fast you answer. Below it, the notes and chords most
  worth another look. Every answer in lessons and drills counts; stats are
  kept per tuning, stay on the device, and Settings → Reset stats clears
  them.
- **Practice weak spots more.** Within whatever a lesson or drill covers,
  the notes and chords you miss, answer slowly or have not seen in a while
  come up more often, and a miss brings that spot back sooner in the same
  run. On by default; switch it off in Settings.
- **Launch splash.** A random cryptid plays you in each time the app opens,
  never the same one twice in a row: Mothman on lead guitar, Bigfoot on
  bass, Nessie on her own neck, the Jersey Devil on banjo, the Jackalope on
  ukulele and El Chupacabra on acoustic. Tap to skip.
- **Privacy policy** ([PRIVACY.md](https://github.com/drlholloway/fretboardtrainer/blob/main/PRIVACY.md)), linked from Settings →
  About: nothing is collected or sent; settings, progress and stats stay on
  the device.

### Changed
- The iOS and Android launch screens are the night sky of the splash
  instead of white.
- Settings has a new **Practice** section (sound, weak spots, unlocking
  lessons, resetting progress and stats), and About credits the recordings.
- The Linux Flatpak asks for audio access (PulseAudio) for the new sound.

## 0.2.1 — 2026-09-11

### Added
- **Linux** builds on the Releases page: AppImage, Flatpak bundle and tarball
  (x86-64), packaged the same way as Sightings. The window opens phone-sized,
  as on macOS.

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
