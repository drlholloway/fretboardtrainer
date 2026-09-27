import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings.dart';

/// What ear training needs from the device: sound switched on in Settings,
/// and on iPhone and iPad the ring/silent switch off (iOS does not let apps
/// read the switch, so the reminder is always shown there).
class EarNotice extends ConsumerWidget {
  const EarNotice({super.key, this.compact = false});

  /// A single line, for the top of a lesson.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundOn = ref.watch(settingsProvider.select((s) => s.soundOn));
    final theme = Theme.of(context);
    if (!soundOn) {
      return _Banner(
        icon: Icons.volume_off_outlined,
        text: 'Ear training needs sound, which is off in Settings.',
        action: FilledButton.tonal(
          onPressed: () => ref
              .read(settingsProvider.notifier)
              .edit((s) => s.copyWith(soundOn: true)),
          child: const Text('Turn on sound'),
        ),
        color: theme.colorScheme.errorContainer,
        compact: compact,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _Banner(
        icon: Icons.notifications_off_outlined,
        text: compact
            ? 'Hearing nothing? Check the silent switch.'
            : 'Hearing nothing? Your iPhone may be on silent: flip the '
                  'switch on its side so the orange line is hidden, and turn '
                  'the volume up.',
        color: theme.colorScheme.secondaryContainer,
        compact: compact,
      );
    }
    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.color,
    required this.compact,
    this.action,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool compact;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 4 : 8, 16, compact ? 4 : 8),
      child: Card(
        color: color,
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Row(
            children: [
              Icon(icon, size: compact ? 18 : 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: compact
                      ? theme.textTheme.bodySmall
                      : theme.textTheme.bodyMedium,
                ),
              ),
              if (action != null) ...[const SizedBox(width: 8), action!],
            ],
          ),
        ),
      ),
    );
  }
}
