import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:test/test.dart';

void main() {
  group('PitchClass', () {
    test('names with sharps and flats', () {
      expect(PitchClass.c.name(), 'C');
      expect(const PitchClass(1).name(), 'C♯');
      expect(const PitchClass(1).name(Accidentals.flats), 'D♭');
      expect(const PitchClass(1).bothNames, 'C♯ / D♭');
      expect(PitchClass.a.isNatural, isTrue);
      expect(const PitchClass(10).isNatural, isFalse);
    });

    test('arithmetic wraps', () {
      expect(PitchClass.b + 1, PitchClass.c);
      expect(PitchClass.c - 1, PitchClass.b);
      expect(PitchClass.e.intervalTo(PitchClass.c), 8);
      expect(PitchClass.c.intervalTo(PitchClass.e), 4);
    });

    test('parse', () {
      expect(PitchClass.parse('C#'), const PitchClass(1));
      expect(PitchClass.parse('Db'), const PitchClass(1));
      expect(PitchClass.parse('e♭'), const PitchClass(3));
      expect(PitchClass.parse('Cb'), PitchClass.b);
      expect(() => PitchClass.parse('H'), throwsFormatException);
    });

    test('spelling', () {
      final s = const PitchClass(10).spell(Accidentals.flats);
      expect(s.letter, 'B');
      expect(s.accidental, -1);
      expect(s.letterStep, 6);
      expect(s.toString(), 'B♭');
    });
  });

  group('Pitch', () {
    test('middle C is 60', () {
      expect(Pitch.of(PitchClass.c, 4).midi, 60);
      expect(const Pitch(60).octave, 4);
      expect(const Pitch(60).name(), 'C4');
      expect(const Pitch(40).name(), 'E2');
      expect(const Pitch(59).name(), 'B3');
    });

    test('parse', () {
      expect(Pitch.parse('E2').midi, 40);
      expect(Pitch.parse('C#4').midi, 61);
      expect(Pitch.parse('Bb3').midi, 58);
    });

    test('staff steps', () {
      expect(const Pitch(60).staffStep(), 28);
      expect(const Pitch(62).staffStep(), 29);
      expect(const Pitch(61).staffStep(), 28); // C♯4
      expect(const Pitch(61).staffStep(Accidentals.flats), 29); // D♭4
    });

    test('ordering', () {
      final list = [const Pitch(64), const Pitch(40), const Pitch(50)]..sort();
      expect(list.map((p) => p.midi), [40, 50, 64]);
    });
  });
}
