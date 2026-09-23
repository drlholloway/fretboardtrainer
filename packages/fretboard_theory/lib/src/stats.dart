import 'package:meta/meta.dart';

import 'chords.dart';
import 'drills.dart';
import 'instrument.dart';

/// How answers to one question are tallied: the mode plus the thing being
/// asked about (a fret position for note questions, a voicing for chords).
/// Choice layout and distractors do not matter.
extension StatKeys on Question {
  /// The position the question is about, for note and octave questions.
  FretPosition? get statPosition => switch (this) {
        FretToNoteQuestion(:final position) => position,
        NoteToFretQuestion(:final answer) => answer,
        OctaveQuestion(:final answer) => answer,
        _ => null,
      };

  /// The voicing the question is about, for chord questions.
  ChordVoicing? get statVoicing => switch (this) {
        ChordToNameQuestion(:final voicing) => voicing,
        NameToChordQuestion(:final answer) => answer,
        _ => null,
      };

  String get statKey {
    final p = statPosition;
    if (p != null) return positionStatKey(mode, p);
    return voicingStatKey(mode, statVoicing!);
  }
}

String positionStatKey(DrillMode mode, FretPosition p) =>
    '${mode.name}:${p.string}:${p.fret}';

String voicingStatKey(DrillMode mode, ChordVoicing v) => '${mode.name}:${v.id}';

/// How much more often to ask about something, for spaced repetition.
///
/// 1 is a spot answered right, quickly and recently. Misses in the latest
/// answers count most, then slow answers and time since last asked; spots
/// never asked come up a little more than known ones so they get
/// introduced.
double repetitionWeight(FactStats? f, DateTime now) {
  if (f == null || f.attempts == 0) return 2;
  final miss = 1 - f.recentAccuracy;
  final time = f.averageTime;
  final slow = time == null
      ? 0.5
      : ((time.inMilliseconds - 2000) / 4000).clamp(0.0, 1.0);
  final days =
      (now.millisecondsSinceEpoch - f.lastSeenMs) / Duration.millisecondsPerDay;
  final stale = (days / 7).clamp(0.0, 1.0);
  return 1 + 5 * miss + 1.5 * slow + 1.5 * stale;
}

/// Stats are kept per instrument and tuning: fret 3 on the low string is a
/// different note in drop D.
String statsLayout(Instrument i) => '${i.kind.name}:${i.tuning.id}';

/// Tally for one stat key.
@immutable
class FactStats {
  const FactStats({
    this.attempts = 0,
    this.correct = 0,
    this.timedMs = 0,
    this.timed = 0,
    this.lastSeenMs = 0,
    this.recent = 0,
    this.recentCount = 0,
  });

  factory FactStats.fromJson(Map<String, Object?> j) => FactStats(
        attempts: (j['n'] as num?)?.toInt() ?? 0,
        correct: (j['ok'] as num?)?.toInt() ?? 0,
        timedMs: (j['ms'] as num?)?.toInt() ?? 0,
        timed: (j['t'] as num?)?.toInt() ?? 0,
        lastSeenMs: (j['at'] as num?)?.toInt() ?? 0,
        recent: (j['r'] as num?)?.toInt() ?? 0,
        recentCount: (j['rn'] as num?)?.toInt() ?? 0,
      );

  /// How many of the latest answers [recent] remembers.
  static const recentWindow = 8;

  /// Answers slower than this are not timed (the learner looked away).
  static const maxTimedMs = 30000;

  final int attempts;
  final int correct;

  /// Total and count of response times, correct answers only.
  final int timedMs;
  final int timed;

  /// When this was last asked, milliseconds since the epoch.
  final int lastSeenMs;

  /// The latest [recentCount] results as bits, newest in bit 0 (1 = right).
  final int recent;
  final int recentCount;

  double get accuracy => attempts == 0 ? 0 : correct / attempts;

  /// Accuracy over the latest answers only, so old mistakes fade.
  double get recentAccuracy {
    if (recentCount == 0) return 0;
    var right = 0;
    for (var i = 0; i < recentCount; i++) {
      if (recent & (1 << i) != 0) right++;
    }
    return right / recentCount;
  }

  /// Mean time to a correct answer, or null if none were timed.
  Duration? get averageTime =>
      timed == 0 ? null : Duration(milliseconds: timedMs ~/ timed);

  FactStats record({
    required bool correct,
    required Duration time,
    required DateTime at,
  }) {
    final ms = time.inMilliseconds;
    final timedNow = correct && ms > 0 && ms <= maxTimedMs;
    return FactStats(
      attempts: attempts + 1,
      correct: this.correct + (correct ? 1 : 0),
      timedMs: timedMs + (timedNow ? ms : 0),
      timed: timed + (timedNow ? 1 : 0),
      lastSeenMs: at.millisecondsSinceEpoch,
      recent: ((recent << 1) | (correct ? 1 : 0)) & ((1 << recentWindow) - 1),
      recentCount: recentCount < recentWindow ? recentCount + 1 : recentWindow,
    );
  }

  FactStats operator +(FactStats o) => FactStats(
        attempts: attempts + o.attempts,
        correct: correct + o.correct,
        timedMs: timedMs + o.timedMs,
        timed: timed + o.timed,
        lastSeenMs: lastSeenMs > o.lastSeenMs ? lastSeenMs : o.lastSeenMs,
        // Merged tallies have no single answer order; keep the newer one's.
        recent: lastSeenMs >= o.lastSeenMs ? recent : o.recent,
        recentCount: lastSeenMs >= o.lastSeenMs ? recentCount : o.recentCount,
      );

  Map<String, Object?> toJson() => {
        'n': attempts,
        'ok': correct,
        if (timed > 0) 'ms': timedMs,
        if (timed > 0) 't': timed,
        'at': lastSeenMs,
        'r': recent,
        'rn': recentCount,
      };
}

/// Every answer the learner has given, tallied, plus practice streaks.
@immutable
class StatsBook {
  const StatsBook({
    this.facts = const {},
    this.lastPracticeDay,
    this.dayStreak = 0,
    this.bestDayStreak = 0,
    this.bestAnswerStreak = 0,
  });

  factory StatsBook.fromJson(Map<String, Object?> j) {
    final raw = (j['facts'] as Map?)?.cast<String, Object?>() ?? const {};
    return StatsBook(
      facts: {
        for (final l in raw.entries)
          l.key: {
            for (final f in (l.value as Map).cast<String, Object?>().entries)
              f.key: FactStats.fromJson(
                (f.value as Map).cast<String, Object?>(),
              ),
          },
      },
      lastPracticeDay: (j['day'] as num?)?.toInt(),
      dayStreak: (j['days'] as num?)?.toInt() ?? 0,
      bestDayStreak: (j['bestDays'] as num?)?.toInt() ?? 0,
      bestAnswerStreak: (j['bestRun'] as num?)?.toInt() ?? 0,
    );
  }

  /// Layout ([statsLayout]) → stat key → tally.
  final Map<String, Map<String, FactStats>> facts;

  /// Local calendar day of the last answer, as days since 1970-01-01.
  final int? lastPracticeDay;

  /// Consecutive days with at least one answer, ending on [lastPracticeDay].
  final int dayStreak;
  final int bestDayStreak;

  /// Most answers right in a row in a single drill or lesson.
  final int bestAnswerStreak;

  static int dayNumber(DateTime local) =>
      DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// The day streak as of [now]: zero once a whole day has been missed.
  int currentDayStreak(DateTime now) {
    final last = lastPracticeDay;
    if (last == null) return 0;
    return dayNumber(now) - last <= 1 ? dayStreak : 0;
  }

  bool get isEmpty => facts.values.every((m) => m.isEmpty);

  StatsBook record(
    Instrument instrument,
    Question q, {
    required bool correct,
    required Duration time,
    required DateTime at,
    int answerStreak = 0,
  }) {
    final layout = statsLayout(instrument);
    final key = q.statKey;
    final tallies = facts[layout] ?? const {};
    final today = dayNumber(at);
    final last = lastPracticeDay;
    final days = last == today
        ? dayStreak
        : last == today - 1
            ? dayStreak + 1
            : 1;
    return StatsBook(
      facts: {
        ...facts,
        layout: {
          ...tallies,
          key: (tallies[key] ?? const FactStats())
              .record(correct: correct, time: time, at: at),
        },
      },
      lastPracticeDay: today,
      dayStreak: days,
      bestDayStreak: days > bestDayStreak ? days : bestDayStreak,
      bestAnswerStreak:
          answerStreak > bestAnswerStreak ? answerStreak : bestAnswerStreak,
    );
  }

  /// Tallies for [instrument]'s layout.
  Map<String, FactStats> forLayout(Instrument instrument) =>
      facts[statsLayout(instrument)] ?? const {};

  /// Note-question tallies per fret position for [instrument], summed over
  /// [modes] (default: every note mode).
  Map<FretPosition, FactStats> positions(
    Instrument instrument, {
    Set<DrillMode> modes = const {
      DrillMode.fretToNote,
      DrillMode.noteToFret,
      DrillMode.octave,
    },
  }) {
    final out = <FretPosition, FactStats>{};
    for (final e in forLayout(instrument).entries) {
      final parts = e.key.split(':');
      if (parts.length != 3) continue;
      final mode = DrillMode.values.asNameMap()[parts[0]];
      if (mode == null || !modes.contains(mode)) continue;
      final s = int.tryParse(parts[1]);
      final f = int.tryParse(parts[2]);
      if (s == null || f == null || s >= instrument.stringCount) continue;
      final p = FretPosition(s, f);
      out[p] = out[p] == null ? e.value : out[p]! + e.value;
    }
    return out;
  }

  /// Chord-question tallies per voicing id for [instrument], both modes
  /// summed.
  Map<String, FactStats> chords(Instrument instrument) {
    final out = <String, FactStats>{};
    for (final e in forLayout(instrument).entries) {
      final at = e.key.indexOf(':');
      final mode = DrillMode.values.asNameMap()[e.key.substring(0, at)];
      if (mode == null || !mode.isChord) continue;
      final id = e.key.substring(at + 1);
      out[id] = out[id] == null ? e.value : out[id]! + e.value;
    }
    return out;
  }

  /// Totals over every layout.
  FactStats get total {
    var t = const FactStats();
    for (final m in facts.values) {
      for (final f in m.values) {
        t = t + f;
      }
    }
    return t;
  }

  Map<String, Object?> toJson() => {
        'facts': {
          for (final l in facts.entries)
            l.key: {for (final f in l.value.entries) f.key: f.value.toJson()},
        },
        if (lastPracticeDay != null) 'day': lastPracticeDay,
        'days': dayStreak,
        'bestDays': bestDayStreak,
        'bestRun': bestAnswerStreak,
      };
}
