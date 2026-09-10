import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretboard_theory/fretboard_theory.dart';

import '../../app/theme.dart';
import '../../services/settings.dart';
import '../../widgets/drill_runner.dart';
import 'drill_screen.dart';

/// Runs a free drill built from the saved drill settings. [modes] overrides
/// the question types (used by the debug launch route).
class DrillRunScreen extends ConsumerStatefulWidget {
  const DrillRunScreen({super.key, this.modes});
  final Set<DrillMode>? modes;

  @override
  ConsumerState<DrillRunScreen> createState() => _DrillRunScreenState();
}

class _DrillRunScreenState extends ConsumerState<DrillRunScreen> {
  DrillResult? _result;
  int _run = 0;
  late final Settings _settings;
  late final DrillConfig _config;

  @override
  void initState() {
    super.initState();
    // Snapshot the settings once so a run is not rebuilt mid-way.
    _settings = ref.read(settingsProvider);
    _config = buildDrillConfig(_settings, modes: widget.modes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = _result;
    final total = _settings.drillCount == 0 ? null : _settings.drillCount;
    return Scaffold(
      appBar: AppBar(
        title: Text(_config.modes.map((m) => m.label).join(' · ')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: r == null
          ? DrillRunner(
              key: ValueKey(_run),
              config: _config,
              total: total,
              onFinished: (res) => setState(() => _result = res),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    '${(r.score * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: r.score >= 0.8
                          ? correctColor
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${r.correct} of ${r.total} correct',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (r.misses.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Worth another look',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final m in r.misses.toSet())
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('• $m'),
                      ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () => setState(() {
                      _result = null;
                      _run++;
                    }),
                    child: const Text('Again'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
    );
  }
}
