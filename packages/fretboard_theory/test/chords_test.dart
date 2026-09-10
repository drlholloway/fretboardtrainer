import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:test/test.dart';

void main() {
  final guitar = Instrument.standard(InstrumentKind.guitar);
  final bass = Instrument.standard(InstrumentKind.bass);

  group('identifyChord', () {
    test('triads and sevenths', () {
      ChordName? id(List<String> names) =>
          identifyChord(names.map(Pitch.parse));
      expect(id(['E2', 'B2', 'E3', 'G#3', 'B3', 'E4'])!.label(), 'E');
      expect(id(['A2', 'E3', 'A3', 'C4', 'E4'])!.label(), 'Am');
      expect(id(['E2', 'B2', 'D3', 'G#3', 'B3', 'E4'])!.label(), 'E7');
      expect(id(['E2', 'B2', 'E3'])!.label(), 'E5');
      expect(id(['G2', 'B2', 'D3', 'F#3'])!.label(), 'Gmaj7');
      expect(id(['A2', 'E3', 'G3', 'C4'])!.label(), 'Am7');
      expect(id(['B2', 'D3', 'F3'])!.label(), 'Bdim');
      expect(id(['C3', 'E3', 'G#3'])!.label(), 'Caug');
      expect(id(['C3', 'E3', 'G3', 'A3'])!.label(), 'Am7/C');
      expect(id(['C3', 'E3', 'A#3'])!.label(), 'C7');
      expect(id(['C3', 'C#3', 'D3']), isNull);
      expect(id([]), isNull);
    });

    test('slash bass when the root is not lowest', () {
      final c = identifyChord(['E2', 'C3', 'E3', 'G3'].map(Pitch.parse))!;
      expect(c.label(), 'C/E');
      expect(c.withoutBass.label(), 'C');
    });

    test('sus ambiguity resolved by the bass', () {
      expect(
          identifyChord(['A2', 'E3', 'B3'].map(Pitch.parse))!.label(), 'Asus2');
      expect(
          identifyChord(['E2', 'A2', 'B2'].map(Pitch.parse))!.label(), 'Esus4');
    });

    test('flat spelling', () {
      final bb = identifyChord(['A#2', 'D3', 'F3'].map(Pitch.parse))!;
      expect(bb.label(Accidentals.flats), 'B♭');
      expect(bb.longLabel(Accidentals.flats), 'B♭ major');
    });
  });

  group('open shapes', () {
    test('resolve to the classic fingerings and names', () {
      final expected = {
        'open-c': ('C', 'x32010'),
        'open-a': ('A', 'x02220'),
        'open-g': ('G', '320003'),
        'open-e': ('E', '022100'),
        'open-d': ('D', 'xx0232'),
        'open-am': ('Am', 'x02210'),
        'open-em': ('Em', '022000'),
        'open-dm': ('Dm', 'xx0231'),
        'open-e7': ('E7', '020100'),
        'open-a7': ('A7', 'x02020'),
        'open-d7': ('D7', 'xx0212'),
        'open-g7': ('G7', '320001'),
        'open-b7': ('B7', 'x21202'),
        'open-c7': ('C7', 'x32310'),
        'open-am7': ('Am7', 'x02010'),
        'open-em7': ('Em7', '020000'),
        'open-dm7': ('Dm7', 'xx0211'),
        'open-asus2': ('Asus2', 'x02200'),
        'open-dsus2': ('Dsus2', 'xx0230'),
        'open-asus4': ('Asus4', 'x02230'),
        'open-dsus4': ('Dsus4', 'xx0233'),
        'open-esus4': ('Esus4', '022200'),
      };
      for (final shape in ChordLibrary.openShapes) {
        final v = shape.resolveOpen(guitar);
        expect(v, isNotNull, reason: shape.id);
        final (name, tab) = expected[shape.id]!;
        expect(v!.name.label(), name, reason: shape.id);
        expect(v.tab, tab, reason: shape.id);
        expect(v.name.bass, isNull, reason: '${shape.id} root in the bass');
      }
      expect(ChordLibrary.openGroups.values.expand((g) => g).length,
          ChordLibrary.openShapes.length);
    });

    test('follow the tuning: E shape in drop D', () {
      final dropD = guitar.withTuning(Tuning.byId('dropd6')!);
      final e = ChordLibrary.openShapes.firstWhere((s) => s.id == 'open-e');
      final v = e.resolveOpen(dropD)!;
      expect(v.tab, '222100');
      expect(v.name.label(), 'E');
      final g = ChordLibrary.openShapes.firstWhere((s) => s.id == 'open-g');
      expect(g.resolveOpen(dropD)!.tab, '520003');
      final c = ChordLibrary.openShapes.firstWhere((s) => s.id == 'open-c');
      expect(c.resolveOpen(dropD)!.tab, 'x32010');
    });

    test('shift names in a transposed tuning', () {
      final eb = guitar.withTuning(Tuning.byId('eb6')!);
      final c = ChordLibrary.openShapes.firstWhere((s) => s.id == 'open-c');
      final v = c.resolveOpen(eb)!;
      expect(v.tab, 'x32010');
      expect(v.name.label(), 'B');
      final cStd = guitar.withTuning(Tuning.byId('c6')!);
      expect(c.resolveOpen(cStd)!.name.label(), 'G♯');
      expect(c.resolveOpen(cStd)!.name.label(Accidentals.flats), 'A♭');
      expect(c.resolveOpen(cStd)!.name.label(Accidentals.sharps), 'G♯');
    });
  });

  group('barre shapes', () {
    test('E shape at fret 1 is F', () {
      final v = ChordLibrary.barreShapes[0].resolve(guitar, 1)!;
      expect(v.tab, '133211');
      expect(v.name.label(), 'F');
      expect(v.lowestFret, 1);
      expect(v.highestFret, 3);
    });

    test('A shape minor at fret 5 is Dm', () {
      final v = ChordLibrary.barreShapes[4].resolve(guitar, 5)!;
      expect(v.tab, 'x57765');
      expect(v.name.label(), 'Dm');
    });

    test('seventh shapes', () {
      expect(
          ChordLibrary.barreShapes[2].resolve(guitar, 3)!.name.label(), 'G7');
      expect(
          ChordLibrary.barreShapes[5].resolve(guitar, 2)!.name.label(), 'B7');
    });

    test('unplayable frets are rejected', () {
      expect(ChordLibrary.barreShapes[0].resolve(guitar, 21), isNull);
      expect(ChordLibrary.barreShapes[0].resolve(guitar, -1), isNull);
    });

    test('shapes keep their intervals in other tunings', () {
      final dadgad = guitar.withTuning(Tuning.byId('dadgad')!);
      final v = ChordLibrary.barreShapes[0].resolve(dadgad, 1)!;
      expect(v.tab, '111011');
      expect(v.name.label(Accidentals.flats), 'E♭');
    });
  });

  group('power chords', () {
    test('guitar has root, fifth and octave', () {
      final shape = ChordLibrary.powerShape(guitar, 0);
      final g5 = shape.resolve(guitar, 3)!;
      expect(g5.tab, '355xxx');
      expect(g5.name.label(), 'G5');
      final c5 = ChordLibrary.powerShape(guitar, 1).resolve(guitar, 3)!;
      expect(c5.tab, 'x355xx');
      expect(c5.name.label(), 'C5');
    });

    test('bass has root and fifth', () {
      final v =
          ChordLibrary.powerShape(bass, 0, octave: false).resolve(bass, 5)!;
      expect(v.tab, '57xx');
      expect(v.name.label(), 'A5');
    });

    test('drop D is a one-finger shape', () {
      final dropD = guitar.withTuning(Tuning.byId('dropd6')!);
      final v = ChordLibrary.powerShape(dropD, 0).resolve(dropD, 5)!;
      expect(v.tab, '555xxx');
      expect(v.name.label(), 'G5');
    });
  });

  group('ChordLibrary.voicings', () {
    test('guitar has all categories', () {
      final all = ChordLibrary.voicings(guitar);
      expect(all.where((v) => v.category == ChordCategory.open).length, 22);
      expect(
          all.where((v) => v.category == ChordCategory.power).length, 3 * 13);
      expect(
          all.where((v) => v.category == ChordCategory.barre).length, 6 * 12);
      for (final v in all) {
        expect(v.frets.length, 6, reason: v.id);
        expect(v.pitches, isNotEmpty);
      }
    });

    test('bass only has power chords', () {
      final all = ChordLibrary.voicings(bass);
      expect(all, isNotEmpty);
      expect(all.every((v) => v.category == ChordCategory.power), isTrue);
      expect(all.every((v) => v.frets.length == 4), isTrue);
    });

    test('seven-string guitar mutes the low B for open shapes', () {
      final seven = Instrument.standard(InstrumentKind.guitar, strings: 7);
      final open =
          ChordLibrary.voicings(seven, categories: {ChordCategory.open});
      expect(open.length, 22);
      final c = open.firstWhere((v) => v.shape.id == 'open-c');
      expect(c.tab, 'xx32010');
      expect(c.rootString, 2);
      expect(c.name.label(), 'C');
      final barre =
          ChordLibrary.voicings(seven, categories: {ChordCategory.barre});
      expect(barre.first.tab, 'x133211');
      final power =
          ChordLibrary.voicings(seven, categories: {ChordCategory.power});
      expect(power.first.tab, '022xxxx');
      expect(power.first.name.label(), 'B5');
    });

    test('explicit shapes resolve on a seven-string', () {
      final seven = Instrument.standard(InstrumentKind.guitar, strings: 7);
      final open =
          ChordLibrary.resolveShapes(seven, ChordLibrary.openGroups['major']!);
      expect(open.map((v) => v.tab),
          ['xx32010', 'xx02220', 'x320003', 'x022100', 'xxx0232']);
      final barre = ChordLibrary.resolveShapes(
          seven, [ChordLibrary.barreShapes[0]],
          maxRootFret: 2);
      expect(barre.map((v) => v.name.label()), ['F', 'F♯']);
      final power = ChordLibrary.resolveShapes(
          seven, [ChordLibrary.powerShape(seven, 0)],
          maxRootFret: 1);
      expect(power.map((v) => v.tab), ['022xxxx', '133xxxx']);
    });

    test('root string filter', () {
      final v = ChordLibrary.voicings(
        guitar,
        categories: {ChordCategory.power},
        rootStrings: [1],
      );
      expect(v.every((x) => x.rootString == 1), isTrue);
      expect(v.length, 13);
    });
  });
}
