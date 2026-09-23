import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:fretboard_trainer/services/sound.dart';

void main() {
  final map = SampleMap.fromJson(
    jsonDecode(File('assets/audio/samples.json').readAsStringSync())
        as Map<String, Object?>,
  );

  test('every position on every tuning has a sample on disk', () {
    for (final kind in InstrumentKind.values) {
      for (final n in kind.stringCounts) {
        for (final t in Tuning.presets(kind, n)) {
          final i = Instrument(kind: kind, tuning: t);
          for (var s = 0; s < i.stringCount; s++) {
            for (var f = 0; f <= i.fretCount; f++) {
              final asset = map.asset(i, FretPosition(s, f));
              expect(asset, isNotNull, reason: '$i s$s f$f');
              expect(File(asset!).existsSync(), isTrue, reason: asset);
            }
          }
        }
      }
    }
  });

  test('guitar notes come from the string they are played on', () {
    final guitar = Instrument.standard(InstrumentKind.guitar);
    // A on the low E string at fret 5, and the open A string.
    expect(
      map.asset(guitar, const FretPosition(0, 5)),
      'assets/audio/guitar/s0_45.mp3',
    );
    expect(
      map.asset(guitar, const FretPosition(1, 0)),
      'assets/audio/guitar/s1_45.mp3',
    );
    // A seven-string's low B borrows the low E string's recordings.
    final seven = Instrument.standard(InstrumentKind.guitar, strings: 7);
    expect(
      map.asset(seven, const FretPosition(0, 0)),
      'assets/audio/guitar/s0_35.mp3',
    );
    expect(
      map.asset(seven, const FretPosition(1, 0)),
      'assets/audio/guitar/s0_40.mp3',
    );
  });

  test('bass notes by pitch', () {
    final bass = Instrument.standard(InstrumentKind.bass);
    expect(
      map.asset(bass, const FretPosition(0, 0)),
      'assets/audio/bass/28.mp3',
    );
  });
}
