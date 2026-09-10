import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:test/test.dart';

void main() {
  final guitar = Instrument.standard(InstrumentKind.guitar);
  final bass = Instrument.standard(InstrumentKind.bass);

  group('DrillConfig', () {
    test('note positions honour range, strings and naturals', () {
      final c = DrillConfig(
        instrument: guitar,
        modes: {DrillMode.fretToNote},
        strings: {0},
        maxFret: 5,
        naturalsOnly: true,
      );
      expect(c.notePositions.map((p) => p.fret), [0, 1, 3, 5]);
    });

    test('chord voicings from explicit shapes', () {
      final c = DrillConfig(
        instrument: guitar,
        modes: {DrillMode.chordToName},
        chordShapes: ChordLibrary.openGroups['major'],
      );
      expect(c.chordVoicings.map((v) => v.name.label()),
          ['C', 'A', 'G', 'E', 'D']);
    });
  });

  group('DrillGenerator', () {
    test('fret to note has one correct answer and distinct choices', () {
      final g = DrillGenerator(
        DrillConfig(instrument: guitar, modes: {DrillMode.fretToNote}),
        seed: 1,
      );
      for (var i = 0; i < 200; i++) {
        final q = g.next() as FretToNoteQuestion;
        expect(q.choices.length, 4);
        expect(q.choices.map((p) => p.pitchClass).toSet().length, 4);
        expect(q.answer, guitar.pitchAt(q.position));
        expect(q.isCorrect(q.correctIndex), isTrue);
      }
    });

    test('naturals-only fret to note offers natural choices', () {
      final g = DrillGenerator(
        DrillConfig(
          instrument: guitar,
          modes: {DrillMode.fretToNote},
          naturalsOnly: true,
          strings: {0},
          maxFret: 5,
        ),
        seed: 2,
      );
      for (var i = 0; i < 50; i++) {
        final q = g.next() as FretToNoteQuestion;
        expect(q.choices.every((p) => p.pitchClass.isNatural), isTrue);
        expect(q.position.string, 0);
        expect(q.position.fret, lessThanOrEqualTo(5));
      }
    });

    test('note to fret distractors never sound the target', () {
      final g = DrillGenerator(
        DrillConfig(instrument: guitar, modes: {DrillMode.noteToFret}),
        seed: 3,
      );
      for (var i = 0; i < 200; i++) {
        final q = g.next() as NoteToFretQuestion;
        expect(q.choices.length, 4);
        expect(q.choices.toSet().length, 4);
        for (final (j, p) in q.choices.indexed) {
          final same = guitar.pitchAt(p).pitchClass == q.target.pitchClass;
          expect(same, j == q.correctIndex, reason: 'choice $j of $q');
        }
      }
    });

    test('chord to name choices are distinct labels', () {
      final g = DrillGenerator(
        DrillConfig(instrument: guitar, modes: {DrillMode.chordToName}),
        seed: 4,
      );
      for (var i = 0; i < 200; i++) {
        final q = g.next() as ChordToNameQuestion;
        expect(q.choices.length, 4);
        expect(q.choices.map((n) => n.label()).toSet().length, 4);
        expect(q.answer, q.voicing.name);
      }
    });

    test('small chord pools are topped up with invented names', () {
      final g = DrillGenerator(
        DrillConfig(
          instrument: guitar,
          modes: {DrillMode.chordToName},
          chordShapes: ChordLibrary.openGroups['minor'],
        ),
        seed: 5,
      );
      for (var i = 0; i < 50; i++) {
        final q = g.next() as ChordToNameQuestion;
        expect(q.choices.length, 4);
        expect(q.choices.map((n) => n.label()).toSet().length, 4);
      }
    });

    test('name to chord has exactly one voicing with the target name', () {
      final g = DrillGenerator(
        DrillConfig(instrument: bass, modes: {DrillMode.nameToChord}),
        seed: 6,
      );
      for (var i = 0; i < 100; i++) {
        final q = g.next() as NameToChordQuestion;
        expect(q.choices.length, 4);
        final matches =
            q.choices.where((v) => v.name.label() == q.target.label());
        expect(matches.length, 1);
        expect(q.choices[q.correctIndex].name, q.target);
      }
    });

    test('mixed modes cycle', () {
      final g = DrillGenerator(
        DrillConfig(
          instrument: guitar,
          modes: {DrillMode.fretToNote, DrillMode.chordToName},
        ),
        seed: 7,
      );
      final modes = [for (var i = 0; i < 6; i++) g.next().mode];
      expect(modes, [
        DrillMode.fretToNote,
        DrillMode.chordToName,
        DrillMode.fretToNote,
        DrillMode.chordToName,
        DrillMode.fretToNote,
        DrillMode.chordToName,
      ]);
    });

    test('chord modes are dropped when the instrument has no voicings', () {
      final g = DrillGenerator(
        DrillConfig(
          instrument: bass,
          modes: {DrillMode.fretToNote, DrillMode.chordToName},
          chordCategories: {ChordCategory.open},
        ),
      );
      expect(g.activeModes, [DrillMode.fretToNote]);
    });

    test('empty config throws', () {
      expect(
        () => DrillGenerator(DrillConfig(
          instrument: bass,
          modes: {DrillMode.chordToName},
          chordCategories: {ChordCategory.barre},
        )),
        throwsStateError,
      );
    });

    test('same seed gives the same questions', () {
      final c =
          DrillConfig(instrument: guitar, modes: DrillMode.values.toSet());
      final a = DrillGenerator(c, seed: 42);
      final b = DrillGenerator(c, seed: 42);
      for (var i = 0; i < 20; i++) {
        expect(a.next().promptKey, b.next().promptKey);
      }
    });

    test('explanations mention the answer', () {
      final g = DrillGenerator(
        DrillConfig(
            instrument: guitar,
            modes: {DrillMode.fretToNote},
            strings: {0},
            maxFret: 0),
      );
      expect(g.next().explain(Accidentals.sharps),
          'The low E string at open is E.');
    });
  });
}
