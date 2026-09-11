import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:go_router/go_router.dart';

import '../../services/progress.dart';
import '../../services/settings.dart';

/// The Duolingo-style path: units of lessons, unlocked in order.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final curriculum = ref.watch(curriculumProvider);
    final progress = ref.watch(progressProvider);
    final next = ref.watch(nextLessonProvider);
    final theme = Theme.of(context);
    final done = curriculum.lessons
        .where((l) => progress[l.id]?.completed ?? false)
        .length;

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('Learn'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '$done / ${curriculum.lessons.length}',
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/icon/icon_512.png',
                            width: 64,
                            height: 64,
                            semanticLabel: 'Fretman',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${settings.kind.label}, ${settings.stringCount} strings',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                next == null
                                    ? 'Every lesson complete. Nice.'
                                    : 'Next: ${curriculum.unitOf(next).title} · ${next.title}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (next != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () => openLesson(context, next),
                          child: const Text('Continue'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        for (final unit in curriculum.units)
          SliverToBoxAdapter(
            child: _UnitCard(
              unit: unit,
              curriculum: curriculum,
              progress: progress,
              unlockAll: settings.unlockAll,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.curriculum,
    required this.progress,
    required this.unlockAll,
  });

  final Unit unit;
  final Curriculum curriculum;
  final Map<String, LessonProgress> progress;
  final bool unlockAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = unit.lessons
        .where((l) => progress[l.id]?.completed ?? false)
        .length;
    final complete = done == unit.lessons.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        color: theme.colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(unit.title, style: theme.textTheme.titleMedium),
                        Text(
                          unit.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (complete)
                    Icon(Icons.verified, color: theme.colorScheme.primary)
                  else
                    Text(
                      '$done/${unit.lessons.length}',
                      style: theme.textTheme.labelMedium,
                    ),
                ],
              ),
            ),
            for (final lesson in unit.lessons)
              _LessonTile(
                lesson: lesson,
                progress: progress[lesson.id],
                unlocked: isLessonUnlocked(
                  curriculum,
                  progress,
                  lesson,
                  unlockAll: unlockAll,
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.progress,
    required this.unlocked,
  });

  final Lesson lesson;
  final LessonProgress? progress;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = progress?.completed ?? false;
    final icon = !unlocked
        ? Icons.lock_outline
        : completed
        ? Icons.check_circle
        : lesson.isTest
        ? Icons.flag_outlined
        : Icons.play_circle_outline;
    final color = !unlocked
        ? theme.colorScheme.outline
        : completed
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    final best = progress?.bestScore;
    return ListTile(
      enabled: unlocked,
      leading: Icon(icon, color: color),
      title: Text(lesson.title),
      subtitle: Text(lesson.subtitle),
      trailing: best == null || progress!.attempts == 0
          ? null
          : Text(
              '${(best * 100).round()}%',
              style: theme.textTheme.labelLarge?.copyWith(
                color: completed
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
      onTap: unlocked ? () => openLesson(context, lesson) : null,
    );
  }
}

void openLesson(BuildContext context, Lesson lesson) =>
    context.push('/lesson/${lesson.id}');
