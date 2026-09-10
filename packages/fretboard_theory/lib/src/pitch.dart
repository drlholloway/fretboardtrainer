import 'package:meta/meta.dart';

/// How to spell the black keys.
enum Accidentals { sharps, flats }

/// One of the twelve pitch classes. C is 0.
@immutable
class PitchClass {
  const PitchClass(this.index) : assert(index >= 0 && index < 12);

  final int index;

  static const c = PitchClass(0);
  static const d = PitchClass(2);
  static const e = PitchClass(4);
  static const f = PitchClass(5);
  static const g = PitchClass(7);
  static const a = PitchClass(9);
  static const b = PitchClass(11);

  static const all = [
    PitchClass(0), PitchClass(1), PitchClass(2), PitchClass(3), //
    PitchClass(4), PitchClass(5), PitchClass(6), PitchClass(7), //
    PitchClass(8), PitchClass(9), PitchClass(10), PitchClass(11), //
  ];

  static const naturals = [c, d, e, f, g, a, b];

  static const _sharpNames = [
    'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B', //
  ];
  static const _flatNames = [
    'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B', //
  ];

  bool get isNatural => _sharpNames[index].length == 1;

  /// Name with the given accidental preference, e.g. `C♯` or `D♭`.
  String name([Accidentals accidentals = Accidentals.sharps]) =>
      accidentals == Accidentals.sharps
          ? _sharpNames[index]
          : _flatNames[index];

  /// Both spellings for a black key, e.g. `C♯ / D♭`; the plain name otherwise.
  String get bothNames => isNatural
      ? _sharpNames[index]
      : '${_sharpNames[index]} / ${_flatNames[index]}';

  /// Letter and accidental for the given spelling.
  Spelling spell([Accidentals accidentals = Accidentals.sharps]) {
    final n = name(accidentals);
    return Spelling(
      letter: n[0],
      accidental: n.length == 1 ? 0 : (n[1] == '♯' ? 1 : -1),
    );
  }

  PitchClass operator +(int semitones) => PitchClass((index + semitones) % 12);
  PitchClass operator -(int semitones) =>
      PitchClass(((index - semitones) % 12 + 12) % 12);

  /// Semitones going up from this pitch class to [other], 0..11.
  int intervalTo(PitchClass other) => ((other.index - index) % 12 + 12) % 12;

  /// Parses `C`, `C#`, `Db`, `C♯`, `D♭` (case-insensitive letter).
  static PitchClass parse(String text) {
    final s = text.trim();
    if (s.isEmpty) throw FormatException('empty pitch class');
    final letter = s[0].toUpperCase();
    final base =
        const {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}[letter];
    if (base == null) throw FormatException('bad pitch class: $text');
    var acc = 0;
    for (final ch in s.substring(1).split('')) {
      switch (ch) {
        case '#' || '♯':
          acc++;
        case 'b' || '♭':
          acc--;
        default:
          throw FormatException('bad pitch class: $text');
      }
    }
    return PitchClass(((base + acc) % 12 + 12) % 12);
  }

  @override
  bool operator ==(Object other) => other is PitchClass && other.index == index;

  @override
  int get hashCode => index;

  @override
  String toString() => _sharpNames[index];
}

/// A spelled note letter plus accidental (-1 flat, 0 natural, +1 sharp).
@immutable
class Spelling {
  const Spelling({required this.letter, required this.accidental});
  final String letter;
  final int accidental;

  /// Diatonic step of the letter within an octave, C = 0 .. B = 6.
  int get letterStep => 'CDEFGAB'.indexOf(letter);

  String get accidentalGlyph => switch (accidental) {
        1 => '♯',
        -1 => '♭',
        _ => '',
      };

  @override
  String toString() => '$letter$accidentalGlyph';
}

/// A specific pitch, identified by its MIDI note number (middle C = 60).
@immutable
class Pitch implements Comparable<Pitch> {
  const Pitch(this.midi) : assert(midi >= 0 && midi < 128);

  /// Builds a pitch from a pitch class and a scientific octave (C4 = 60).
  Pitch.of(PitchClass pc, int octave) : midi = (octave + 1) * 12 + pc.index;

  final int midi;

  PitchClass get pitchClass => PitchClass(midi % 12);

  /// Scientific pitch notation octave: C4 is middle C.
  int get octave => midi ~/ 12 - 1;

  String name([Accidentals accidentals = Accidentals.sharps]) =>
      '${pitchClass.name(accidentals)}$octave';

  Spelling spell([Accidentals accidentals = Accidentals.sharps]) =>
      pitchClass.spell(accidentals);

  /// Absolute diatonic step (C4 = 7 * 4 = 28) for staff placement.
  /// Because the spellings never use C♭/B♯ the octave never wraps.
  int staffStep([Accidentals accidentals = Accidentals.sharps]) =>
      octave * 7 + spell(accidentals).letterStep;

  Pitch operator +(int semitones) => Pitch(midi + semitones);
  Pitch operator -(int semitones) => Pitch(midi - semitones);

  /// Parses `E2`, `C#4`, `Bb3`.
  static Pitch parse(String text) {
    final m = RegExp(r'^\s*([A-Ga-g][#b♯♭]*)(-?\d)\s*$').firstMatch(text);
    if (m == null) throw FormatException('bad pitch: $text');
    return Pitch.of(PitchClass.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  @override
  int compareTo(Pitch other) => midi.compareTo(other.midi);

  @override
  bool operator ==(Object other) => other is Pitch && other.midi == midi;

  @override
  int get hashCode => midi;

  @override
  String toString() => name();
}
