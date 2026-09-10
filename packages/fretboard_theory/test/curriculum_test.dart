import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:test/test.dart';

void main() {
  group('Curriculum', () {
    test('guitar path follows the README order', () {
      final c = Curriculum(InstrumentKind.guitar, 6);
      expect(c.units.map((u) => u.title), [
        'The low E string',
        'The A string',
        'The D string',
        'The G string',
        'The B string',
        'The high E string',
        'The whole fretboard',
        'Open chords',
        'Power chords',
        'Barre chords',
        'Drop D',
      ]);
    });

    test('bass path skips open and barre chords', () {
      final c = Curriculum(InstrumentKind.bass, 4);
      expect(c.units.map((u) => u.title), [
        'The E string',
        'The A string',
        'The D string',
        'The G string',
        'The whole fretboard',
        'Power chords',
        'Drop D',
      ]);
    });

    test('five-string bass has no drop unit', () {
      final c = Curriculum(InstrumentKind.bass, 5);
      expect(c.units.last.title, 'Power chords');
      expect(c.units.first.title, 'The B string');
    });

    test('seven-string guitar ends in drop A', () {
      final c = Curriculum(InstrumentKind.guitar, 7);
      expect(c.units.last.title, 'Drop A');
      expect(c.units.last.lessons.first.instrument.tuning.describe(),
          'A E A D G B E');
    });

    test('ids are unique and resolvable', () {
      for (final k in InstrumentKind.values) {
        for (final n in k.stringCounts) {
          final c = Curriculum(k, n);
          final ids = c.lessons.map((l) => l.id).toList();
          expect(ids.toSet().length, ids.length);
          for (final l in c.lessons) {
            expect(c.lessonById(l.id), same(l));
            expect(c.unitOf(l).id, l.unitId);
          }
        }
      }
    });

    test('every lesson can generate its questions and teach cards', () {
      for (final k in InstrumentKind.values) {
        for (final n in k.stringCounts) {
          final c = Curriculum(k, n);
          for (final l in c.lessons) {
            final g = DrillGenerator(l.config, seed: 1);
            for (var i = 0; i < l.questionCount; i++) {
              final q = g.next();
              expect(q.choiceCount, greaterThanOrEqualTo(2), reason: l.id);
            }
            final cards = l.teach();
            if (l.isTest) {
              expect(cards, isEmpty, reason: l.id);
            } else {
              expect(cards, isNotEmpty, reason: l.id);
              for (final card in cards) {
                expect(card.title, isNotEmpty);
                expect(card.body, isNotEmpty);
              }
            }
          }
        }
      }
    });

    test('string lesson teach card lists the notes', () {
      final c = Curriculum(InstrumentKind.guitar, 6);
      final card = c.lessons.first.teach().single as StringTeachCard;
      expect(card.title, 'Low E string, frets 0–5');
      expect(card.body, contains('E open, F at 1, G at 3, A at 5'));
      expect(card.naturalsOnly, isTrue);
    });

    test('whole-fretboard lessons teach with a fretboard card', () {
      final c = Curriculum(InstrumentKind.bass, 4);
      final l = c.lessonById('b4-fretboard-a')!;
      final card = l.teach().single as FretboardTeachCard;
      expect(card.naturalsOnly, isTrue);
      expect(card.maxFret, 12);
    });

    test('drop unit lessons use the drop tuning', () {
      final c = Curriculum(InstrumentKind.guitar, 6);
      final drop = c.units.last;
      for (final l in drop.lessons) {
        expect(l.instrument.tuning.id, 'dropd6');
      }
      final test = drop.lessons.last;
      expect(test.hasNotes, isTrue);
      expect(test.hasChords, isTrue);
      final chordCard = drop.lessons[1].teach().first as ChordTeachCard;
      expect(chordCard.voicing.tab, '000xxx');
      expect(chordCard.voicing.name.label(), 'D5');
    });
  });
}
