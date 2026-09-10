import 'package:meta/meta.dart';

import 'chords.dart';
import 'drills.dart';
import 'instrument.dart';
import 'pitch.dart';

/// Something shown before the questions of a lesson.
sealed class TeachCard {
  const TeachCard({required this.title, required this.body});
  final String title;
  final String body;
}

/// Shows one string with its notes labelled over a fret range.
class StringTeachCard extends TeachCard {
  const StringTeachCard({
    required super.title,
    required super.body,
    required this.string,
    required this.minFret,
    required this.maxFret,
    required this.naturalsOnly,
  });
  final int string;
  final int minFret;
  final int maxFret;
  final bool naturalsOnly;
}

/// Shows every string with its notes labelled over a fret range.
class FretboardTeachCard extends TeachCard {
  const FretboardTeachCard({
    required super.title,
    required super.body,
    required this.minFret,
    required this.maxFret,
    required this.naturalsOnly,
  });
  final int minFret;
  final int maxFret;
  final bool naturalsOnly;
}

/// Shows one chord voicing with its name.
class ChordTeachCard extends TeachCard {
  const ChordTeachCard({
    required super.title,
    required super.body,
    required this.voicing,
  });
  final ChordVoicing voicing;
}

/// A lesson: some teaching, then a run of questions with a pass mark.
@immutable
class Lesson {
  const Lesson({
    required this.id,
    required this.unitId,
    required this.title,
    required this.subtitle,
    required this.instrument,
    required this.modes,
    this.isTest = false,
    this.questionCount = 10,
    this.passScore = 0.7,
    this.strings,
    this.minFret = 0,
    this.maxFret = 12,
    this.naturalsOnly = false,
    this.chordShapes,
    this.chordCategories = const {},
    this.rootStrings,
    this.maxRootFret = 12,
  });

  final String id;
  final String unitId;
  final String title;
  final String subtitle;

  /// The instrument this lesson is taught on (standard tuning unless the
  /// unit is about another tuning).
  final Instrument instrument;
  final Set<DrillMode> modes;
  final bool isTest;
  final int questionCount;
  final double passScore;

  final Set<int>? strings;
  final int minFret;
  final int maxFret;
  final bool naturalsOnly;

  final List<ChordShape>? chordShapes;
  final Set<ChordCategory> chordCategories;
  final Set<int>? rootStrings;
  final int maxRootFret;

  bool get hasNotes => modes.any((m) => !m.isChord);
  bool get hasChords => modes.any((m) => m.isChord);

  DrillConfig get config => DrillConfig(
        instrument: instrument,
        modes: modes,
        minFret: minFret,
        maxFret: maxFret,
        strings: strings,
        naturalsOnly: naturalsOnly,
        chordShapes: chordShapes,
        chordCategories: chordCategories,
        rootStrings: rootStrings,
        maxRootFret: maxRootFret,
      );

  /// Teaching cards, generated from the lesson spec.
  List<TeachCard> teach([Accidentals acc = Accidentals.sharps]) {
    if (isTest) return const [];
    final cards = <TeachCard>[];
    if (hasNotes) {
      final ss = strings;
      if (ss == null) {
        cards.add(FretboardTeachCard(
          title: naturalsOnly
              ? 'Natural notes, frets $minFret–$maxFret'
              : 'Every note, frets $minFret–$maxFret',
          body: naturalsOnly
              ? 'The same natural notes on every string. Look for the '
                  'landmarks you already know: fret 5 and fret 12, and the '
                  'one-fret gaps at E–F and B–C.'
              : 'Every note on every string. Each string repeats the same '
                  'twelve-note cycle from its open note; fret 12 is the '
                  'octave.',
          minFret: minFret,
          maxFret: maxFret,
          naturalsOnly: naturalsOnly,
        ));
      } else {
        for (final s in ss) {
          cards.add(_stringCard(s, acc));
        }
      }
    }
    if (hasChords) {
      final voicings = config.chordVoicings;
      final seen = <String>{};
      for (final v in voicings) {
        // Movable shapes: show the first few root frets only.
        if (!seen.add(v.shape.id) && v.shape.isMovable) {
          if (voicings
                  .where((o) => o.shape.id == v.shape.id)
                  .toList()
                  .indexOf(v) >=
              3) {
            continue;
          }
        }
        cards.add(_chordCard(v, acc));
      }
    }
    return cards;
  }

  StringTeachCard _stringCard(int s, Accidentals acc) {
    final label = instrument.stringLabel(s, acc);
    final notes = <String>[];
    for (var f = minFret; f <= maxFret; f++) {
      final pc = instrument.pitchAt(FretPosition(s, f)).pitchClass;
      if (naturalsOnly && !pc.isNatural) continue;
      final name = pc.isNatural ? pc.name(acc) : pc.bothNames;
      notes.add(
          f == 0 ? '$name open' : '$name at ${f == 12 ? '12 (octave)' : f}');
    }
    final body = StringBuffer();
    if (naturalsOnly) {
      body.write('Natural notes on the $label string: ${notes.join(', ')}. ');
      body.write('E–F and B–C are one fret apart; every other pair of '
          'natural notes is two frets apart.');
    } else {
      body.write('All notes on the $label string: ${notes.join(', ')}. ');
      body.write('Each fret is one semitone. The notes between the naturals '
          'have two names: a sharp of the note below or a flat of the note above.');
    }
    if (maxFret >= 12) {
      body.write(' Fret 12 sounds the open string an octave up, and the '
          'pattern repeats from there.');
    }
    return StringTeachCard(
      title:
          '${label[0].toUpperCase()}${label.substring(1)} string, frets $minFret–$maxFret',
      body: body.toString(),
      string: s,
      minFret: minFret,
      maxFret: maxFret,
      naturalsOnly: naturalsOnly,
    );
  }

  ChordTeachCard _chordCard(ChordVoicing v, Accidentals acc) {
    final name = v.name.label(acc);
    final body = switch (v.category) {
      ChordCategory.open =>
        '$name (${v.name.longLabel(acc)}): ${v.tab}. Strings marked x are not played.',
      ChordCategory.power =>
        '$name: root on the ${instrument.stringLabel(v.rootString, acc)} string at '
            '${v.rootFret == 0 ? 'the open string' : 'fret ${v.rootFret}'}, plus the fifth'
            '${v.frets.where((f) => f != null).length > 2 ? ' and the octave' : ''}. '
            'The root names the chord; slide the shape to change it.',
      ChordCategory.barre => '$name: ${v.shape.label} with the root on the '
          '${instrument.stringLabel(v.rootString, acc)} string at fret ${v.rootFret}. '
          'Your first finger barres fret ${v.lowestFret} like a movable nut.',
    };
    return ChordTeachCard(title: name, body: body, voicing: v);
  }
}

@immutable
class Unit {
  const Unit({
    required this.id,
    required this.title,
    required this.description,
    required this.lessons,
  });
  final String id;
  final String title;
  final String description;
  final List<Lesson> lessons;
}

/// Builds the Duolingo-style path for an instrument kind and string count.
/// Lessons are taught in standard tuning until the final drop-tuning unit.
class Curriculum {
  Curriculum(this.kind, this.stringCount) : units = _build(kind, stringCount);

  final InstrumentKind kind;
  final int stringCount;
  final List<Unit> units;

  List<Lesson> get lessons => [for (final u in units) ...u.lessons];

  Lesson? lessonById(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  Unit unitOf(Lesson l) => units.firstWhere((u) => u.id == l.unitId);

  static List<Unit> _build(InstrumentKind kind, int strings) {
    final std = Instrument.standard(kind, strings: strings);
    final p = '${kind == InstrumentKind.guitar ? 'g' : 'b'}$strings';
    final notes = {DrillMode.fretToNote, DrillMode.noteToFret};
    final chords = {DrillMode.chordToName, DrillMode.nameToChord};
    final units = <Unit>[];

    // One unit per string, lowest first.
    for (var s = 0; s < strings; s++) {
      final label = std.stringLabel(s);
      final uid = '$p-string$s';
      units.add(Unit(
        id: uid,
        title: 'The $label string',
        description: 'Learn every note on the $label string up to fret 12.',
        lessons: [
          Lesson(
            id: '$uid-a',
            unitId: uid,
            title: 'Naturals, frets 0–5',
            subtitle: 'Open string to the fifth fret',
            instrument: std,
            modes: notes,
            strings: {s},
            maxFret: 5,
            naturalsOnly: true,
            questionCount: 8,
          ),
          Lesson(
            id: '$uid-b',
            unitId: uid,
            title: 'Naturals, frets 5–12',
            subtitle: 'Up to the octave',
            instrument: std,
            modes: notes,
            strings: {s},
            minFret: 5,
            maxFret: 12,
            naturalsOnly: true,
            questionCount: 8,
          ),
          Lesson(
            id: '$uid-c',
            unitId: uid,
            title: 'Sharps and flats',
            subtitle: 'Every note from open to fret 12',
            instrument: std,
            modes: notes,
            strings: {s},
            maxFret: 12,
            questionCount: 10,
          ),
          Lesson(
            id: '$uid-test',
            unitId: uid,
            title: '$label string test',
            subtitle: 'Every note, no hints',
            instrument: std,
            modes: notes,
            strings: {s},
            maxFret: 12,
            isTest: true,
            questionCount: 12,
            passScore: 0.8,
          ),
        ],
      ));
    }

    // Whole fretboard.
    units.add(Unit(
      id: '$p-fretboard',
      title: 'The whole fretboard',
      description: 'Mix every string together.',
      lessons: [
        Lesson(
          id: '$p-fretboard-a',
          unitId: '$p-fretboard',
          title: 'Naturals, all strings',
          subtitle: 'Frets 0–12',
          instrument: std,
          modes: notes,
          naturalsOnly: true,
          questionCount: 12,
        ),
        Lesson(
          id: '$p-fretboard-b',
          unitId: '$p-fretboard',
          title: 'All notes, all strings',
          subtitle: 'Frets 0–12',
          instrument: std,
          modes: notes,
          questionCount: 12,
        ),
        Lesson(
          id: '$p-fretboard-test',
          unitId: '$p-fretboard',
          title: 'Fretboard test',
          subtitle: 'Twenty questions, 80% to pass',
          instrument: std,
          modes: notes,
          isTest: true,
          questionCount: 20,
          passScore: 0.8,
        ),
      ],
    ));

    if (kind == InstrumentKind.guitar) {
      final uid = '$p-open';
      Lesson open(String id, String title, String subtitle,
              List<ChordShape> shapes) =>
          Lesson(
            id: '$uid-$id',
            unitId: uid,
            title: title,
            subtitle: subtitle,
            instrument: std,
            modes: chords,
            chordShapes: shapes,
            questionCount: 8,
          );
      final g = ChordLibrary.openGroups;
      units.add(Unit(
        id: uid,
        title: 'Open chords',
        description: 'The chords every guitarist learns first.',
        lessons: [
          open('major', 'Major chords', 'C, A, G, E and D', g['major']!),
          open('minor', 'Minor chords', 'Am, Em and Dm', g['minor']!),
          open('seventh', 'Seventh chords', 'E7, A7, D7, G7, B7 and C7',
              g['seventh']!),
          open(
              'more',
              'More open chords',
              'Minor sevenths and suspended chords',
              [...g['minor seventh']!, ...g['suspended']!]),
          Lesson(
            id: '$uid-test',
            unitId: uid,
            title: 'Open chord test',
            subtitle: 'All open chords',
            instrument: std,
            modes: chords,
            chordShapes: ChordLibrary.openShapes,
            isTest: true,
            questionCount: 12,
            passScore: 0.8,
          ),
        ],
      ));
    }

    // Power chords (guitar and bass).
    {
      final uid = '$p-power';
      units.add(Unit(
        id: uid,
        title: 'Power chords',
        description: 'Root and fifth, movable anywhere on the neck.',
        lessons: [
          Lesson(
            id: '$uid-a',
            unitId: uid,
            title: 'Root on the ${std.stringLabel(0)} string',
            subtitle: 'Frets 0–12',
            instrument: std,
            modes: chords,
            chordCategories: const {ChordCategory.power},
            rootStrings: const {0},
            questionCount: 8,
          ),
          Lesson(
            id: '$uid-b',
            unitId: uid,
            title: 'Root on the ${std.stringLabel(1)} string',
            subtitle: 'Frets 0–12',
            instrument: std,
            modes: chords,
            chordCategories: const {ChordCategory.power},
            rootStrings: const {1},
            questionCount: 8,
          ),
          Lesson(
            id: '$uid-test',
            unitId: uid,
            title: 'Power chord test',
            subtitle: 'Both root strings',
            instrument: std,
            modes: chords,
            chordCategories: const {ChordCategory.power},
            rootStrings: const {0, 1},
            isTest: true,
            questionCount: 12,
            passScore: 0.8,
          ),
        ],
      ));
    }

    if (kind == InstrumentKind.guitar) {
      final uid = '$p-barre';
      final b = ChordLibrary.barreShapes;
      Lesson barre(String id, String title, String subtitle,
              List<ChordShape> shapes) =>
          Lesson(
            id: '$uid-$id',
            unitId: uid,
            title: title,
            subtitle: subtitle,
            instrument: std,
            modes: chords,
            chordShapes: shapes,
            questionCount: 8,
          );
      units.add(Unit(
        id: uid,
        title: 'Barre chords',
        description: 'Open shapes moved up the neck.',
        lessons: [
          barre('e', 'E shape', 'Major and minor, root on the low E string',
              [b[0], b[1]]),
          barre('a', 'A shape', 'Major and minor, root on the A string',
              [b[3], b[4]]),
          barre('7', 'Seventh shapes', 'E7 and A7 shapes', [b[2], b[5]]),
          Lesson(
            id: '$uid-test',
            unitId: uid,
            title: 'Barre chord test',
            subtitle: 'All shapes, frets 1–12',
            instrument: std,
            modes: chords,
            chordShapes: b,
            isTest: true,
            questionCount: 12,
            passScore: 0.8,
          ),
        ],
      ));
    }

    // Drop tuning: the lowest string is retuned, so learn it again.
    final drop = Tuning.drop(kind, strings);
    if (drop != null) {
      final inst = std.withTuning(drop);
      final uid = '$p-drop';
      final label = inst.stringLabel(0);
      units.add(Unit(
        id: uid,
        title: drop.name,
        description: 'The lowest string tuned down a whole step to $label.',
        lessons: [
          Lesson(
            id: '$uid-a',
            unitId: uid,
            title: 'Notes on the $label string',
            subtitle: 'Every note, frets 0–12',
            instrument: inst,
            modes: notes,
            strings: const {0},
            questionCount: 10,
          ),
          Lesson(
            id: '$uid-b',
            unitId: uid,
            title: '${drop.name} power chords',
            subtitle: 'One finger across the two lowest strings',
            instrument: inst,
            modes: chords,
            chordCategories: const {ChordCategory.power},
            rootStrings: const {0},
            questionCount: 8,
          ),
          Lesson(
            id: '$uid-test',
            unitId: uid,
            title: '${drop.name} test',
            subtitle: 'Notes and power chords',
            instrument: inst,
            modes: {...notes, ...chords},
            strings: const {0},
            chordCategories: const {ChordCategory.power},
            rootStrings: const {0},
            isTest: true,
            questionCount: 12,
            passScore: 0.8,
          ),
        ],
      ));
    }
    return units;
  }
}
