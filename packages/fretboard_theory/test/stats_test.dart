import 'dart:convert';

import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:test/test.dart';

void main() {
  final guitar = Instrument.standard(InstrumentKind.guitar);
  final dropD = guitar.withTuning(Tuning.guitar6[1]);
  final day1 = DateTime(2026, 9, 1, 20);

  Question ask(DrillMode mode, {int seed = 1}) =>
      DrillGenerator(DrillConfig(instrument: guitar, modes: {mode}), seed: seed)
          .next();

  FretToNoteQuestion fretToNote(FretPosition p) => FretToNoteQuestion(
        instrument: guitar,
        position: p,
        choices: [guitar.pitchAt(p)],
        correctIndex: 0,
      );

  group('stat keys', () {
    test('note questions key on the position asked about', () {
      final f2n = ask(DrillMode.fretToNote) as FretToNoteQuestion;
      expect(f2n.statPosition, f2n.position);
      expect(f2n.statKey,
          'fretToNote:${f2n.position.string}:${f2n.position.fret}');
      final n2f = ask(DrillMode.noteToFret) as NoteToFretQuestion;
      expect(n2f.statPosition, n2f.answer);
      final oct = ask(DrillMode.octave) as OctaveQuestion;
      expect(oct.statPosition, oct.answer);
    });

    test('chord questions key on the voicing, whatever the choices', () {
      final c2n = ask(DrillMode.chordToName) as ChordToNameQuestion;
      expect(c2n.statKey, 'chordToName:${c2n.voicing.id}');
      final n2c = ask(DrillMode.nameToChord) as NameToChordQuestion;
      expect(n2c.statVoicing, n2c.answer);
    });

    test('layouts differ by tuning and instrument', () {
      expect(statsLayout(guitar), 'guitar:std6');
      expect(statsLayout(dropD), 'guitar:dropd6');
      expect(
        statsLayout(Instrument.standard(InstrumentKind.bass)),
        isNot(statsLayout(guitar)),
      );
    });
  });

  group('FactStats', () {
    test('counts answers and times only correct, sane ones', () {
      var f = const FactStats();
      f = f.record(correct: true, time: const Duration(seconds: 2), at: day1);
      f = f.record(correct: false, time: const Duration(seconds: 1), at: day1);
      f = f.record(correct: true, time: const Duration(seconds: 4), at: day1);
      f = f.record(correct: true, time: const Duration(minutes: 2), at: day1);
      expect(f.attempts, 4);
      expect(f.correct, 3);
      expect(f.accuracy, 0.75);
      expect(f.averageTime, const Duration(seconds: 3));
      expect(f.lastSeenMs, day1.millisecondsSinceEpoch);
    });

    test('recent accuracy forgets answers beyond the window', () {
      var f = const FactStats();
      for (var i = 0; i < 10; i++) {
        f = f.record(correct: false, time: Duration.zero, at: day1);
      }
      for (var i = 0; i < FactStats.recentWindow; i++) {
        f = f.record(correct: true, time: Duration.zero, at: day1);
      }
      expect(f.accuracy, lessThan(0.5));
      expect(f.recentAccuracy, 1);
      expect(f.recentCount, FactStats.recentWindow);
    });
  });

  group('StatsBook', () {
    test('tallies per layout and key', () {
      final p = const FretPosition(0, 3);
      var book = const StatsBook();
      book = book.record(guitar, fretToNote(p),
          correct: true, time: const Duration(seconds: 1), at: day1);
      book = book.record(guitar, fretToNote(p),
          correct: false, time: const Duration(seconds: 1), at: day1);
      book = book.record(dropD, fretToNote(p),
          correct: true, time: const Duration(seconds: 1), at: day1);
      expect(book.positions(guitar)[p]!.attempts, 2);
      expect(book.positions(dropD)[p]!.attempts, 1);
      expect(book.total.attempts, 3);
      expect(book.positions(guitar, modes: {DrillMode.noteToFret}), isEmpty);
    });

    test('chord tallies sum both chord modes per voicing', () {
      final c2n = ask(DrillMode.chordToName) as ChordToNameQuestion;
      final n2c = NameToChordQuestion(
        target: c2n.voicing.name,
        choices: [c2n.voicing],
        correctIndex: 0,
      );
      var book = const StatsBook();
      book = book.record(guitar, c2n,
          correct: true, time: Duration.zero, at: day1);
      book = book.record(guitar, n2c,
          correct: false, time: Duration.zero, at: day1);
      expect(book.chords(guitar)[c2n.voicing.id]!.attempts, 2);
      expect(book.positions(guitar), isEmpty);
    });

    test('day streak grows on consecutive days and resets after a gap', () {
      final q = fretToNote(const FretPosition(1, 2));
      StatsBook on(StatsBook b, DateTime at) =>
          b.record(guitar, q, correct: true, time: Duration.zero, at: at);
      var book = on(const StatsBook(), day1);
      book = on(book, day1.add(const Duration(hours: 1)));
      expect(book.dayStreak, 1);
      book = on(book, DateTime(2026, 9, 2, 7));
      book = on(book, DateTime(2026, 9, 3, 23));
      expect(book.dayStreak, 3);
      expect(book.currentDayStreak(DateTime(2026, 9, 4, 12)), 3);
      expect(book.currentDayStreak(DateTime(2026, 9, 5, 12)), 0);
      book = on(book, DateTime(2026, 9, 6, 9));
      expect(book.dayStreak, 1);
      expect(book.bestDayStreak, 3);
    });

    test('keeps the best answer streak', () {
      final q = fretToNote(const FretPosition(1, 2));
      var book = const StatsBook();
      book = book.record(guitar, q,
          correct: true, time: Duration.zero, at: day1, answerStreak: 7);
      book = book.record(guitar, q,
          correct: true, time: Duration.zero, at: day1, answerStreak: 3);
      expect(book.bestAnswerStreak, 7);
    });

    test('survives a JSON round trip', () {
      final c2n = ask(DrillMode.chordToName) as ChordToNameQuestion;
      var book = const StatsBook();
      book = book.record(guitar, fretToNote(const FretPosition(2, 5)),
          correct: true,
          time: const Duration(seconds: 2),
          at: day1,
          answerStreak: 4);
      book = book.record(dropD, c2n,
          correct: false, time: Duration.zero, at: day1);
      final back = StatsBook.fromJson(
        jsonDecode(jsonEncode(book.toJson())) as Map<String, Object?>,
      );
      expect(back.toJson(), book.toJson());
      expect(back.positions(guitar)[const FretPosition(2, 5)]!.averageTime,
          const Duration(seconds: 2));
      expect(back.chords(dropD)[c2n.voicing.id]!.attempts, 1);
      expect(back.bestAnswerStreak, 4);
    });
  });
}
