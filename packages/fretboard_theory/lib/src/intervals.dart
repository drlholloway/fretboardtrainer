/// Names for the distance between two notes, in semitones (0–12). On one
/// string an interval is simply that many frets.
abstract final class Intervals {
  static const _names = [
    'unison',
    'minor second',
    'major second',
    'minor third',
    'major third',
    'perfect fourth',
    'tritone',
    'perfect fifth',
    'minor sixth',
    'major sixth',
    'minor seventh',
    'major seventh',
    'octave',
  ];

  static const _short = [
    'P1',
    'm2',
    'M2',
    'm3',
    'M3',
    'P4',
    'TT',
    'P5',
    'm6',
    'M6',
    'm7',
    'M7',
    'P8',
  ];

  /// How each interval tends to sound, for the teach cards.
  static const _sound = [
    'the same note',
    'tense and close, the shark-attack theme',
    'a step, the start of a scale',
    'dark and sad, the minor sound',
    'bright and happy, the major sound',
    'open and bold, the first two notes of "Here Comes the Bride"',
    'restless, halfway to the octave',
    'strong and hollow, the power chord sound',
    'bittersweet',
    'warm, the "My Bonnie" leap',
    'bluesy and unresolved',
    'almost there, one fret short of the octave',
    'the same note higher: the "Somewhere Over the Rainbow" leap',
  ];

  static String name(int semitones) => _names[_check(semitones)];
  static String short(int semitones) => _short[_check(semitones)];
  static String sound(int semitones) => _sound[_check(semitones)];

  static int _check(int s) {
    if (s < 0 || s > 12) throw RangeError.range(s, 0, 12, 'semitones');
    return s;
  }
}
