import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every answer from lessons and free drills, tallied by [StatsBook] and
/// persisted as one JSON blob.
class StatsNotifier extends Notifier<StatsBook> {
  static const _key = 'stats';
  SharedPreferences? _prefs;

  @override
  StatsBook build() {
    _load();
    return const StatsBook();
  }

  Future<void> _load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return;
    try {
      state = StatsBook.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      // Unreadable stats are not worth a crash; start again.
    }
  }

  Future<void> _save() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> record(
    Instrument instrument,
    Question q, {
    required bool correct,
    required Duration time,
    required int answerStreak,
  }) async {
    state = state.record(
      instrument,
      q,
      correct: correct,
      time: time,
      at: DateTime.now(),
      answerStreak: answerStreak,
    );
    await _save();
  }

  Future<void> reset() async {
    state = const StatsBook();
    await _save();
  }
}

final statsProvider = NotifierProvider<StatsNotifier, StatsBook>(
  StatsNotifier.new,
);
