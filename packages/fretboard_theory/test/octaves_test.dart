import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:test/test.dart';

void main() {
  final guitar = Instrument.standard(InstrumentKind.guitar);
  final bass = Instrument.standard(InstrumentKind.bass);

  group('OctaveShape', () {
    test('standard guitar has the classic shapes', () {
      final all = OctaveShape.all(guitar);
      expect(all, contains(const OctaveShape(source: 0, target: 2, offset: 2)));
      expect(all, contains(const OctaveShape(source: 1, target: 3, offset: 2)));
      expect(all, contains(const OctaveShape(source: 2, target: 4, offset: 3)));
      expect(all, contains(const OctaveShape(source: 3, target: 5, offset: 3)));
      expect(
          all, contains(const OctaveShape(source: 0, target: 3, offset: -3)));
      expect(
          all, contains(const OctaveShape(source: 1, target: 4, offset: -2)));
      expect(all, contains(const OctaveShape(source: 0, target: 5, offset: 0)));
      expect(
          all, contains(const OctaveShape(source: 2, target: 5, offset: -2)));
      // A→e and E→B would need a five-fret stretch and are not taught.
      expect(all.where((s) => s.source == 1 && s.target == 5), isEmpty);
      expect(all.where((s) => s.source == 0 && s.target == 4), isEmpty);
      expect(all.length, 8);
    });

    test('every shape lands on the same note name an octave or two up', () {
      for (final inst in [
        guitar,
        bass,
        Instrument.standard(InstrumentKind.guitar, strings: 7),
        Instrument.standard(InstrumentKind.bass, strings: 6),
        guitar.withTuning(Tuning.byId('dropd6')!),
      ]) {
        for (final s in OctaveShape.all(inst)) {
          for (final f in s.sourceFrets()) {
            final a = inst.pitchAt(FretPosition(s.source, f));
            final b = inst.pitchAt(FretPosition(s.target, s.fretFor(f)!));
            expect(b.pitchClass, a.pitchClass, reason: '$inst $s fret $f');
            expect((b.midi - a.midi) % 12, 0);
            expect(b.midi, greaterThan(a.midi));
          }
        }
      }
    });

    test('bass has the two-up and long-reach shapes', () {
      expect(OctaveShape.all(bass), [
        const OctaveShape(source: 0, target: 2, offset: 2),
        const OctaveShape(source: 0, target: 3, offset: -3),
        const OctaveShape(source: 1, target: 3, offset: 2),
      ]);
    });

    test('describe and label', () {
      const s = OctaveShape(source: 0, target: 2, offset: 2);
      expect(s.describe(), 'two strings up, two frets higher');
      expect(s.label(guitar), 'low E string → D string');
      expect(const OctaveShape(source: 0, target: 3, offset: -3).describe(),
          'three strings up, three frets back');
      expect(const OctaveShape(source: 0, target: 5, offset: 0).describe(),
          'five strings up, same fret');
      expect(s.fretFor(10), 12);
      expect(s.fretFor(11), isNull);
      expect(
          const OctaveShape(source: 0, target: 3, offset: -3)
              .sourceFrets()
              .first,
          3);
    });
  });

  group('octave drill', () {
    test('questions have one correct target on the right string', () {
      final g = DrillGenerator(
        DrillConfig(instrument: guitar, modes: {DrillMode.octave}),
        seed: 11,
      );
      for (var i = 0; i < 200; i++) {
        final q = g.next() as OctaveQuestion;
        expect(q.choices.length, 4);
        expect(q.choices.toSet().length, 4);
        expect(q.choices.every((p) => p.string == q.shape.target), isTrue);
        final pc = q.pitch.pitchClass;
        for (final (j, p) in q.choices.indexed) {
          expect(guitar.pitchAt(p).pitchClass == pc, j == q.correctIndex);
        }
        expect(q.answer.fret, q.shape.fretFor(q.source.fret));
      }
    });

    test('explanation names the shape', () {
      final g = DrillGenerator(
        DrillConfig(
          instrument: guitar,
          modes: {DrillMode.octave},
          octaveShapes: const [OctaveShape(source: 0, target: 2, offset: 2)],
          minFret: 3,
          maxFret: 3,
        ),
      );
      expect(
        g.next().explain(Accidentals.sharps),
        'G on the low E string at fret 3 is fret 5 on the D string: '
        'two strings up, two frets higher.',
      );
    });

    test('naturals-only restricts the source notes', () {
      final g = DrillGenerator(
        DrillConfig(
          instrument: guitar,
          modes: {DrillMode.octave},
          naturalsOnly: true,
        ),
        seed: 2,
      );
      for (var i = 0; i < 50; i++) {
        expect((g.next() as OctaveQuestion).pitch.pitchClass.isNatural, isTrue);
      }
    });
  });

  group('octave unit', () {
    test('sits after the two lowest strings on guitar', () {
      final c = Curriculum(InstrumentKind.guitar, 6);
      expect(c.units[2].title, 'Octave shapes');
      expect(c.units[2].lessons.map((l) => l.title), [
        'Two strings up, 2 frets higher',
        'Two strings up, 3 frets higher',
        'The long reaches',
        'Octave shapes test',
      ]);
      expect(c.units[2].lessons[0].subtitle,
          'low E string → D string · A string → G string');
      expect(c.units[3].title, 'The D string');
      final cards = c.units[2].lessons[0].teach();
      expect(cards.length, 2);
      final card = cards.first as OctaveTeachCard;
      expect(card.title, 'Low E string → D string');
      expect(card.exampleFrets, [0, 5, 10]);
      expect(
          card.body,
          contains(
              'E open on the low E string is E at fret 2 on the D string'));
    });

    test('bass has no B-string lesson', () {
      final c = Curriculum(InstrumentKind.bass, 4);
      expect(c.units[2].title, 'Octave shapes');
      expect(c.units[2].lessons.map((l) => l.title), [
        'Two strings up, 2 frets higher',
        'The long reaches',
        'Octave shapes test',
      ]);
    });
  });
}
