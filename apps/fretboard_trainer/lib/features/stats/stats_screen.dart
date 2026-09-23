import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretboard_theory/fretboard_theory.dart';

import '../../app/theme.dart';
import '../../services/settings.dart';
import '../../services/stats.dart';
import '../../widgets/fretboard.dart';

enum HeatMetric { accuracy, speed }

/// Answers under this count are too few to call a spot weak.
const _minAttempts = 2;

/// Where the learner is solid and where they stumble: streaks, a fretboard
/// heatmap and the weakest notes and chords.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  HeatMetric _metric = HeatMetric.accuracy;

  /// Layout picked from the ones with data; null follows the settings.
  String? _layout;

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(statsProvider);
    final s = ref.watch(settingsProvider);
    final acc = s.accidentals;
    final theme = Theme.of(context);

    // Lessons use standard tuning even when the drill tuning is something
    // else, so offer every layout that has answers.
    final layouts = _layoutsWithData(book, s.instrument);
    final instrument =
        layouts[_layout] ??
        (book.forLayout(s.instrument).isNotEmpty || layouts.isEmpty
            ? s.instrument
            : layouts.values.first);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    if (book.isEmpty) {
      return CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Stats')),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Answer a few questions in Learn or Drill and your '
                  'strong and weak spots show up here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final total = book.total;
    final positions = book.positions(instrument);
    final chordStats = book.chords(instrument);
    final voicings = {
      for (final v in ChordLibrary.voicings(instrument)) v.id: v,
    };
    final lastFret = positions.keys.fold(
      12,
      (hi, p) => p.fret > hi ? p.fret : hi,
    );
    final weakNotes = positions.entries.where((e) => _isWeak(e.value)).toList()
      ..sort(_weakestFirst);
    final weakChords =
        chordStats.entries
            .where((e) => voicings.containsKey(e.key) && _isWeak(e.value))
            .toList()
          ..sort(_weakestFirst);

    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('Stats')),
        SliverList.list(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _Tile(
                    value: '${book.currentDayStreak(DateTime.now())}',
                    label: 'day streak',
                    note: 'best ${book.bestDayStreak}',
                  ),
                  const SizedBox(width: 8),
                  _Tile(
                    value: '${book.bestAnswerStreak}',
                    label: 'best run',
                    note: 'right in a row',
                  ),
                  const SizedBox(width: 8),
                  _Tile(
                    value: '${(total.accuracy * 100).round()}%',
                    label: 'right',
                    note: '${total.attempts} answers',
                  ),
                ],
              ),
            ),
            section('Across the fretboard'),
            if (layouts.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: statsLayout(instrument),
                  items: [
                    for (final e in layouts.entries)
                      DropdownMenuItem(
                        value: e.key,
                        child: Text(_describe(e.value, acc)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _layout = v),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _describe(instrument, acc),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<HeatMetric>(
                segments: const [
                  ButtonSegment(
                    value: HeatMetric.accuracy,
                    label: Text('How often right'),
                  ),
                  ButtonSegment(
                    value: HeatMetric.speed,
                    label: Text('How fast'),
                  ),
                ],
                selected: {_metric},
                onSelectionChanged: (v) => setState(() => _metric = v.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: FretboardView(
                instrument: instrument,
                lastFret: lastFret,
                leftHanded: s.leftHanded,
                stringSpacing: 30,
                markers: [
                  for (final e in positions.entries)
                    if (_heat(e.value, _metric) case final t?)
                      FretMarker(
                        e.key,
                        label: instrument.pitchAt(e.key).pitchClass.name(acc),
                        color: heatColor(t),
                        textColor: t < 0.5 ? Colors.white : markerText,
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                _metric == HeatMetric.accuracy
                    ? 'Green notes you get right, red ones you miss, going '
                          'by your latest answers. Blank spots have not come '
                          'up yet.'
                    : 'Green notes you name quickly (under two seconds), red '
                          'ones take you six or more. Only right answers are '
                          'timed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (weakNotes.isNotEmpty) ...[
              section('Notes to work on'),
              for (final e in weakNotes.take(5))
                ListTile(
                  dense: true,
                  leading: _Dot(e.value),
                  title: Text(_describeNote(instrument, e.key, acc)),
                  subtitle: Text(_describeTally(e.value)),
                ),
            ],
            if (weakChords.isNotEmpty) ...[
              section('Chords to work on'),
              for (final e in weakChords.take(5))
                ListTile(
                  dense: true,
                  leading: _Dot(e.value),
                  title: Text(
                    '${voicings[e.key]!.name.label(acc)}, '
                    '${voicings[e.key]!.shape.label}',
                  ),
                  subtitle: Text(
                    '${voicings[e.key]!.tab} · ${_describeTally(e.value)}',
                  ),
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ],
    );
  }
}

bool _isWeak(FactStats f) => f.attempts >= _minAttempts && f.recentAccuracy < 1;

int _weakestFirst(
  MapEntry<Object, FactStats> a,
  MapEntry<Object, FactStats> b,
) {
  final byRecent = a.value.recentAccuracy.compareTo(b.value.recentAccuracy);
  if (byRecent != 0) return byRecent;
  return b.value.attempts.compareTo(a.value.attempts);
}

/// 0 (bad) .. 1 (good) for [metric], or null when there is nothing to show.
double? _heat(FactStats f, HeatMetric metric) {
  switch (metric) {
    case HeatMetric.accuracy:
      return f.attempts == 0 ? null : f.recentAccuracy;
    case HeatMetric.speed:
      final t = f.averageTime;
      if (t == null) return null;
      return ((6000 - t.inMilliseconds) / 4000).clamp(0.0, 1.0);
  }
}

/// Red through amber to green.
Color heatColor(double t) => t < 0.5
    ? Color.lerp(wrongColor, markerColor, t * 2)!
    : Color.lerp(markerColor, correctColor, (t - 0.5) * 2)!;

String _describe(Instrument i, Accidentals acc) =>
    '${i.kind.label}, ${i.stringCount} strings, ${i.tuning.name} '
    '(${i.tuning.describe(acc)})';

String _describeNote(Instrument i, FretPosition p, Accidentals acc) {
  final name = i.pitchAt(p).pitchClass.name(acc);
  final where = p.isOpen ? 'open' : 'fret ${p.fret}';
  return '$name, ${i.stringLabel(p.string, acc)} string, $where';
}

String _describeTally(FactStats f) {
  final recent = (f.recentAccuracy * f.recentCount).round();
  final time = f.averageTime;
  return '$recent of the last ${f.recentCount} right'
      '${time == null ? '' : ' · ${(time.inMilliseconds / 1000).toStringAsFixed(1)} s'}';
}

/// Every layout the learner has answers for, as instruments.
Map<String, Instrument> _layoutsWithData(StatsBook book, Instrument current) {
  final out = <String, Instrument>{};
  for (final key in book.facts.keys) {
    if (book.facts[key]!.isEmpty) continue;
    if (key == statsLayout(current)) {
      out[key] = current;
      continue;
    }
    for (final kind in InstrumentKind.values) {
      for (final n in kind.stringCounts) {
        for (final t in Tuning.presets(kind, n)) {
          final i = Instrument(kind: kind, tuning: t);
          if (statsLayout(i) == key) out[key] = i;
        }
      }
    }
  }
  return out;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label, required this.note});

  final String value;
  final String label;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(label, style: theme.textTheme.labelLarge),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.stats);
  final FactStats stats;

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: heatColor(stats.recentAccuracy),
      shape: BoxShape.circle,
    ),
  );
}
