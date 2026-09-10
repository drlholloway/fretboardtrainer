import 'dart:math';

import 'package:meta/meta.dart';

import 'chords.dart';
import 'instrument.dart';
import 'pitch.dart';

enum DrillMode {
  fretToNote('Fret → Note', 'See a fretted position, pick the note'),
  noteToFret('Note → Fret', 'See a note, pick where it is'),
  chordToName('Chord → Name', 'See a chord shape, pick its name'),
  nameToChord('Name → Chord', 'See a chord name, pick its shape');

  const DrillMode(this.label, this.description);
  final String label;
  final String description;

  bool get isChord => this == chordToName || this == nameToChord;
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

  bool isCorrect(int index) => index == correctIndex;

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

/// Produces questions for a [DrillConfig]. Deterministic for a given seed.
class DrillGenerator {
  DrillGenerator(this.config, {int? seed}) : _random = Random(seed) {
    _positions = config.notePositions;
    _voicings = config.chordVoicings;
    _modes = config.modes.where((m) {
      if (m.isChord) return _voicings.isNotEmpty;
      return _positions.isNotEmpty;
    }).toList();
    if (_modes.isEmpty) {
      throw StateError('nothing to ask: no positions or voicings in range');
    }
  }

  final DrillConfig config;
  final Random _random;
  late final List<FretPosition> _positions;
  late final List<ChordVoicing> _voicings;
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
        DrillMode.chordToName => _chordToName(),
        DrillMode.nameToChord => _nameToChord(),
      };
    } while (q.promptKey == _lastKey && ++tries < 8);
    _lastKey = q.promptKey;
    return q;
  }

  T _pick<T>(List<T> items) => items[_random.nextInt(items.length)];

  List<T> _shuffled<T>(Iterable<T> items) => items.toList()..shuffle(_random);

  int _insertCorrect<T>(List<T> distractors, T correct) {
    final i = _random.nextInt(distractors.length + 1);
    distractors.insert(i, correct);
    return i;
  }

  FretToNoteQuestion _fretToNote() {
    final pos = _pick(_positions);
    final answer = instrument.pitchAt(pos);
    final natural = config.naturalsOnly && answer.pitchClass.isNatural;
    final pool = (natural ? PitchClass.naturals : PitchClass.all)
        .where((pc) => pc != answer.pitchClass)
        .toList();
    // Always include a near neighbour so the choices are not trivially far.
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
  /// in the same neighbourhood.
  Pitch _nearestPitch(PitchClass pc, Pitch reference) {
    final up = reference.pitchClass.intervalTo(pc);
    final down = 12 - up;
    return up <= down ? reference + up : reference - down;
  }

  NoteToFretQuestion _noteToFret() {
    final pos = _pick(_positions);
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

  ChordToNameQuestion _chordToName() {
    final v = _pick(_voicings);
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
    final v = _pick(_voicings);
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
}
