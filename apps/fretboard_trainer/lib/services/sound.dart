import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:fretboard_theory/fretboard_theory.dart';

import 'settings.dart';

/// Which recorded sample plays a note. Built by `packaging/audio/make_samples.py`
/// (see `assets/audio/samples.json`): guitar notes were recorded string by
/// string on a six-string, bass notes once per pitch.
class SampleMap {
  SampleMap(this.guitar, this.bass);

  factory SampleMap.fromJson(Map<String, Object?> j) => SampleMap(
    {
      for (final e in (j['guitar'] as Map).cast<String, Object?>().entries)
        int.parse(e.key): {for (final m in e.value as List) m as int},
    },
    {for (final m in j['bass'] as List) m as int},
  );

  /// Recording string (0 = low E) → MIDI pitches recorded on it.
  final Map<int, Set<int>> guitar;
  final Set<int> bass;

  /// Asset path for [p] on [instrument], or null if nothing is close.
  String? asset(Instrument instrument, FretPosition p) {
    final midi = instrument.pitchAt(p).midi;
    if (instrument.kind == InstrumentKind.bass) {
      return bass.contains(midi) ? 'assets/audio/bass/$midi.mp3' : null;
    }
    // Line the strings up from the top, so a seven-string's extra low
    // string borrows the low E's recordings.
    final own = (p.string - (instrument.stringCount - 6)).clamp(0, 5);
    final strings = guitar.keys.toList()
      ..sort((a, b) => (a - own).abs().compareTo((b - own).abs()));
    for (final s in strings) {
      if (guitar[s]!.contains(midi)) {
        return 'assets/audio/guitar/s${s}_$midi.mp3';
      }
    }
    return null;
  }
}

/// Plays the recorded notes. Everything is best effort: a missing audio
/// device or sample never interrupts a drill.
class Sound {
  Sound(this._enabled);

  final bool Function() _enabled;

  /// Widget tests have no audio engine.
  static final bool _available =
      !kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST');

  static const _cacheSize = 48;
  static const strumGap = Duration(milliseconds: 35);
  static const phraseGap = Duration(milliseconds: 450);

  SampleMap? _map;
  Future<void>? _ready;

  /// Least recently used first.
  final _sources = <String, AudioSource>{};
  final _playing = <SoundHandle>[];
  int _generation = 0;

  SoLoud get _soloud => SoLoud.instance;

  Future<void> _init() => _ready ??= () async {
    final raw = await rootBundle.loadString('assets/audio/samples.json');
    _map = SampleMap.fromJson(jsonDecode(raw) as Map<String, Object?>);
    if (!_soloud.isInitialized) await _soloud.init();
  }();

  Future<AudioSource> _source(String asset) async {
    final hit = _sources.remove(asset);
    if (hit != null) return _sources[asset] = hit;
    final source = await _soloud.loadAsset(asset);
    _sources[asset] = source;
    while (_sources.length > _cacheSize) {
      final oldest = _sources.keys.first;
      unawaited(_soloud.disposeSource(_sources.remove(oldest)!));
    }
    return source;
  }

  /// Plays [positions] one after another, [gap] apart: a chord strummed
  /// from the lowest string, or a short phrase. Stops whatever was playing.
  Future<void> play(
    Instrument instrument,
    List<FretPosition> positions, {
    Duration gap = strumGap,
  }) async {
    if (!_available || !_enabled() || positions.isEmpty) return;
    try {
      await _init();
      final generation = ++_generation;
      _stopAll();
      final volume = positions.length > 2 && gap == strumGap ? 0.6 : 0.9;
      for (var i = 0; i < positions.length; i++) {
        if (i > 0) await Future<void>.delayed(gap);
        // A newer call has taken over.
        if (generation != _generation) return;
        final asset = _map!.asset(instrument, positions[i]);
        if (asset == null) continue;
        final source = await _source(asset);
        _playing.add(_soloud.play(source, volume: volume));
      }
    } on Object catch (e) {
      debugPrint('sound: $e');
    }
  }

  void _stopAll() {
    for (final h in _playing) {
      _soloud.fadeVolume(h, 0, const Duration(milliseconds: 60));
      _soloud.scheduleStop(h, const Duration(milliseconds: 60));
    }
    _playing.clear();
  }

  /// What a question sounds like once it is answered: the note, the two
  /// notes of an octave shape, or the chord strummed.
  Future<void> answer(Question q) => switch (q) {
    FretToNoteQuestion(:final instrument, :final position) => play(instrument, [
      position,
    ]),
    NoteToFretQuestion(:final instrument, :final answer) => play(instrument, [
      answer,
    ]),
    OctaveQuestion(:final instrument, :final source, :final answer) => play(
      instrument,
      [source, answer],
      gap: phraseGap,
    ),
    ChordToNameQuestion(:final voicing) => strum(voicing),
    NameToChordQuestion(:final answer) => strum(answer),
  };

  Future<void> strum(ChordVoicing v) => play(
    v.instrument,
    v.positions.toList()..sort((a, b) => a.string.compareTo(b.string)),
  );
}

final soundProvider = Provider<Sound>(
  (ref) => Sound(() => ref.read(settingsProvider).soundOn),
);
