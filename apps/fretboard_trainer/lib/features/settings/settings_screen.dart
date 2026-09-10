import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretboard_theory/fretboard_theory.dart';

import '../../services/progress.dart';
import '../../services/settings.dart';
import '../../widgets/fretboard.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final instrument = s.instrument;
    final presets = Tuning.presets(s.kind, s.stringCount);

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
        const SliverAppBar.large(title: Text('Settings')),
        SliverList.list(
          children: [
            section('Your instrument'),
            _Control(
              title: 'Instrument',
              child: SegmentedButton<InstrumentKind>(
                segments: [
                  for (final k in InstrumentKind.values)
                    ButtonSegment(value: k, label: Text(k.label)),
                ],
                selected: {s.kind},
                onSelectionChanged: (v) =>
                    n.edit((s) => s.copyWith(kind: v.first, clearTuning: true)),
              ),
            ),
            _Control(
              title: 'Strings',
              child: SegmentedButton<int>(
                segments: [
                  for (final c in s.kind.stringCounts)
                    ButtonSegment(value: c, label: Text('$c')),
                ],
                selected: {s.stringCount},
                onSelectionChanged: (v) => n.edit(
                  (s) => s.kind == InstrumentKind.guitar
                      ? s.copyWith(guitarStrings: v.first, clearTuning: true)
                      : s.copyWith(bassStrings: v.first, clearTuning: true),
                ),
              ),
            ),
            _Control(
              title: 'Tuning',
              subtitle: 'Lessons teach standard tuning first; drills use this.',
              child: DropdownButton<String>(
                isExpanded: true,
                value: s.tuning.id,
                items: [
                  for (final t in presets)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.name}  (${t.describe(s.accidentals)})'),
                    ),
                ],
                onChanged: (id) => n.edit((s) => s.copyWith(tuningId: id)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: FretboardView(
                instrument: instrument,
                lastFret: 12,
                leftHanded: s.leftHanded,
                markers: [
                  for (var i = 0; i < instrument.stringCount; i++)
                    FretMarker(
                      FretPosition(i, 0),
                      label: instrument
                          .openPitch(i)
                          .pitchClass
                          .name(s.accidentals),
                    ),
                ],
              ),
            ),
            section('Display'),
            _Control(
              title: 'Note names',
              child: SegmentedButton<Accidentals>(
                segments: const [
                  ButtonSegment(value: Accidentals.sharps, label: Text('C♯')),
                  ButtonSegment(value: Accidentals.flats, label: Text('D♭')),
                ],
                selected: {s.accidentals},
                onSelectionChanged: (v) =>
                    n.edit((s) => s.copyWith(accidentals: v.first)),
              ),
            ),
            SwitchListTile(
              value: s.leftHanded,
              title: const Text('Left-handed'),
              subtitle: const Text('Nut on the right'),
              onChanged: (v) => n.edit((s) => s.copyWith(leftHanded: v)),
            ),
            _Control(
              title: 'Theme',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', label: Text('Auto')),
                  ButtonSegment(value: 'light', label: Text('Light')),
                  ButtonSegment(value: 'dark', label: Text('Dark')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) =>
                    n.edit((s) => s.copyWith(themeMode: v.first)),
              ),
            ),
            section('Learning path'),
            SwitchListTile(
              value: s.unlockAll,
              title: const Text('Unlock every lesson'),
              subtitle: const Text('Skip around instead of following the path'),
              onChanged: (v) => n.edit((s) => s.copyWith(unlockAll: v)),
            ),
            ListTile(
              title: const Text('Reset progress'),
              subtitle: const Text('Forget every completed lesson and score'),
              trailing: const Icon(Icons.delete_outline),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Reset progress?'),
                    content: const Text(
                      'Every lesson goes back to the start. Settings are kept.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(progressProvider.notifier).reset();
                }
              },
            ),
            section('About'),
            const ListTile(
              title: Text('Fretboard Trainer'),
              subtitle: Text(
                'Notes and chords on guitar and bass, one quick drill at a time.',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ],
    );
  }
}

/// A labelled row whose control sits under the label, so wide controls
/// never fight a ListTile for space.
class _Control extends StatelessWidget {
  const _Control({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodyLarge),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
