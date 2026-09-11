import 'package:meta/meta.dart';

import 'instrument.dart';
import 'pitch.dart';

/// The octave of a note on one string found on a higher string: the same
/// note name, [offset] frets away. On a standard-tuned guitar the shapes are
/// "two strings up, two frets higher" (E→D, A→G), "two strings up, three
/// frets higher" across the B string (D→B, G→E), "three strings up, three
/// frets back" (E→G), "three strings up, two frets back" (A→B), and the
/// same fret on the two E strings.
@immutable
class OctaveShape {
  const OctaveShape({
    required this.source,
    required this.target,
    required this.offset,
  }) : assert(target > source);

  final int source;
  final int target;

  /// Frets to add to the source fret to land on the target string.
  final int offset;

  int get stringsUp => target - source;

  /// Fret on the target string for [sourceFret], or null if off the neck.
  int? fretFor(int sourceFret, {int maxFret = 12}) {
    final f = sourceFret + offset;
    return f < 0 || f > maxFret ? null : f;
  }

  /// Source frets whose octave lands between 0 and [maxFret].
  List<int> sourceFrets({int minFret = 0, int maxFret = 12}) => [
        for (var f = minFret; f <= maxFret; f++)
          if (fretFor(f, maxFret: maxFret) != null) f,
      ];

  /// Every octave relation between strings up to five apart on [instrument]:
  /// the fret offset that reaches the same note name one octave up (or two
  /// octaves up for the two E strings of a guitar), kept only when the
  /// offset is small enough to be a usable shape (three frets either way).
  static List<OctaveShape> all(Instrument instrument) {
    final out = <OctaveShape>[];
    for (var s = 0; s < instrument.stringCount; s++) {
      for (var t = s + 2; t < instrument.stringCount && t <= s + 5; t++) {
        var o =
            instrument.openPitch(s).midi + 12 - instrument.openPitch(t).midi;
        while (o < -3) {
          o += 12;
        }
        if (o > 3) continue;
        out.add(OctaveShape(source: s, target: t, offset: o));
      }
    }
    return out;
  }

  /// Plain-language description: "two strings up, two frets higher".
  String describe() {
    const words = ['', 'one', 'two', 'three', 'four', 'five'];
    final up = '${words[stringsUp]} string${stringsUp == 1 ? '' : 's'} up';
    if (offset == 0) return '$up, same fret';
    final n = words[offset.abs()];
    return '$up, $n fret${offset.abs() == 1 ? '' : 's'} ${offset > 0 ? 'higher' : 'back'}';
  }

  /// "low E string → D string".
  String label(Instrument instrument, [Accidentals acc = Accidentals.sharps]) =>
      '${instrument.stringLabel(source, acc)} string → '
      '${instrument.stringLabel(target, acc)} string';

  @override
  bool operator ==(Object other) =>
      other is OctaveShape &&
      other.source == source &&
      other.target == target &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(source, target, offset);

  @override
  String toString() => 's$source→s$target ${offset >= 0 ? '+' : ''}$offset';
}
