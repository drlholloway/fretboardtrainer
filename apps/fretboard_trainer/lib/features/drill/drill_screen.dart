import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:go_router/go_router.dart';

import '../../services/settings.dart';

/// Free practice: pick what to be asked and go.
class DrillScreen extends ConsumerWidget {
  const DrillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final instrument = s.instrument;
    final theme = Theme.of(context);
    final acc = s.accidentals;

    final noteModes = s.drillModes.where((m) => !m.isChord).isNotEmpty;
    final chordModes = s.drillModes.where((m) => m.isChord).isNotEmpty;
    final chordsAvailable = ChordLibrary.voicings(
      instrument,
      categories: s.drillCategories,
      maxRootFret: s.drillMaxFret,
    ).isNotEmpty;
    final canStart = s.drillModes.isNotEmpty && (noteModes || chordsAvailable);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('Drill')),
        SliverList.list(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${instrument.kind.label}, ${instrument.stringCount} strings, ${instrument.tuning.name} '
                '(${instrument.tuning.describe(acc)}). Change it in Settings.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            section('What to ask'),
            for (final m in DrillMode.values)
              CheckboxListTile(
                value: s.drillModes.contains(m),
                title: Text(m.label),
                subtitle: Text(m.description),
                onChanged: (v) => notifier.edit(
                  (s) => s.copyWith(
                    drillModes: v! ? {...s.drillModes, m} : {...s.drillModes}
                      ..remove(m),
                  ),
                ),
              ),
            if (noteModes) ...[
              section('Notes'),
              ListTile(
                title: Text('Up to fret ${s.drillMaxFret}'),
                subtitle: Slider(
                  value: s.drillMaxFret.toDouble(),
                  min: 3,
                  max: instrument.fretCount.toDouble(),
                  divisions: instrument.fretCount - 3,
                  label: '${s.drillMaxFret}',
                  onChanged: (v) =>
                      notifier.edit((s) => s.copyWith(drillMaxFret: v.round())),
                ),
              ),
              SwitchListTile(
                value: s.drillNaturalsOnly,
                title: const Text('Natural notes only'),
                subtitle: const Text('No sharps or flats'),
                onChanged: (v) =>
                    notifier.edit((s) => s.copyWith(drillNaturalsOnly: v)),
              ),
              ListTile(
                title: const Text('Strings'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (var i = instrument.stringCount - 1; i >= 0; i--)
                        FilterChip(
                          label: Text(instrument.stringLabel(i, acc)),
                          selected:
                              s.drillStrings.isEmpty ||
                              s.drillStrings.contains(i),
                          onSelected: (on) => notifier.edit((s) {
                            final all = {
                              for (var k = 0; k < instrument.stringCount; k++)
                                k,
                            };
                            final cur = s.drillStrings.isEmpty
                                ? all
                                : {...s.drillStrings};
                            if (on) {
                              cur.add(i);
                            } else if (cur.length > 1) {
                              cur.remove(i);
                            }
                            return s.copyWith(
                              drillStrings: cur.length == all.length ? {} : cur,
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (chordModes) ...[
              section('Chords'),
              for (final c in ChordCategory.values)
                CheckboxListTile(
                  value: s.drillCategories.contains(c),
                  title: Text(c.label),
                  subtitle:
                      c != ChordCategory.power &&
                          instrument.kind == InstrumentKind.bass
                      ? const Text('Guitar only')
                      : null,
                  onChanged:
                      c != ChordCategory.power &&
                          instrument.kind == InstrumentKind.bass
                      ? null
                      : (v) => notifier.edit(
                          (s) => s.copyWith(
                            drillCategories:
                                v!
                                      ? {...s.drillCategories, c}
                                      : {...s.drillCategories}
                                  ..remove(c),
                          ),
                        ),
                ),
            ],
            section('How many'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 10, label: Text('10')),
                  ButtonSegment(value: 20, label: Text('20')),
                  ButtonSegment(value: 50, label: Text('50')),
                  ButtonSegment(value: 0, label: Text('Endless')),
                ],
                selected: {s.drillCount},
                onSelectionChanged: (v) =>
                    notifier.edit((s) => s.copyWith(drillCount: v.first)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: canStart ? () => context.push('/drill/run') : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
            ),
            if (!canStart)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  s.drillModes.isEmpty ? 'Pick at least one question type.' : 'No chords match: pick a chord category available on this instrument.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ],
    );
  }
}

DrillConfig buildDrillConfig(Settings s, {Set<DrillMode>? modes}) =>
    DrillConfig(
      instrument: s.instrument,
      modes: modes ?? s.drillModes,
      maxFret: s.drillMaxFret,
      strings: s.drillStrings.isEmpty ? null : s.drillStrings,
      naturalsOnly: s.drillNaturalsOnly,
      chordCategories: s.drillCategories,
      maxRootFret: s.drillMaxFret < 12 ? s.drillMaxFret : 12,
    );
