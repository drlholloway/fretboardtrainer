import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:test/test.dart';

void main() {
  group('Tuning', () {
    test('standard presets', () {
      expect(Tuning.guitar6Standard.describe(), 'E A D G B E');
      expect(Tuning.guitar7Standard.describe(), 'B E A D G B E');
      expect(Tuning.bass4Standard.describe(), 'E A D G');
      expect(Tuning.bass5Standard.describe(), 'B E A D G');
      expect(Tuning.bass6Standard.describe(), 'B E A D G C');
    });

    test('drop and transposed presets', () {
      expect(Tuning.drop(InstrumentKind.guitar, 6)!.describe(), 'D A D G B E');
      expect(Tuning.drop(InstrumentKind.bass, 4)!.describe(), 'D A D G');
      expect(
          Tuning.drop(InstrumentKind.guitar, 7)!.describe(), 'A E A D G B E');
      expect(Tuning.drop(InstrumentKind.bass, 5), isNull);
      expect(Tuning.byId('c6')!.describe(), 'C F A♯ D♯ G C');
      expect(
          Tuning.byId('eb6')!.describe(Accidentals.flats), 'E♭ A♭ D♭ G♭ B♭ E♭');
    });

    test('presets exist for every supported string count', () {
      for (final k in InstrumentKind.values) {
        for (final n in k.stringCounts) {
          final presets = Tuning.presets(k, n);
          expect(presets, isNotEmpty);
          for (final t in presets) {
            expect(t.stringCount, n, reason: t.id);
            expect(Tuning.byId(t.id), t);
            for (var i = 1; i < n; i++) {
              expect(t.open[i].midi, greaterThan(t.open[i - 1].midi),
                  reason: '${t.id} strings ascend');
            }
          }
        }
      }
    });
  });

  group('Instrument', () {
    final guitar = Instrument.standard(InstrumentKind.guitar);
    final bass = Instrument.standard(InstrumentKind.bass);

    test('pitch at position', () {
      expect(guitar.pitchAt(const FretPosition(0, 0)).name(), 'E2');
      expect(guitar.pitchAt(const FretPosition(0, 5)).name(), 'A2');
      expect(guitar.pitchAt(const FretPosition(5, 12)).name(), 'E5');
      expect(guitar.pitchAt(const FretPosition(4, 1)).name(), 'C4');
      expect(bass.pitchAt(const FretPosition(3, 2)).name(), 'A2');
    });

    test('string numbers count from the highest string', () {
      expect(guitar.stringNumber(0), 6);
      expect(guitar.stringNumber(5), 1);
      expect(guitar.stringIndex(6), 0);
      expect(bass.stringNumber(0), 4);
    });

    test('string labels distinguish duplicate open notes', () {
      expect(guitar.stringLabel(0), 'low E');
      expect(guitar.stringLabel(5), 'high E');
      expect(guitar.stringLabel(1), 'A');
      expect(bass.stringLabel(0), 'E');
      final dadgad = guitar.withTuning(Tuning.byId('dadgad')!);
      expect(dadgad.stringLabel(0), 'low D');
      expect(dadgad.stringLabel(2), 'high D');
      expect(dadgad.stringLabel(5), 'high D');
    });

    test('positions of a pitch class', () {
      final a = guitar.positionsOf(PitchClass.a, maxFret: 12);
      expect(a, contains(const FretPosition(0, 5)));
      expect(a, contains(const FretPosition(1, 0)));
      expect(a, contains(const FretPosition(1, 12)));
      expect(a, contains(const FretPosition(5, 5)));
      expect(a.length, 7);
      final onlyLow =
          guitar.positionsOf(PitchClass.a, maxFret: 12, strings: [0]);
      expect(onlyLow, [const FretPosition(0, 5)]);
    });

    test('default fret counts', () {
      expect(guitar.fretCount, 22);
      expect(bass.fretCount, 20);
      expect(
          Instrument.standard(InstrumentKind.bass, strings: 5).stringCount, 5);
    });
  });
}
