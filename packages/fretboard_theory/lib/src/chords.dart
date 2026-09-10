import 'package:meta/meta.dart';

import 'instrument.dart';
import 'pitch.dart';

enum ChordQuality {
  major([0, 4, 7], '', 'major'),
  minor([0, 3, 7], 'm', 'minor'),
  power([0, 7], '5', 'power'),
  dominant7([0, 4, 7, 10], '7', 'dominant seventh'),
  minor7([0, 3, 7, 10], 'm7', 'minor seventh'),
  major7([0, 4, 7, 11], 'maj7', 'major seventh'),
  sus2([0, 2, 7], 'sus2', 'suspended second'),
  sus4([0, 5, 7], 'sus4', 'suspended fourth'),
  diminished([0, 3, 6], 'dim', 'diminished'),
  augmented([0, 4, 8], 'aug', 'augmented');

  const ChordQuality(this.intervals, this.suffix, this.longName);

  /// Semitones above the root.
  final List<int> intervals;
  final String suffix;
  final String longName;
}

/// A chord symbol such as `A`, `F♯m`, `E5`, `G7/B`.
@immutable
class ChordName {
  const ChordName(this.root, this.quality, {this.bass});

  final PitchClass root;
  final ChordQuality quality;

  /// Lowest sounding note when it is not the root (slash chord), else null.
  final PitchClass? bass;

  Set<PitchClass> get pitchClasses =>
      {for (final i in quality.intervals) root + i};

  /// Chord symbol without the slash bass.
  String symbol([Accidentals acc = Accidentals.sharps]) =>
      '${root.name(acc)}${quality.suffix}';

  String label([Accidentals acc = Accidentals.sharps]) =>
      bass == null ? symbol(acc) : '${symbol(acc)}/${bass!.name(acc)}';

  /// Spoken form, e.g. `A minor`, `E power chord`.
  String longLabel([Accidentals acc = Accidentals.sharps]) {
    final q = quality == ChordQuality.power ? 'power chord' : quality.longName;
    return '${root.name(acc)} $q';
  }

  ChordName get withoutBass => ChordName(root, quality);

  @override
  bool operator ==(Object other) =>
      other is ChordName &&
      other.root == root &&
      other.quality == quality &&
      other.bass == bass;

  @override
  int get hashCode => Object.hash(root, quality, bass);

  @override
  String toString() => label();
}

/// Names the chord formed by [pitches], or null when the pitch-class set is
/// not one of the known qualities. The lowest pitch becomes a slash bass
/// when it is not the root.
ChordName? identifyChord(Iterable<Pitch> pitches) {
  final sorted = pitches.toList()..sort();
  if (sorted.isEmpty) return null;
  final set = {for (final p in sorted) p.pitchClass};
  final lowest = sorted.first.pitchClass;

  ChordName? best;
  var bestScore = -1;
  for (final root in set) {
    for (final q in ChordQuality.values) {
      final template = {for (final i in q.intervals) root + i};
      var score = 0;
      if (template.length == set.length && template.containsAll(set)) {
        score = 1000;
      } else if (q.intervals.length == 4 && set.length == 3) {
        // Seventh chords are often voiced without the fifth (open C7).
        final noFifth = {
          for (final i in q.intervals)
            if (i != 7) root + i
        };
        if (noFifth.containsAll(set)) score = 500;
      }
      if (score == 0) continue;
      // Prefer a root in the bass, then the earlier (more common) quality.
      score +=
          (root == lowest ? 100 : 0) + (ChordQuality.values.length - q.index);
      if (score > bestScore) {
        bestScore = score;
        best = ChordName(root, q, bass: root == lowest ? null : lowest);
      }
    }
  }
  return best;
}

enum ChordCategory {
  open('Open chords'),
  power('Power chords'),
  barre('Barre chords');

  const ChordCategory(this.label);
  final String label;
}

/// A chord fingering expressed as semitone offsets from the root note on
/// each string, so it can be resolved on any tuning. Null means muted.
@immutable
class ChordShape {
  const ChordShape({
    required this.id,
    required this.label,
    required this.category,
    required this.rootString,
    required this.offsets,
    this.fixedRootFret,
    this.reference,
  });

  /// Defines a shape from a fret-per-string list in the reference tuning.
  factory ChordShape.fromFrets({
    required String id,
    required String label,
    required ChordCategory category,
    required int rootString,
    required List<int?> frets,
    Tuning? reference,
    bool movable = false,
  }) {
    final ref = reference ?? Tuning.guitar6Standard;
    assert(frets.length == ref.stringCount);
    final rootFret = frets[rootString]!;
    final root = ref.open[rootString] + rootFret;
    return ChordShape(
      id: id,
      label: label,
      category: category,
      rootString: rootString,
      fixedRootFret: movable ? null : rootFret,
      reference: movable ? null : ref,
      offsets: [
        for (var s = 0; s < frets.length; s++)
          if (frets[s] == null)
            null
          else
            (ref.open[s] + frets[s]!).midi - root.midi,
      ],
    );
  }

  final String id;

  /// Player-facing hint such as `E shape` or `open`.
  final String label;
  final ChordCategory category;
  final int rootString;
  final List<int?> offsets;

  /// For open shapes the root sits on a fixed fret of the [reference] tuning;
  /// movable shapes leave both null and are resolved at any root fret.
  final int? fixedRootFret;
  final Tuning? reference;

  bool get isMovable => fixedRootFret == null;

  /// Resolves a fixed (open) shape on [instrument].
  ///
  /// When the tuning is the reference tuning shifted uniformly (E♭, D or C
  /// standard) the fingering is kept and the chord is renamed. Otherwise
  /// (drop D, DADGAD) the sounding pitches are kept and the frets move, so
  /// an E in drop D becomes `222100`. Null when the result is unplayable or
  /// not a nameable chord.
  ChordVoicing? resolveOpen(Instrument instrument) {
    final ref = reference;
    final f = fixedRootFret;
    if (ref == null || f == null) return null;
    if (ref.stringCount != instrument.stringCount) return null;
    final shift = instrument.openPitch(0).midi - ref.open[0].midi;
    var uniform = true;
    for (var s = 1; s < ref.stringCount; s++) {
      if (instrument.openPitch(s).midi - ref.open[s].midi != shift) {
        uniform = false;
        break;
      }
    }
    final root = ref.open[rootString] + f + (uniform ? shift : 0);
    final rootFret = root.midi - instrument.openPitch(rootString).midi;
    if (rootFret < 0) return null;
    return resolve(instrument, rootFret);
  }

  /// Resolves the shape at [rootFret] on [instrument], or null when a string
  /// would need a negative fret, exceed the neck, or the reach is unplayable.
  ChordVoicing? resolve(Instrument instrument, int rootFret) {
    if (offsets.length != instrument.stringCount) return null;
    if (rootString >= instrument.stringCount) return null;
    if (rootFret < 0) return null;
    final root = instrument.openPitch(rootString) + rootFret;
    final frets = <int?>[];
    for (var s = 0; s < offsets.length; s++) {
      final o = offsets[s];
      if (o == null) {
        frets.add(null);
        continue;
      }
      final f = root.midi + o - instrument.openPitch(s).midi;
      if (f < 0 || f > instrument.fretCount) return null;
      frets.add(f);
    }
    final fretted = [
      for (final f in frets)
        if (f != null && f > 0) f,
    ];
    if (fretted.isNotEmpty) {
      final lo = fretted.reduce((a, b) => a < b ? a : b);
      final hi = fretted.reduce((a, b) => a > b ? a : b);
      final maxSpan = isMovable ? 3 : 4;
      if (hi - lo > maxSpan) return null;
      if (!isMovable && hi > 5) return null;
    }
    final pitches = instrument.pitchesOf(frets);
    final name = identifyChord(pitches);
    if (name == null) return null;
    return ChordVoicing._(
      shape: this,
      instrument: instrument,
      rootFret: rootFret,
      frets: frets,
      pitches: pitches,
      name: name,
    );
  }

  @override
  String toString() => id;
}

/// A [ChordShape] resolved on an instrument: concrete frets and a name.
@immutable
class ChordVoicing {
  const ChordVoicing._({
    required this.shape,
    required this.instrument,
    required this.rootFret,
    required this.frets,
    required this.pitches,
    required this.name,
  });

  final ChordShape shape;
  final Instrument instrument;
  final int rootFret;

  /// Fret per string, lowest string first; null is muted.
  final List<int?> frets;
  final List<Pitch> pitches;
  final ChordName name;

  ChordCategory get category => shape.category;
  int get rootString => shape.rootString;

  /// Positions that are fretted or open (muted strings are omitted).
  List<FretPosition> get positions => [
        for (var s = 0; s < frets.length; s++)
          if (frets[s] != null) FretPosition(s, frets[s]!),
      ];

  /// Lowest fretted (non-open) fret, or 0 when everything is open.
  int get lowestFret {
    var lo = 0;
    for (final f in frets) {
      if (f != null && f > 0 && (lo == 0 || f < lo)) lo = f;
    }
    return lo;
  }

  int get highestFret {
    var hi = 0;
    for (final f in frets) {
      if (f != null && f > hi) hi = f;
    }
    return hi;
  }

  /// `x32010`-style tab string (`x` = muted).
  String get tab =>
      frets.map((f) => f == null ? 'x' : (f > 9 ? '($f)' : '$f')).join();

  /// Stable id for progress and de-duplication, e.g. `open-c@3`.
  String get id => '${shape.id}@$rootFret';

  @override
  bool operator ==(Object other) =>
      other is ChordVoicing &&
      other.shape.id == shape.id &&
      other.rootFret == rootFret &&
      other.instrument == instrument;

  @override
  int get hashCode => Object.hash(shape.id, rootFret, instrument);

  @override
  String toString() => '${name.label()} $tab';
}

/// Built-in chord shapes and the voicings they produce on an instrument.
class ChordLibrary {
  ChordLibrary._();

  static ChordShape _open(
          String id, String label, int rootString, List<int?> f) =>
      ChordShape.fromFrets(
        id: 'open-$id',
        label: label,
        category: ChordCategory.open,
        rootString: rootString,
        frets: f,
      );

  static ChordShape _barre(
          String id, String label, int rootString, List<int?> f) =>
      ChordShape.fromFrets(
        id: 'barre-$id',
        label: label,
        category: ChordCategory.barre,
        rootString: rootString,
        frets: f,
        movable: true,
      );

  static const int? _x = null;

  /// The classic open chords in six-string standard tuning.
  static final List<ChordShape> openShapes = [
    _open('c', 'C', 1, const [_x, 3, 2, 0, 1, 0]),
    _open('a', 'A', 1, const [_x, 0, 2, 2, 2, 0]),
    _open('g', 'G', 0, const [3, 2, 0, 0, 0, 3]),
    _open('e', 'E', 0, const [0, 2, 2, 1, 0, 0]),
    _open('d', 'D', 2, const [_x, _x, 0, 2, 3, 2]),
    _open('am', 'Am', 1, const [_x, 0, 2, 2, 1, 0]),
    _open('em', 'Em', 0, const [0, 2, 2, 0, 0, 0]),
    _open('dm', 'Dm', 2, const [_x, _x, 0, 2, 3, 1]),
    _open('e7', 'E7', 0, const [0, 2, 0, 1, 0, 0]),
    _open('a7', 'A7', 1, const [_x, 0, 2, 0, 2, 0]),
    _open('d7', 'D7', 2, const [_x, _x, 0, 2, 1, 2]),
    _open('g7', 'G7', 0, const [3, 2, 0, 0, 0, 1]),
    _open('b7', 'B7', 1, const [_x, 2, 1, 2, 0, 2]),
    _open('c7', 'C7', 1, const [_x, 3, 2, 3, 1, 0]),
    _open('am7', 'Am7', 1, const [_x, 0, 2, 0, 1, 0]),
    _open('em7', 'Em7', 0, const [0, 2, 0, 0, 0, 0]),
    _open('dm7', 'Dm7', 2, const [_x, _x, 0, 2, 1, 1]),
    _open('asus2', 'Asus2', 1, const [_x, 0, 2, 2, 0, 0]),
    _open('dsus2', 'Dsus2', 2, const [_x, _x, 0, 2, 3, 0]),
    _open('asus4', 'Asus4', 1, const [_x, 0, 2, 2, 3, 0]),
    _open('dsus4', 'Dsus4', 2, const [_x, _x, 0, 2, 3, 3]),
    _open('esus4', 'Esus4', 0, const [0, 2, 2, 2, 0, 0]),
  ];

  /// Open shapes grouped for teaching: majors, minors, sevenths, suspended.
  static final Map<String, List<ChordShape>> openGroups = {
    'major': openShapes.sublist(0, 5),
    'minor': openShapes.sublist(5, 8),
    'seventh': openShapes.sublist(8, 14),
    'minor seventh': openShapes.sublist(14, 17),
    'suspended': openShapes.sublist(17, 22),
  };

  /// Movable barre shapes (six-string). Root fret 1 gives F / Fm / F7 on the
  /// E shapes and A♯ / A♯m / A♯7 on the A shapes.
  static final List<ChordShape> barreShapes = [
    _barre('e-major', 'E shape', 0, const [0, 2, 2, 1, 0, 0]),
    _barre('e-minor', 'Em shape', 0, const [0, 2, 2, 0, 0, 0]),
    _barre('e-7', 'E7 shape', 0, const [0, 2, 0, 1, 0, 0]),
    _barre('a-major', 'A shape', 1, const [_x, 0, 2, 2, 2, 0]),
    _barre('a-minor', 'Am shape', 1, const [_x, 0, 2, 2, 1, 0]),
    _barre('a-7', 'A7 shape', 1, const [_x, 0, 2, 0, 2, 0]),
  ];

  /// Power chord shape rooted on [rootString]: root, fifth and (on guitar) the
  /// octave on the next two strings. Built per instrument because the
  /// offsets are tuning-independent but the string count is not.
  static ChordShape powerShape(Instrument instrument, int rootString,
      {bool octave = true}) {
    final n = instrument.stringCount;
    final withOctave = octave && rootString + 2 < n;
    return ChordShape(
      id: 'power-s$rootString${withOctave ? '' : '-2'}',
      label: 'root on ${instrument.stringLabel(rootString)}',
      category: ChordCategory.power,
      rootString: rootString,
      offsets: [
        for (var s = 0; s < n; s++)
          if (s == rootString)
            0
          else if (s == rootString + 1)
            7
          else if (withOctave && s == rootString + 2)
            12
          else
            null,
      ],
    );
  }

  /// Strings that power chords are rooted on for this instrument: the lowest
  /// three on guitar, the lowest two on bass.
  static List<int> powerRootStrings(Instrument instrument) =>
      switch (instrument.kind) {
        InstrumentKind.guitar => [0, 1, 2],
        InstrumentKind.bass => [0, 1],
      };

  /// Every playable voicing on [instrument] in the given categories.
  ///
  /// Open shapes are only defined for six-string guitar; a seven-string uses
  /// its six highest strings for them. Barre and power chords are movable and
  /// are generated at every root fret up to [maxRootFret].
  static List<ChordVoicing> voicings(
    Instrument instrument, {
    Set<ChordCategory> categories = const {
      ChordCategory.open,
      ChordCategory.power,
      ChordCategory.barre,
    },
    int minRootFret = 0,
    int maxRootFret = 12,
    Iterable<int>? rootStrings,
  }) {
    final out = <ChordVoicing>[];
    final six = _sixStringView(instrument);

    if (categories.contains(ChordCategory.open) && six != null) {
      for (final shape in openShapes) {
        final v = shape.resolveOpen(six.instrument);
        if (v != null) out.add(_lift(v, instrument, six.offset));
      }
    }
    if (categories.contains(ChordCategory.power)) {
      for (final rs in rootStrings ?? powerRootStrings(instrument)) {
        if (rs + 1 >= instrument.stringCount) continue;
        final shape = powerShape(
          instrument,
          rs,
          octave: instrument.kind == InstrumentKind.guitar,
        );
        for (var f = minRootFret; f <= maxRootFret; f++) {
          final v = shape.resolve(instrument, f);
          if (v != null) out.add(v);
        }
      }
    }
    if (categories.contains(ChordCategory.barre) && six != null) {
      for (final shape in barreShapes) {
        if (rootStrings != null &&
            !rootStrings.contains(shape.rootString + six.offset)) {
          continue;
        }
        final lo = minRootFret < 1 ? 1 : minRootFret;
        for (var f = lo; f <= maxRootFret; f++) {
          final v = shape.resolve(six.instrument, f);
          if (v != null) out.add(_lift(v, instrument, six.offset));
        }
      }
    }
    return out;
  }

  /// Resolves explicit six-string [shapes] on [instrument]: open shapes once,
  /// movable shapes at every root fret in range (barre shapes from fret 1).
  /// Power shapes are built per instrument and so resolve directly.
  static List<ChordVoicing> resolveShapes(
    Instrument instrument,
    Iterable<ChordShape> shapes, {
    int minRootFret = 0,
    int maxRootFret = 12,
  }) {
    final out = <ChordVoicing>[];
    final six = _sixStringView(instrument);
    for (final shape in shapes) {
      final direct = shape.offsets.length == instrument.stringCount;
      final target = direct ? instrument : six?.instrument;
      if (target == null) continue;
      final offset = direct ? 0 : six!.offset;
      if (shape.isMovable) {
        final lo = shape.category == ChordCategory.barre && minRootFret < 1
            ? 1
            : minRootFret;
        for (var f = lo; f <= maxRootFret; f++) {
          final v = shape.resolve(target, f);
          if (v != null) out.add(_lift(v, instrument, offset));
        }
      } else {
        final v = shape.resolveOpen(target);
        if (v != null) out.add(_lift(v, instrument, offset));
      }
    }
    return out;
  }

  /// A six-string guitar view of [instrument] (its highest six strings), or
  /// null when the instrument is not a guitar with at least six strings.
  static ({Instrument instrument, int offset})? _sixStringView(Instrument i) {
    if (i.kind != InstrumentKind.guitar || i.stringCount < 6) return null;
    final offset = i.stringCount - 6;
    if (offset == 0) return (instrument: i, offset: 0);
    final t = Tuning(
      id: '${i.tuning.id}-hi6',
      name: i.tuning.name,
      open: i.tuning.open.sublist(offset),
    );
    return (instrument: i.withTuning(t), offset: offset);
  }

  /// Re-expresses a six-string voicing on the full instrument, muting the
  /// extra low strings.
  static ChordVoicing _lift(ChordVoicing v, Instrument full, int offset) {
    if (offset == 0) return v;
    final shape = ChordShape(
      id: v.shape.id,
      label: v.shape.label,
      category: v.shape.category,
      rootString: v.shape.rootString + offset,
      offsets: [...List<int?>.filled(offset, null), ...v.shape.offsets],
      fixedRootFret: v.shape.fixedRootFret,
      reference: v.shape.reference,
    );
    return ChordVoicing._(
      shape: shape,
      instrument: full,
      rootFret: v.rootFret,
      frets: [...List<int?>.filled(offset, null), ...v.frets],
      pitches: v.pitches,
      name: v.name,
    );
  }
}
