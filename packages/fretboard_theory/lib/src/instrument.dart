import 'package:meta/meta.dart';

import 'pitch.dart';

enum InstrumentKind {
  guitar,
  bass;

  String get label => switch (this) {
        InstrumentKind.guitar => 'Guitar',
        InstrumentKind.bass => 'Bass',
      };

  /// Supported string counts, per the README: bass 4–6, guitar 6–7.
  List<int> get stringCounts => switch (this) {
        InstrumentKind.guitar => const [6, 7],
        InstrumentKind.bass => const [4, 5, 6],
      };

  int get defaultStringCount => switch (this) {
        InstrumentKind.guitar => 6,
        InstrumentKind.bass => 4,
      };

  int get defaultFretCount => switch (this) {
        InstrumentKind.guitar => 22,
        InstrumentKind.bass => 20,
      };
}

/// Open-string pitches, lowest string first.
@immutable
class Tuning {
  const Tuning({required this.id, required this.name, required this.open});

  final String id;
  final String name;
  final List<Pitch> open;

  int get stringCount => open.length;

  /// Open-string names, lowest first, e.g. `E A D G B E`.
  String describe([Accidentals accidentals = Accidentals.sharps]) =>
      open.map((p) => p.pitchClass.name(accidentals)).join(' ');

  /// Whether this tuning is the standard one for its string count.
  bool get isStandard => id.startsWith('std');

  Tuning transposed(String id, String name, int semitones) => Tuning(
        id: id,
        name: name,
        open: [for (final p in open) p + semitones],
      );

  static final guitar6Standard = Tuning(
    id: 'std6',
    name: 'E standard',
    open: [40, 45, 50, 55, 59, 64].map(Pitch.new).toList(),
  );

  static final guitar7Standard = Tuning(
    id: 'std7',
    name: 'B standard',
    open: [35, 40, 45, 50, 55, 59, 64].map(Pitch.new).toList(),
  );

  static final bass4Standard = Tuning(
    id: 'stdb4',
    name: 'E standard',
    open: [28, 33, 38, 43].map(Pitch.new).toList(),
  );

  static final bass5Standard = Tuning(
    id: 'stdb5',
    name: 'B standard',
    open: [23, 28, 33, 38, 43].map(Pitch.new).toList(),
  );

  static final bass6Standard = Tuning(
    id: 'stdb6',
    name: 'B standard',
    open: [23, 28, 33, 38, 43, 48].map(Pitch.new).toList(),
  );

  static final List<Tuning> guitar6 = [
    guitar6Standard,
    Tuning(
      id: 'dropd6',
      name: 'Drop D',
      open: [38, 45, 50, 55, 59, 64].map(Pitch.new).toList(),
    ),
    guitar6Standard.transposed('eb6', 'E♭ standard', -1),
    guitar6Standard.transposed('d6', 'D standard', -2),
    Tuning(
      id: 'dropc6',
      name: 'Drop C',
      open: [36, 43, 48, 53, 57, 62].map(Pitch.new).toList(),
    ),
    guitar6Standard.transposed('c6', 'C standard', -4),
    Tuning(
      id: 'dadgad',
      name: 'DADGAD',
      open: [38, 45, 50, 55, 57, 62].map(Pitch.new).toList(),
    ),
    Tuning(
      id: 'openg6',
      name: 'Open G',
      open: [38, 43, 50, 55, 59, 62].map(Pitch.new).toList(),
    ),
  ];

  static final List<Tuning> guitar7 = [
    guitar7Standard,
    Tuning(
      id: 'dropa7',
      name: 'Drop A',
      open: [33, 40, 45, 50, 55, 59, 64].map(Pitch.new).toList(),
    ),
    guitar7Standard.transposed('bb7', 'B♭ standard', -1),
    guitar7Standard.transposed('a7', 'A standard', -2),
  ];

  static final List<Tuning> bass4 = [
    bass4Standard,
    Tuning(
      id: 'dropdb4',
      name: 'Drop D',
      open: [26, 33, 38, 43].map(Pitch.new).toList(),
    ),
    bass4Standard.transposed('ebb4', 'E♭ standard', -1),
    bass4Standard.transposed('db4', 'D standard', -2),
    bass4Standard.transposed('cb4', 'C standard', -4),
  ];

  static final List<Tuning> bass5 = [
    bass5Standard,
    Tuning(
      id: 'tenorb5',
      name: 'E standard, high C',
      open: [28, 33, 38, 43, 48].map(Pitch.new).toList(),
    ),
    bass5Standard.transposed('bbb5', 'B♭ standard', -1),
    bass5Standard.transposed('ab5', 'A standard', -2),
  ];

  static final List<Tuning> bass6 = [
    bass6Standard,
    bass6Standard.transposed('bbb6', 'B♭ standard', -1),
    bass6Standard.transposed('ab6', 'A standard', -2),
  ];

  static List<Tuning> presets(InstrumentKind kind, int strings) =>
      switch ((kind, strings)) {
        (InstrumentKind.guitar, 6) => guitar6,
        (InstrumentKind.guitar, 7) => guitar7,
        (InstrumentKind.bass, 4) => bass4,
        (InstrumentKind.bass, 5) => bass5,
        (InstrumentKind.bass, 6) => bass6,
        _ => throw ArgumentError('no presets for $kind with $strings strings'),
      };

  static Tuning standard(InstrumentKind kind, int strings) =>
      presets(kind, strings).first;

  /// The drop tuning for this instrument and string count (lowest string
  /// down a whole step), or null when there is no preset for it.
  static Tuning? drop(InstrumentKind kind, int strings) {
    for (final t in presets(kind, strings)) {
      if (t.id.startsWith('drop')) return t;
    }
    return null;
  }

  static Tuning? byId(String id) {
    for (final list in [guitar6, guitar7, bass4, bass5, bass6]) {
      for (final t in list) {
        if (t.id == id) return t;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is Tuning && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name (${describe()})';
}

/// A fretted (or open) position: [string] is 0 for the lowest-pitched string.
@immutable
class FretPosition {
  const FretPosition(this.string, this.fret)
      : assert(string >= 0),
        assert(fret >= 0);

  final int string;
  final int fret;

  bool get isOpen => fret == 0;

  @override
  bool operator ==(Object other) =>
      other is FretPosition && other.string == string && other.fret == fret;

  @override
  int get hashCode => Object.hash(string, fret);

  @override
  String toString() => 's$string f$fret';
}

/// A concrete instrument: kind, tuning and fret count.
@immutable
class Instrument {
  Instrument({required this.kind, required this.tuning, int? fretCount})
      : fretCount = fretCount ?? kind.defaultFretCount;

  Instrument.standard(this.kind, {int? strings, int? fretCount})
      : tuning = Tuning.standard(kind, strings ?? kind.defaultStringCount),
        fretCount = fretCount ?? kind.defaultFretCount;

  final InstrumentKind kind;
  final Tuning tuning;
  final int fretCount;

  int get stringCount => tuning.stringCount;

  Instrument withTuning(Tuning t) =>
      Instrument(kind: kind, tuning: t, fretCount: fretCount);

  /// The player's string number: 1 is the highest-pitched string.
  int stringNumber(int string) => stringCount - string;

  /// Index of the player's string number (1 = highest pitched).
  int stringIndex(int number) => stringCount - number;

  Pitch openPitch(int string) => tuning.open[string];

  Pitch pitchAt(FretPosition p) => tuning.open[p.string] + p.fret;

  /// Sounding pitches for a fret-per-string voicing (null = muted).
  List<Pitch> pitchesOf(List<int?> frets) => [
        for (var s = 0; s < frets.length; s++)
          if (frets[s] != null) pitchAt(FretPosition(s, frets[s]!)),
      ];

  /// All positions in range that sound [pc].
  List<FretPosition> positionsOf(
    PitchClass pc, {
    int minFret = 0,
    int? maxFret,
    Iterable<int>? strings,
  }) {
    final hi = maxFret ?? fretCount;
    return [
      for (final s in strings ?? List.generate(stringCount, (i) => i))
        for (var f = minFret; f <= hi; f++)
          if (pitchAt(FretPosition(s, f)).pitchClass == pc) FretPosition(s, f),
    ];
  }

  /// Human label for a string, e.g. `low E` / `A` / `high E`.
  String stringLabel(int string, [Accidentals acc = Accidentals.sharps]) {
    final name = openPitch(string).pitchClass.name(acc);
    final dup = [
      for (var s = 0; s < stringCount; s++)
        if (s != string &&
            openPitch(s).pitchClass == openPitch(string).pitchClass)
          s,
    ];
    if (dup.isEmpty) return name;
    return string < dup.first ? 'low $name' : 'high $name';
  }

  @override
  bool operator ==(Object other) =>
      other is Instrument &&
      other.kind == kind &&
      other.tuning == tuning &&
      other.fretCount == fretCount;

  @override
  int get hashCode => Object.hash(kind, tuning, fretCount);

  @override
  String toString() => '${kind.label} $stringCount-string, ${tuning.name}';
}
