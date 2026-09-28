import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:test/test.dart';

void main() {
  final guitar = Instrument.standard(InstrumentKind.guitar);
  final bass = Instrument.standard(InstrumentKind.bass);

  List<T> ask<T extends Question>(DrillConfig config, [int n = 300]) {
    final gen = DrillGenerator(config, seed: 5);
    return [for (var i = 0; i < n; i++) gen.next() as T];
  }

  void checkChoices(
    Instrument inst,
    DrillConfig config,
    int midi,
    List<FretPosition> choices,
    Set<int> correct,
  ) {
    final right = config.samePitchPositions(midi).toSet();
    expect(right.length, greaterThanOrEqualTo(2));
    expect(choices.toSet(), hasLength(choices.length));
    expect(choices.length, inInclusiveRange(6, 8));
    // Exactly the places that sound the note are right...
    expect({for (final i in correct) choices[i]}, right);
    // ...and no wrong mark sounds it.
    for (final (i, p) in choices.indexed) {
      if (!correct.contains(i)) {
        expect(inst.pitchAt(p).midi, isNot(midi));
      }
      expect(p.fret, inInclusiveRange(0, 12));
    }
    // Along the neck, left to right.
    final frets = [for (final p in choices) p.fret];
    expect(frets, [...frets]..sort());
  }

  group('see a note, find every place', () {
    for (final inst in [guitar, bass]) {
      test('${inst.kind.name}: every right place, nothing else', () {
        final config = DrillConfig(
          instrument: inst,
          modes: {DrillMode.allPositions},
        );
        var traps = 0;
        for (final q in ask<AllPositionsQuestion>(config)) {
          expect(q.multiSelect, isTrue);
          checkChoices(inst, config, q.target.midi, q.choices, q.correct);
          expect(q.isRightSet(q.correct), isTrue);
          expect(
              q.isRightSet({...q.correct}..remove(q.correct.first)), isFalse);
          // The same name an octave away is the trap to include.
          if (q.choices.any((p) {
            final m = inst.pitchAt(p).midi;
            return m != q.target.midi && (m - q.target.midi) % 12 == 0;
          })) {
            traps++;
          }
        }
        expect(traps, greaterThan(150));
      });
    }

    test('naturals only asks natural notes', () {
      final config = DrillConfig(
        instrument: guitar,
        modes: {DrillMode.allPositions},
        naturalsOnly: true,
      );
      for (final q in ask<AllPositionsQuestion>(config, 100)) {
        expect(q.target.pitchClass.isNatural, isTrue);
      }
    });

    test('explains every place, lowest string first', () {
      final config = DrillConfig(
        instrument: guitar,
        modes: {DrillMode.allPositions},
      );
      // A3: fret 12 on A, fret 7 on D, fret 2 on G.
      final places = config.samePitchPositions(57);
      final q = AllPositionsQuestion(
        instrument: guitar,
        target: const Pitch(57),
        choices: places,
        correct: {for (var i = 0; i < places.length; i++) i},
      );
      expect(
        q.explain(Accidentals.sharps),
        'A here is at fret 12 on the A string, fret 7 on the D string and '
        'fret 2 on the G string.',
      );
      expect(q.statKey, 'allPositions:midi57');
    });
  });

  group('hear a note, find every place', () {
    test('the played place is one of the right ones', () {
      final config = DrillConfig(
        instrument: guitar,
        modes: {DrillMode.earAllPositions},
      );
      for (final q in ask<EarAllPositionsQuestion>(config)) {
        checkChoices(guitar, config, q.target.midi, q.choices, q.correct);
        expect(q.answers, contains(q.source));
        expect(q.reference, FretPosition(q.source.string, 0));
        expect(q.statKey, 'earAllPositions:midi${q.target.midi}');
      }
    });
  });

  group('units', () {
    test('fretboard: right after the whole fretboard', () {
      final units = Curriculum(InstrumentKind.guitar, 6)
          .unitsIn(Track.fretboard)
          .map((u) => u.title)
          .toList();
      expect(
        units.indexOf('Every place a note lives'),
        units.indexOf('The whole fretboard') + 1,
      );
    });

    test('ear: right after finding notes on every string', () {
      final units = Curriculum(InstrumentKind.guitar, 6)
          .unitsIn(Track.ear)
          .map((u) => u.title)
          .toList();
      expect(
        units.indexOf('The same note, other strings'),
        units.indexOf('Find the note by ear') + 1,
      );
    });

    test('teach card: one note in several places, playable', () {
      final c = Curriculum(InstrumentKind.guitar, 6);
      for (final id in ['g6-everywhere-a', 'g6-ear-everywhere-a']) {
        final card = c.lessonById(id)!.teach().single as EarTeachCard;
        expect(card.title, 'One note, several places');
        final pitches = {
          for (final e in card.examples) guitar.pitchAt(e.target).midi,
        };
        expect(pitches, hasLength(1));
        expect(card.examples.length, greaterThanOrEqualTo(2));
      }
    });
  });
}
