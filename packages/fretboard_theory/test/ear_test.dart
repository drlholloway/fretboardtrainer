import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:test/test.dart';

void main() {
  final guitar = Instrument.standard(InstrumentKind.guitar);

  List<T> ask<T extends Question>(DrillConfig config, [int n = 200]) {
    final gen = DrillGenerator(config, seed: 11);
    return [for (var i = 0; i < n; i++) gen.next() as T];
  }

  test('interval names', () {
    expect(Intervals.name(7), 'perfect fifth');
    expect(Intervals.short(3), 'm3');
    expect(Intervals.name(12), 'octave');
    expect(() => Intervals.name(13), throwsRangeError);
  });

  group('find the note by ear', () {
    test('choices are frets on the played string, the open string too', () {
      final config = DrillConfig(
        instrument: guitar,
        modes: {DrillMode.earNote},
        strings: {0},
        maxFret: 5,
      );
      final asked = <int>{};
      for (final q in ask<EarNoteQuestion>(config)) {
        asked.add(q.position.fret);
        expect(q.answer, q.position);
        expect(q.reference, const FretPosition(0, 0));
        expect(q.choices, hasLength(4));
        expect(q.choices.toSet(), hasLength(4));
        for (final c in q.choices) {
          expect(c.string, 0);
          expect(c.fret, inInclusiveRange(0, 5));
        }
        // Left to right along the string.
        final frets = [for (final c in q.choices) c.fret];
        expect(frets, [...frets]..sort());
      }
      // The open string itself is one of the answers ("E, then E").
      expect(asked, {0, 1, 2, 3, 4, 5});
      final same = EarNoteQuestion(
        instrument: guitar,
        position: const FretPosition(0, 0),
        choices: const [FretPosition(0, 0)],
        correctIndex: 0,
      );
      expect(
        same.explain(Accidentals.sharps),
        'That was E again: the open low E string both times.',
      );
    });

    test('explains the jump from the open string', () {
      final q = EarNoteQuestion(
        instrument: guitar,
        position: const FretPosition(0, 7),
        choices: const [FretPosition(0, 7)],
        correctIndex: 0,
      );
      expect(
        q.explain(Accidentals.sharps),
        'That was B, fret 7 on the low E string: a perfect fifth above the '
        'open string.',
      );
      expect(q.statKey, 'earNote:0:7');
    });
  });

  group('open strings by ear', () {
    test('choices are the lesson strings, lowest first', () {
      final config = DrillConfig(
        instrument: guitar,
        modes: {DrillMode.earString},
        strings: {0, 1, 2},
      );
      final asked = <int>{};
      for (final q in ask<EarStringQuestion>(config)) {
        asked.add(q.string);
        expect(q.choices, [0, 1, 2]);
        expect(q.answer, q.string);
        expect(q.statKey, 'earString:${q.string}:0');
      }
      expect(asked, {0, 1, 2});
      final q = ask<EarStringQuestion>(config, 1).single;
      expect(q.explain(Accidentals.sharps), startsWith('That was the open '));
    });

    test('a single string is nothing to choose between', () {
      expect(
        () => DrillGenerator(
          DrillConfig(
            instrument: guitar,
            modes: {DrillMode.earString},
            strings: {3},
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('intervals by ear', () {
    test('asks only the lesson intervals, answered up the same string', () {
      final config = DrillConfig(
        instrument: guitar,
        modes: {DrillMode.earInterval},
        strings: {0, 1},
        intervals: {5, 7, 12},
      );
      final seen = <int>{};
      for (final q in ask<EarIntervalQuestion>(config)) {
        seen.add(q.semitones);
        expect({5, 7, 12}, contains(q.semitones));
        expect(
            q.answer, FretPosition(q.root.string, q.root.fret + q.semitones));
        expect(q.choices, hasLength(4));
        expect(q.choices.toSet(), hasLength(4));
        for (final c in q.choices) {
          expect(c.string, q.root.string);
          expect(c.fret, greaterThan(q.root.fret));
          expect(c.fret, lessThanOrEqualTo(12));
        }
      }
      expect(seen, {5, 7, 12});
    });

    test('octaves start on the open string; stats key on the interval', () {
      final config = DrillConfig(
        instrument: guitar,
        modes: {DrillMode.earInterval},
        strings: {0},
        intervals: {12},
      );
      for (final q in ask<EarIntervalQuestion>(config, 20)) {
        expect(q.root.fret, 0);
        expect(q.statKey, 'earInterval:12');
      }
    });
  });

  group('ear path', () {
    for (final (kind, n) in [
      (InstrumentKind.guitar, 6),
      (InstrumentKind.guitar, 7),
      (InstrumentKind.bass, 4),
      (InstrumentKind.bass, 5),
    ]) {
      test('${kind.name} $n: its own units, apart from the fretboard path', () {
        final c = Curriculum(kind, n);
        final ear = c.lessonsIn(Track.ear);
        expect(c.unitsIn(Track.ear).map((u) => u.title), [
          'The open strings',
          'Find the note by ear',
          'Octaves, fifths and fourths',
        ]);
        // Lower half, upper half, then every string.
        final open = c.unitsIn(Track.ear).first.lessons;
        expect(
          open[0].strings!.length + open[1].strings!.length,
          n,
        );
        expect(open[2].strings, hasLength(n));
        for (final l in ear) {
          expect(l.isEar, isTrue);
          expect(c.trackOf(l), Track.ear);
          expect(l.id, contains('-ear-'));
        }
        expect(c.lessonsIn(Track.fretboard).any((l) => l.isEar), isFalse);
        expect(
          c.lessons,
          hasLength(
            c.lessonsIn(Track.fretboard).length + c.lessonsIn(Track.ear).length,
          ),
        );
      });
    }

    test('teach cards play examples on the lesson string', () {
      final c = Curriculum(InstrumentKind.guitar, 6);
      final strings =
          c.lessonById('g6-ear-open-a')!.teach().single as EarTeachCard;
      expect([
        for (final e in strings.examples) e.label
      ], [
        'Low E',
        'A',
        'D',
      ]);
      expect(strings.examples.first.reference, isNull);

      final card =
          c.lessonById('g6-ear-find-a')!.teach().single as EarTeachCard;
      expect(card.string, 0);
      expect(
        [for (final e in card.examples) e.target.fret],
        [0, 1, 2, 3, 4, 5],
      );
      expect(card.examples.first.label, 'Open · E');
      expect(card.examples.first.reference, const FretPosition(0, 0));

      final fifths = c.lessonById('g6-ear-intervals-a')!.teach();
      expect(fifths.map((t) => t.title), ['Perfect fifth', 'Octave']);
      final octave = fifths.last as EarTeachCard;
      expect(octave.examples.single.label, 'E → E');
    });
  });
}
