import 'dart:math';

import 'package:meta/meta.dart';

import 'chords.dart';
import 'instrument.dart';
import 'intervals.dart';
import 'octaves.dart';
import 'pitch.dart';
import 'stats.dart';

enum DrillMode {
  fretToNote('Fret → Note', 'See a fretted position, pick the note'),
  noteToFret('Note → Fret', 'See a note, pick where it is'),
  octave('Octave shapes', 'See a note on one string, find it on a higher one'),
  chordToName('Chord → Name', 'See a chord shape, pick its name'),
  nameToChord('Name → Chord', 'See a chord name, pick its shape'),
  earString('Hear → String', 'Hear an open string; say which one'),
  earNote('Hear → Fret', 'Hear the open string, then a note; find it'),
  earInterval('Hear an interval', 'Hear two notes; find the second'),
  allPositions('Note → Every place', 'See a note, select every place it is'),
  earAllPositions(
    'Hear → Every place',
    'Hear a note, select every place it is',
  );

  const DrillMode(this.label, this.description);
  final String label;
  final String description;

  bool get isChord => this == chordToName || this == nameToChord;

  /// Answered by ear: the question is played, not shown.
  bool get isEar =>
      this == earString ||
      this == earNote ||
      this == earInterval ||
      this == earAllPositions;

  /// Several choices can be right; the learner picks them all.
  bool get isMultiSelect => this == allPositions || this == earAllPositions;
}

/// What a drill or lesson asks. Note settings apply to the note modes and
/// chord settings to the chord modes; a config may enable both.
@immutable
class DrillConfig {
  const DrillConfig({
    required this.instrument,
    required this.modes,
    this.minFret = 0,
    this.maxFret = 12,
    this.strings,
    this.naturalsOnly = false,
    this.chordCategories = const {
      ChordCategory.open,
      ChordCategory.power,
      ChordCategory.barre,
    },
    this.chordShapes,
    this.rootStrings,
    this.minRootFret = 0,
    this.maxRootFret = 12,
    this.octaveShapes,
    this.intervals,
    this.choiceCount = 4,
  }) : assert(modes.length > 0);

  final Instrument instrument;
  final Set<DrillMode> modes;

  /// Note drills: fret range (inclusive) and which strings (null = all).
  final int minFret;
  final int maxFret;
  final Set<int>? strings;
  final bool naturalsOnly;

  /// Chord drills: categories, optional explicit shapes, root strings and
  /// root-fret range for movable shapes.
  final Set<ChordCategory> chordCategories;
  final List<ChordShape>? chordShapes;
  final Set<int>? rootStrings;
  final int minRootFret;
  final int maxRootFret;

  /// Octave drills: which string pairs to ask about (null = every shape on
  /// the instrument).
  final List<OctaveShape>? octaveShapes;

  /// Interval drills: which intervals to ask, in semitones (null = 1–12).
  final Set<int>? intervals;

  final int choiceCount;

  DrillConfig copyWith({
    Instrument? instrument,
    Set<DrillMode>? modes,
    int? minFret,
    int? maxFret,
    Set<int>? strings,
    bool clearStrings = false,
    bool? naturalsOnly,
    Set<ChordCategory>? chordCategories,
    int? maxRootFret,
  }) =>
      DrillConfig(
        instrument: instrument ?? this.instrument,
        modes: modes ?? this.modes,
        minFret: minFret ?? this.minFret,
        maxFret: maxFret ?? this.maxFret,
        strings: clearStrings ? null : (strings ?? this.strings),
        naturalsOnly: naturalsOnly ?? this.naturalsOnly,
        chordCategories: chordCategories ?? this.chordCategories,
        chordShapes: chordShapes,
        rootStrings: rootStrings,
        minRootFret: minRootFret,
        maxRootFret: maxRootFret ?? this.maxRootFret,
        octaveShapes: octaveShapes,
        intervals: intervals,
        choiceCount: choiceCount,
      );

  List<int> get stringList =>
      (strings ?? {for (var s = 0; s < instrument.stringCount; s++) s})
          .where((s) => s < instrument.stringCount)
          .toList()
        ..sort();

  /// Every position the note drills may ask about.
  List<FretPosition> get notePositions => [
        for (final s in stringList)
          for (var f = minFret; f <= maxFret; f++)
            if (!naturalsOnly ||
                instrument.pitchAt(FretPosition(s, f)).pitchClass.isNatural)
              FretPosition(s, f),
      ];

  /// Every (shape, source fret) the octave drills may ask about. Targets are
  /// kept within fret 12 so the whole shape fits on one screen.
  List<(OctaveShape, int)> get octavePrompts => [
        for (final shape in octaveShapes ?? OctaveShape.all(instrument))
          for (final f in shape.sourceFrets(minFret: minFret, maxFret: 12))
            if (f <= maxFret &&
                (!naturalsOnly ||
                    instrument
                        .pitchAt(FretPosition(shape.source, f))
                        .pitchClass
                        .isNatural))
              (shape, f),
      ];

  /// Every position the find-it-by-ear drill may play: the note drills'
  /// positions within the octave, the open string itself included.
  List<FretPosition> get earNotePositions => [
        for (final p in notePositions)
          if (p.fret <= 12) p
      ];

  /// Every (root, semitones) the interval drill may play, up one string.
  /// Roots stay low enough that there are wrong frets to choose from.
  List<(FretPosition, int)> get intervalPrompts {
    final top = maxFret < 12 ? maxFret : 12;
    return [
      for (final s in stringList)
        for (final iv in intervals ?? {for (var i = 1; i <= 12; i++) i})
          for (var r = minFret; r + iv <= top && r <= top - choiceCount; r++)
            (FretPosition(s, r), iv),
    ];
  }

  /// Frets the every-place questions cover: the note range, up to 12.
  int get _samePitchTop => maxFret < 12 ? maxFret : 12;

  /// Every position in range that sounds exactly [midi].
  List<FretPosition> samePitchPositions(int midi) => [
        for (final s in stringList)
          for (var f = minFret; f <= _samePitchTop; f++)
            if (instrument.pitchAt(FretPosition(s, f)).midi == midi)
              FretPosition(s, f),
      ];

  /// Pitches the see-it-find-it-everywhere drill may ask: those that live
  /// in at least two places in range.
  List<Pitch> get samePitchPrompts {
    final byMidi = <int, int>{};
    for (final s in stringList) {
      for (var f = minFret; f <= _samePitchTop; f++) {
        final p = instrument.pitchAt(FretPosition(s, f));
        if (naturalsOnly && !p.pitchClass.isNatural) continue;
        byMidi[p.midi] = (byMidi[p.midi] ?? 0) + 1;
      }
    }
    return [
      for (final e in byMidi.entries)
        if (e.value >= 2) Pitch(e.key),
    ]..sort((a, b) => a.midi.compareTo(b.midi));
  }

  /// Positions the hear-it-find-it-everywhere drill may play: any whose
  /// pitch lives in at least two places in range.
  List<FretPosition> get samePitchSources {
    final asked = {for (final p in samePitchPrompts) p.midi};
    return [
      for (final s in stringList)
        for (var f = minFret; f <= _samePitchTop; f++)
          if (asked.contains(instrument.pitchAt(FretPosition(s, f)).midi))
            FretPosition(s, f),
    ];
  }

  /// Every voicing the chord drills may ask about.
  List<ChordVoicing> get chordVoicings {
    final shapes = chordShapes;
    if (shapes != null) {
      return ChordLibrary.resolveShapes(
        instrument,
        shapes,
        minRootFret: minRootFret,
        maxRootFret: maxRootFret,
      );
    }
    return ChordLibrary.voicings(
      instrument,
      categories: chordCategories,
      minRootFret: minRootFret,
      maxRootFret: maxRootFret,
      rootStrings: rootStrings,
    );
  }
}

/// One multiple-choice question. Exactly one choice is correct.
sealed class Question {
  const Question();

  DrillMode get mode;
  int get correctIndex;
  int get choiceCount;

  /// Every right choice: just [correctIndex], except for multi-select
  /// questions, which have several.
  Set<int> get correctIndices => {correctIndex};

  bool get multiSelect => mode.isMultiSelect;

  bool isCorrect(int index) => correctIndices.contains(index);

  /// Whether [picks] is exactly the set of right choices.
  bool isRightSet(Set<int> picks) =>
      picks.length == correctIndices.length &&
      picks.containsAll(correctIndices);

  /// A key that identifies the prompt, used to avoid asking the same thing
  /// twice in a row.
  String get promptKey;

  /// Short explanation shown after answering.
  String explain(Accidentals acc);
}

class FretToNoteQuestion extends Question {
  const FretToNoteQuestion({
    required this.instrument,
    required this.position,
    required this.choices,
    required this.correctIndex,
  });

  final Instrument instrument;
  final FretPosition position;
  final List<Pitch> choices;
  @override
  final int correctIndex;

  Pitch get answer => choices[correctIndex];

  @override
  DrillMode get mode => DrillMode.fretToNote;
  @override
  int get choiceCount => choices.length;
  @override
  String get promptKey => 'f2n:$position';

  @override
  String explain(Accidentals acc) {
    final s = instrument.stringLabel(position.string, acc);
    final where = position.isOpen ? 'open' : 'fret ${position.fret}';
    return 'The $s string at $where is ${answer.pitchClass.name(acc)}.';
  }
}

class NoteToFretQuestion extends Question {
  const NoteToFretQuestion({
    required this.instrument,
    required this.target,
    required this.choices,
    required this.correctIndex,
  });

  final Instrument instrument;

  /// The pitch as it sounds at the correct position.
  final Pitch target;
  final List<FretPosition> choices;
  @override
  final int correctIndex;

  FretPosition get answer => choices[correctIndex];

  @override
  DrillMode get mode => DrillMode.noteToFret;
  @override
  int get choiceCount => choices.length;
  @override
  String get promptKey => 'n2f:${target.pitchClass.index}:${answer.string}';

  @override
  String explain(Accidentals acc) {
    final s = instrument.stringLabel(answer.string, acc);
    final where = answer.isOpen ? 'open' : 'fret ${answer.fret}';
    return '${target.pitchClass.name(acc)} is the $s string at $where.';
  }
}

/// A note on one string; find the same note an octave up on a higher string.
class OctaveQuestion extends Question {
  const OctaveQuestion({
    required this.instrument,
    required this.shape,
    required this.source,
    required this.choices,
    required this.correctIndex,
  });

  final Instrument instrument;
  final OctaveShape shape;
  final FretPosition source;

  /// All on the target string.
  final List<FretPosition> choices;
  @override
  final int correctIndex;

  FretPosition get answer => choices[correctIndex];
  Pitch get pitch => instrument.pitchAt(source);

  @override
  DrillMode get mode => DrillMode.octave;
  @override
  int get choiceCount => choices.length;
  @override
  String get promptKey => 'oct:$source:${shape.target}';

  @override
  String explain(Accidentals acc) {
    final name = pitch.pitchClass.name(acc);
    final src = instrument.stringLabel(source.string, acc);
    final tgt = instrument.stringLabel(shape.target, acc);
    return '$name on the $src string at fret ${source.fret} is fret '
        '${answer.fret} on the $tgt string: ${shape.describe()}.';
  }
}

class ChordToNameQuestion extends Question {
  const ChordToNameQuestion({
    required this.voicing,
    required this.choices,
    required this.correctIndex,
  });

  final ChordVoicing voicing;
  final List<ChordName> choices;
  @override
  final int correctIndex;

  ChordName get answer => choices[correctIndex];

  @override
  DrillMode get mode => DrillMode.chordToName;
  @override
  int get choiceCount => choices.length;
  @override
  String get promptKey => 'c2n:${voicing.id}';

  @override
  String explain(Accidentals acc) =>
      'This is ${answer.label(acc)} (${answer.longLabel(acc)}), ${voicing.shape.label}.';
}

class NameToChordQuestion extends Question {
  const NameToChordQuestion({
    required this.target,
    required this.choices,
    required this.correctIndex,
  });

  final ChordName target;
  final List<ChordVoicing> choices;
  @override
  final int correctIndex;

  ChordVoicing get answer => choices[correctIndex];

  @override
  DrillMode get mode => DrillMode.nameToChord;
  @override
  int get choiceCount => choices.length;
  @override
  String get promptKey => 'n2c:${target.label()}';

  @override
  String explain(Accidentals acc) =>
      '${target.label(acc)} is ${answer.tab} (${answer.shape.label}).';
}

/// Looks up the tally for a stat key ([StatKeys.statKey]); null if unseen.
typedef StatLookup = FactStats? Function(String statKey);

/// Hear one open string; pick which string it was.
class EarStringQuestion extends Question {
  const EarStringQuestion({
    required this.instrument,
    required this.string,
    required this.choices,
    required this.correctIndex,
  });

  final Instrument instrument;
  final int string;

  /// Strings, lowest first.
  final List<int> choices;
  @override
  final int correctIndex;

  int get answer => choices[correctIndex];
  FretPosition get position => FretPosition(string, 0);

  @override
  DrillMode get mode => DrillMode.earString;
  @override
  int get choiceCount => choices.length;
  @override
  String get promptKey => 'earS:$string';

  @override
  String explain(Accidentals acc) {
    final label = instrument.stringLabel(string, acc);
    final n = instrument.stringNumber(string);
    return 'That was the open $label string, string $n.';
  }
}

/// Hear the open string, then a note on it (possibly the open string
/// again); pick the fret it was.
class EarNoteQuestion extends Question {
  const EarNoteQuestion({
    required this.instrument,
    required this.position,
    required this.choices,
    required this.correctIndex,
  });

  final Instrument instrument;

  /// The note played (after the open string).
  final FretPosition position;

  /// Frets on the same string.
  final List<FretPosition> choices;
  @override
  final int correctIndex;

  FretPosition get answer => choices[correctIndex];
  FretPosition get reference => FretPosition(position.string, 0);

  @override
  DrillMode get mode => DrillMode.earNote;
  @override
  int get choiceCount => choices.length;
  @override
  String get promptKey => 'earN:$position';

  @override
  String explain(Accidentals acc) {
    final s = instrument.stringLabel(position.string, acc);
    final name = instrument.pitchAt(position).pitchClass.name(acc);
    if (position.isOpen) {
      return 'That was $name again: the open $s string both times.';
    }
    return 'That was $name, fret ${position.fret} on the $s string: '
        'a ${Intervals.name(position.fret)} above the open string.';
  }
}

/// Hear a shown root note, then a second note up the same string; pick
/// where the second note is.
class EarIntervalQuestion extends Question {
  const EarIntervalQuestion({
    required this.instrument,
    required this.root,
    required this.semitones,
    required this.choices,
    required this.correctIndex,
  });

  final Instrument instrument;
  final FretPosition root;
  final int semitones;

  /// Frets above the root on the same string.
  final List<FretPosition> choices;
  @override
  final int correctIndex;

  FretPosition get answer => choices[correctIndex];

  @override
  DrillMode get mode => DrillMode.earInterval;
  @override
  int get choiceCount => choices.length;
  @override
  String get promptKey => 'earI:$root:$semitones';

  @override
  String explain(Accidentals acc) {
    final s = instrument.stringLabel(root.string, acc);
    final from = instrument.pitchAt(root).pitchClass.name(acc);
    final to = instrument.pitchAt(answer).pitchClass.name(acc);
    final frets = semitones == 1 ? '1 fret' : '$semitones frets';
    return 'A ${Intervals.name(semitones)}: $frets up the $s string, '
        'from $from to $to.';
  }
}

/// Lists positions as "fret 7 on the D string, fret 2 on the G string and
/// fret 12 on the A string", lowest string first.
String _places(Instrument i, Iterable<FretPosition> ps, Accidentals acc) {
  final sorted = ps.toList()..sort((a, b) => a.string.compareTo(b.string));
  final parts = [
    for (final p in sorted)
      '${p.isOpen ? 'open' : 'fret ${p.fret}'} on the '
          '${i.stringLabel(p.string, acc)} string',
  ];
  if (parts.length == 1) return parts.single;
  return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}

/// See a note (on the staff and by name); select every place on the
/// fretboard that sounds exactly it.
class AllPositionsQuestion extends Question {
  const AllPositionsQuestion({
    required this.instrument,
    required this.target,
    required this.choices,
    required this.correct,
  });

  final Instrument instrument;
  final Pitch target;
  final List<FretPosition> choices;

  /// Indices of [choices] that sound [target].
  final Set<int> correct;

  @override
  int get correctIndex => correct.reduce((a, b) => a < b ? a : b);
  @override
  Set<int> get correctIndices => correct;
  @override
  DrillMode get mode => DrillMode.allPositions;
  @override
  int get choiceCount => choices.length;
  @override
  String get promptKey => 'all:${target.midi}';

  List<FretPosition> get answers => [for (final i in correct) choices[i]];

  @override
  String explain(Accidentals acc) =>
      '${target.pitchClass.name(acc)} here is at '
      '${_places(instrument, answers, acc)}.';
}

/// Hear the open string, then a note on it; select every place on the
/// fretboard that sounds exactly that note, on any string.
class EarAllPositionsQuestion extends Question {
  const EarAllPositionsQuestion({
    required this.instrument,
    required this.source,
    required this.choices,
    required this.correct,
  });

  final Instrument instrument;

  /// Where the note was played.
  final FretPosition source;
  final List<FretPosition> choices;
  final Set<int> correct;

  FretPosition get reference => FretPosition(source.string, 0);
  Pitch get target => instrument.pitchAt(source);

  @override
  int get correctIndex => correct.reduce((a, b) => a < b ? a : b);
  @override
  Set<int> get correctIndices => correct;
  @override
  DrillMode get mode => DrillMode.earAllPositions;
  @override
  int get choiceCount => choices.length;
  @override
  String get promptKey => 'earAll:$source';

  List<FretPosition> get answers => [for (final i in correct) choices[i]];

  @override
  String explain(Accidentals acc) => 'That was ${target.pitchClass.name(acc)}, '
      '${source.isOpen ? 'the open' : 'fret ${source.fret} on the'} '
      '${instrument.stringLabel(source.string, acc)} string. The same note is '
      'at ${_places(instrument, answers, acc)}.';
}

/// Produces questions for a [DrillConfig]. Deterministic for a given seed.
///
/// With [stats], picks are weighted by [repetitionWeight] so missed, slow
/// and long-unseen spots come up more often (spaced repetition). The lookup
/// is called on every pick, so answers given during the run count at once.
class DrillGenerator {
  DrillGenerator(
    this.config, {
    int? seed,
    this.stats,
    DateTime Function()? clock,
  })  : _random = Random(seed),
        _clock = clock ?? DateTime.now {
    _positions = config.notePositions;
    _voicings = config.chordVoicings;
    _octaves = config.octavePrompts;
    _earStrings = config.stringList;
    _earNotes = config.earNotePositions;
    _intervals = config.intervalPrompts;
    _samePitch = config.samePitchPrompts;
    _samePitchSources = config.samePitchSources;
    _modes = config.modes.where((m) {
      if (m.isChord) return _voicings.isNotEmpty;
      if (m == DrillMode.octave) return _octaves.isNotEmpty;
      if (m == DrillMode.earString) return _earStrings.length > 1;
      if (m == DrillMode.earNote) return _earNotes.isNotEmpty;
      if (m == DrillMode.earInterval) return _intervals.isNotEmpty;
      if (m == DrillMode.allPositions) return _samePitch.isNotEmpty;
      if (m == DrillMode.earAllPositions) return _samePitchSources.isNotEmpty;
      return _positions.isNotEmpty;
    }).toList();
    if (_modes.isEmpty) {
      throw StateError('nothing to ask: no positions or voicings in range');
    }
  }

  final DrillConfig config;
  final StatLookup? stats;
  final DateTime Function() _clock;
  final Random _random;
  late final List<FretPosition> _positions;
  late final List<ChordVoicing> _voicings;
  late final List<(OctaveShape, int)> _octaves;
  late final List<int> _earStrings;
  late final List<FretPosition> _earNotes;
  late final List<(FretPosition, int)> _intervals;
  late final List<Pitch> _samePitch;
  late final List<FretPosition> _samePitchSources;
  late final List<DrillMode> _modes;
  String? _lastKey;
  int _modeCursor = 0;

  Instrument get instrument => config.instrument;
  List<DrillMode> get activeModes => List.unmodifiable(_modes);

  Question next() {
    // Cycle through the enabled modes so mixed lessons feel balanced.
    final mode = _modes[_modeCursor++ % _modes.length];
    Question q;
    var tries = 0;
    do {
      q = switch (mode) {
        DrillMode.fretToNote => _fretToNote(),
        DrillMode.noteToFret => _noteToFret(),
        DrillMode.octave => _octave(),
        DrillMode.chordToName => _chordToName(),
        DrillMode.nameToChord => _nameToChord(),
        DrillMode.earString => _earString(),
        DrillMode.earNote => _earNote(),
        DrillMode.earInterval => _earInterval(),
        DrillMode.allPositions => _allPositions(),
        DrillMode.earAllPositions => _earAllPositions(),
      };
    } while (q.promptKey == _lastKey && ++tries < 8);
    _lastKey = q.promptKey;
    return q;
  }

  T _pick<T>(List<T> items) => items[_random.nextInt(items.length)];

  /// [_pick], weighted by the learner's stats for each item's [key].
  T _pickFor<T>(List<T> items, String Function(T) key) {
    final lookup = stats;
    if (lookup == null) return _pick(items);
    final now = _clock();
    final weights = [
      for (final i in items) repetitionWeight(lookup(key(i)), now),
    ];
    var r = _random.nextDouble() * weights.fold(0.0, (a, b) => a + b);
    for (var i = 0; i < items.length; i++) {
      r -= weights[i];
      if (r < 0) return items[i];
    }
    return items.last;
  }

  List<T> _shuffled<T>(Iterable<T> items) => items.toList()..shuffle(_random);

  int _insertCorrect<T>(List<T> distractors, T correct) {
    final i = _random.nextInt(distractors.length + 1);
    distractors.insert(i, correct);
    return i;
  }

  FretToNoteQuestion _fretToNote() {
    final pos = _pickFor(
      _positions,
      (p) => positionStatKey(DrillMode.fretToNote, p),
    );
    final answer = instrument.pitchAt(pos);
    final natural = config.naturalsOnly && answer.pitchClass.isNatural;
    final pool = (natural ? PitchClass.naturals : PitchClass.all)
        .where((pc) => pc != answer.pitchClass)
        .toList();
    // Always include a near neighbor so the choices are not trivially far.
    final near = _shuffled(pool.where(
      (pc) =>
          answer.pitchClass.intervalTo(pc) <= 2 ||
          pc.intervalTo(answer.pitchClass) <= 2,
    ));
    final far = _shuffled(pool.where((pc) => !near.contains(pc)));
    final chosen = <PitchClass>[
      ...near.take(1),
      ..._shuffled([...near.skip(1), ...far]),
    ].take(config.choiceCount - 1).toList();
    final choices = [
      for (final pc in chosen) _nearestPitch(pc, answer),
    ];
    final idx = _insertCorrect(choices, answer);
    return FretToNoteQuestion(
      instrument: instrument,
      position: pos,
      choices: choices,
      correctIndex: idx,
    );
  }

  /// The instance of [pc] closest to [reference] so staff positions stay
  /// in the same neighborhood.
  Pitch _nearestPitch(PitchClass pc, Pitch reference) {
    final up = reference.pitchClass.intervalTo(pc);
    final down = 12 - up;
    return up <= down ? reference + up : reference - down;
  }

  NoteToFretQuestion _noteToFret() {
    final pos = _pickFor(
      _positions,
      (p) => positionStatKey(DrillMode.noteToFret, p),
    );
    final target = instrument.pitchAt(pos);
    final others = _positions
        .where((p) => instrument.pitchAt(p).pitchClass != target.pitchClass)
        .toList();
    // Prefer wrong frets on the same string, then anywhere.
    final same = _shuffled(others.where((p) => p.string == pos.string));
    final elsewhere = _shuffled(others.where((p) => p.string != pos.string));
    final distractors = <FretPosition>[];
    for (final p in [...same.take(2), ...elsewhere, ...same.skip(2)]) {
      if (distractors.length >= config.choiceCount - 1) break;
      if (!distractors.contains(p)) distractors.add(p);
    }
    final idx = _insertCorrect(distractors, pos);
    return NoteToFretQuestion(
      instrument: instrument,
      target: target,
      choices: distractors,
      correctIndex: idx,
    );
  }

  OctaveQuestion _octave() {
    final (shape, f) = _pickFor(
      _octaves,
      (o) => positionStatKey(
        DrillMode.octave,
        FretPosition(o.$1.target, o.$1.fretFor(o.$2)!),
      ),
    );
    final source = FretPosition(shape.source, f);
    final correct = FretPosition(shape.target, shape.fretFor(f)!);
    final pc = instrument.pitchAt(source).pitchClass;
    // Wrong frets on the target string, nearest first, never the same note.
    final near = <FretPosition>[];
    for (final d in [1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6]) {
      final m = correct.fret + d;
      if (m < 0 || m > 12) continue;
      final p = FretPosition(shape.target, m);
      if (instrument.pitchAt(p).pitchClass == pc) continue;
      near.add(p);
    }
    final distractors = [
      ..._shuffled(near.take(4)),
      ..._shuffled(near.skip(4)),
    ].take(config.choiceCount - 1).toList();
    final idx = _insertCorrect(distractors, correct);
    return OctaveQuestion(
      instrument: instrument,
      shape: shape,
      source: source,
      choices: distractors,
      correctIndex: idx,
    );
  }

  ChordToNameQuestion _chordToName() {
    final v = _pickFor(
      _voicings,
      (v) => voicingStatKey(DrillMode.chordToName, v),
    );
    final correct = v.name;
    final names = <String, ChordName>{};
    for (final other in _voicings) {
      if (other.name.label() != correct.label()) {
        names[other.name.label()] = other.name;
      }
    }
    final related = _shuffled(names.values.where(
      (n) => n.root == correct.root || n.quality == correct.quality,
    ));
    final rest = _shuffled(names.values.where((n) => !related.contains(n)));
    final distractors =
        [...related, ...rest].take(config.choiceCount - 1).toList();
    // Small pools (a lesson with three chords) are topped up with invented
    // but plausible names.
    var guard = 0;
    while (distractors.length < config.choiceCount - 1 && guard++ < 100) {
      final n = guard < 50
          ? ChordName(_pick(PitchClass.all), correct.quality)
          : ChordName(correct.root, _pick(ChordQuality.values));
      if (n.label() != correct.label() &&
          !distractors.any((d) => d.label() == n.label())) {
        distractors.add(n);
      }
    }
    final idx = _insertCorrect(distractors, correct);
    return ChordToNameQuestion(
      voicing: v,
      choices: distractors,
      correctIndex: idx,
    );
  }

  NameToChordQuestion _nameToChord() {
    final v = _pickFor(
      _voicings,
      (v) => voicingStatKey(DrillMode.nameToChord, v),
    );
    final target = v.name;
    var pool = _voicings.where((o) => o.name.label() != target.label());
    if (pool.length < config.choiceCount - 1) {
      pool = ChordLibrary.voicings(instrument)
          .where((o) => o.name.label() != target.label());
    }
    final sameCat = _shuffled(pool.where((o) => o.category == v.category));
    final rest = _shuffled(pool.where((o) => o.category != v.category));
    final distractors = <ChordVoicing>[];
    for (final o in [...sameCat, ...rest]) {
      if (distractors.length >= config.choiceCount - 1) break;
      if (!distractors.any((d) => d.name.label() == o.name.label())) {
        distractors.add(o);
      }
    }
    final idx = _insertCorrect(distractors, v);
    return NameToChordQuestion(
      target: target,
      choices: distractors,
      correctIndex: idx,
    );
  }

  EarStringQuestion _earString() {
    final s = _pickFor(
      _earStrings,
      (s) => positionStatKey(DrillMode.earString, FretPosition(s, 0)),
    );
    // Every string in the lesson, lowest first, so the order sticks too.
    return EarStringQuestion(
      instrument: instrument,
      string: s,
      choices: _earStrings,
      correctIndex: _earStrings.indexOf(s),
    );
  }

  EarNoteQuestion _earNote() {
    final pos = _pickFor(
      _earNotes,
      (p) => positionStatKey(DrillMode.earNote, p),
    );
    // Wrong frets on the same string: the lesson's own first, nearest
    // first, then any other fret in range (the open string included).
    final own = _shuffled(
      _earNotes.where((p) => p.string == pos.string && p != pos),
    )..sort((a, b) =>
        (a.fret - pos.fret).abs().compareTo((b.fret - pos.fret).abs()));
    // Stay on the part of the string the lesson covers (at least 5 frets).
    final top = config.maxFret.clamp(5, 12);
    final more = _shuffled([
      for (var f = 0; f <= top; f++)
        if (f != pos.fret) FretPosition(pos.string, f),
    ])
      ..sort((a, b) =>
          (a.fret - pos.fret).abs().compareTo((b.fret - pos.fret).abs()));
    final distractors = <FretPosition>[];
    for (final p in [...own.take(3), ...more]) {
      if (distractors.length >= config.choiceCount - 1) break;
      if (!distractors.contains(p)) distractors.add(p);
    }
    distractors.sort((a, b) => a.fret.compareTo(b.fret));
    final idx = _insertSorted(distractors, pos);
    return EarNoteQuestion(
      instrument: instrument,
      position: pos,
      choices: distractors,
      correctIndex: idx,
    );
  }

  EarIntervalQuestion _earInterval() {
    final (root, iv) = _pickFor(
      _intervals,
      (p) => intervalStatKey(p.$2),
    );
    final top = config.maxFret < 12 ? config.maxFret : 12;
    final asked = config.intervals ?? const <int>{};
    // Other intervals from the lesson first, then the nearest ones.
    final others = [
      for (var d = 1; root.fret + d <= top; d++)
        if (d != iv) d,
    ]..sort((a, b) {
        final byLesson =
            (asked.contains(a) ? 0 : 1).compareTo(asked.contains(b) ? 0 : 1);
        if (byLesson != 0) return byLesson;
        return (a - iv).abs().compareTo((b - iv).abs());
      });
    final picked = others.take(config.choiceCount - 1).toList()..sort();
    final choices = [
      for (final d in picked) FretPosition(root.string, root.fret + d),
    ];
    final idx = _insertSorted(
      choices,
      FretPosition(root.string, root.fret + iv),
    );
    return EarIntervalQuestion(
      instrument: instrument,
      root: root,
      semitones: iv,
      choices: choices,
      correctIndex: idx,
    );
  }

  /// Inserts [p] among frets sorted along the string, so the choices read
  /// left to right; returns its index.
  int _insertSorted(List<FretPosition> sorted, FretPosition p) {
    var i = 0;
    while (i < sorted.length && sorted[i].fret < p.fret) {
      i++;
    }
    sorted.insert(i, p);
    return i;
  }

  AllPositionsQuestion _allPositions() {
    final target = _pickFor(
      _samePitch,
      (p) => pitchStatKey(DrillMode.allPositions, p.midi),
    );
    final (choices, correct) = _samePitchChoices(target.midi);
    return AllPositionsQuestion(
      instrument: instrument,
      target: target,
      choices: choices,
      correct: correct,
    );
  }

  EarAllPositionsQuestion _earAllPositions() {
    final source = _pickFor(
      _samePitchSources,
      (p) =>
          pitchStatKey(DrillMode.earAllPositions, instrument.pitchAt(p).midi),
    );
    final (choices, correct) =
        _samePitchChoices(instrument.pitchAt(source).midi);
    return EarAllPositionsQuestion(
      instrument: instrument,
      source: source,
      choices: choices,
      correct: correct,
    );
  }

  /// Every place that sounds [midi], plus wrong places to make six to
  /// eight marks: the same note name an octave away first (the real trap),
  /// then notes one fret off a right place. Sorted along the neck.
  (List<FretPosition>, Set<int>) _samePitchChoices(int midi) {
    final right = config.samePitchPositions(midi);
    final top = config.maxFret < 12 ? config.maxFret : 12;
    final wanted = (right.length + 4).clamp(6, 8);
    final octaves = _shuffled([
      for (final s in config.stringList)
        for (var f = config.minFret; f <= top; f++)
          if (instrument.pitchAt(FretPosition(s, f)) case final p
              when p.midi != midi && (p.midi - midi) % 12 == 0)
            FretPosition(s, f),
    ]);
    final nearby = _shuffled([
      for (final r in right)
        for (final f in [r.fret - 1, r.fret + 1])
          if (f >= config.minFret && f <= top) FretPosition(r.string, f),
    ]);
    final wrong = <FretPosition>[];
    for (final p in [...octaves.take(2), ...nearby, ...octaves.skip(2)]) {
      if (right.length + wrong.length >= wanted) break;
      if (!right.contains(p) &&
          !wrong.contains(p) &&
          instrument.pitchAt(p).midi != midi) {
        wrong.add(p);
      }
    }
    final all = [...right, ...wrong]..sort((a, b) => a.fret != b.fret
        ? a.fret.compareTo(b.fret)
        : b.string.compareTo(a.string));
    return (
      all,
      {
        for (final (i, p) in all.indexed)
          if (right.contains(p)) i
      }
    );
  }
}
