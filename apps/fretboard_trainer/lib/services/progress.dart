import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

class LessonProgress {
  const LessonProgress({
    this.attempts = 0,
    this.bestScore = 0,
    this.completed = false,
  });

  factory LessonProgress.fromJson(Map<String, Object?> j) => LessonProgress(
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
    bestScore: (j['bestScore'] as num?)?.toDouble() ?? 0,
    completed: j['completed'] as bool? ?? false,
  );

  final int attempts;

  /// Fraction correct on the best run, 0..1.
  final double bestScore;
  final bool completed;

  Map<String, Object?> toJson() => {
    'attempts': attempts,
    'bestScore': bestScore,
    'completed': completed,
  };
}

/// Per-lesson progress, keyed by lesson id, persisted as one JSON blob.
class ProgressNotifier extends Notifier<Map<String, LessonProgress>> {
  static const _key = 'progress';
  SharedPreferences? _prefs;

  @override
  Map<String, LessonProgress> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, Object?>;
    state = {
      for (final e in map.entries)
        e.key: LessonProgress.fromJson(e.value as Map<String, Object?>),
    };
  }

  Future<void> _save() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      _key,
      jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}),
    );
  }

  /// Records a finished run. Returns whether the lesson is now complete.
  Future<bool> record(Lesson lesson, double score) async {
    final old = state[lesson.id] ?? const LessonProgress();
    final passed = score >= lesson.passScore;
    state = {
      ...state,
      lesson.id: LessonProgress(
        attempts: old.attempts + 1,
        bestScore: score > old.bestScore ? score : old.bestScore,
        completed: old.completed || passed,
      ),
    };
    await _save();
    return passed;
  }

  Future<void> reset() async {
    state = const {};
    await _save();
  }
}

final progressProvider =
    NotifierProvider<ProgressNotifier, Map<String, LessonProgress>>(
      ProgressNotifier.new,
    );

/// Lessons unlock in order along their own path (fretboard or ear): a
/// lesson is open once the one before it is complete, unless the learner
/// has turned on "unlock everything".
bool isLessonUnlocked(
  Curriculum c,
  Map<String, LessonProgress> progress,
  Lesson lesson, {
  bool unlockAll = false,
}) {
  if (unlockAll) return true;
  final all = c.lessonsIn(c.trackOf(lesson));
  final i = all.indexOf(lesson);
  if (i <= 0) return true;
  return progress[all[i - 1].id]?.completed ?? false;
}

/// The first lesson on [track] that is not yet complete.
Lesson? nextLesson(
  Curriculum c,
  Map<String, LessonProgress> progress, [
  Track track = Track.fretboard,
]) {
  for (final l in c.lessonsIn(track)) {
    if (!(progress[l.id]?.completed ?? false)) return l;
  }
  return null;
}

final nextLessonProvider = Provider.family<Lesson?, Track>((ref, track) {
  final c = ref.watch(curriculumProvider);
  return nextLesson(c, ref.watch(progressProvider), track);
});
