import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../services/progress.dart';
import '../../services/settings.dart';
import '../../widgets/drill_runner.dart';
import '../../widgets/fretboard.dart';

enum _Phase { teach, run, result }

/// Teach cards, then the questions, then the result.
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  _Phase _phase = _Phase.teach;
  DrillResult? _result;
  bool _passed = false;
  int _run = 0;

  @override
  Widget build(BuildContext context) {
    final curriculum = ref.watch(curriculumProvider);
    final lesson = curriculum.lessonById(widget.lessonId);
    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('This lesson is not part of the current instrument.'),
        ),
      );
    }
    final unit = curriculum.unitOf(lesson);
    if (_phase == _Phase.teach && lesson.teach().isEmpty) {
      _phase = _Phase.run;
    }
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lesson.title, style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${unit.title} · ${lesson.instrument.tuning.name}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: switch (_phase) {
        _Phase.teach => _TeachPages(
          lesson: lesson,
          onStart: () => setState(() => _phase = _Phase.run),
        ),
        _Phase.run => DrillRunner(
          key: ValueKey(_run),
          config: lesson.config,
          total: lesson.questionCount,
          onFinished: (r) async {
            final passed = await ref
                .read(progressProvider.notifier)
                .record(lesson, r.score);
            if (!mounted) return;
            setState(() {
              _result = r;
              _passed = passed;
              _phase = _Phase.result;
            });
          },
        ),
        _Phase.result => _ResultView(
          lesson: lesson,
          result: _result!,
          passed: _passed,
          next: _passed ? _nextAfter(curriculum, lesson) : null,
          onRetry: () => setState(() {
            _run++;
            _phase = _Phase.run;
          }),
          onReview: () => setState(() => _phase = _Phase.teach),
        ),
      },
    );
  }

  Lesson? _nextAfter(Curriculum c, Lesson l) {
    final i = c.lessons.indexOf(l);
    return i + 1 < c.lessons.length ? c.lessons[i + 1] : null;
  }
}

class _TeachPages extends ConsumerStatefulWidget {
  const _TeachPages({required this.lesson, required this.onStart});
  final Lesson lesson;
  final VoidCallback onStart;

  @override
  ConsumerState<_TeachPages> createState() => _TeachPagesState();
}

class _TeachPagesState extends ConsumerState<_TeachPages> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final cards = widget.lesson.teach(settings.accidentals);
    final last = _page == cards.length - 1;
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: TeachCardView(
                card: cards[i],
                instrument: widget.lesson.instrument,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Text(
                '${_page + 1} / ${cards.length}',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!last)
                      TextButton(
                        onPressed: widget.onStart,
                        child: const Text('Skip'),
                      ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FilledButton(
                        onPressed: last
                            ? widget.onStart
                            : () => _controller.nextPage(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              ),
                        child: Text(
                          last ? 'Start questions' : 'Next',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Renders one [TeachCard] with a fretboard or chord diagram.
class TeachCardView extends ConsumerWidget {
  const TeachCardView({
    super.key,
    required this.card,
    required this.instrument,
  });
  final TeachCard card;
  final Instrument instrument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final acc = settings.accidentals;
    final theme = Theme.of(context);
    final Widget figure = switch (card) {
      final StringTeachCard c => FretboardView(
        instrument: instrument,
        firstFret: 0,
        lastFret: c.maxFret < 12 ? 12 : c.maxFret,
        leftHanded: settings.leftHanded,
        dimStringsExcept: c.string,
        markers: [
          for (var f = c.minFret; f <= c.maxFret; f++)
            if (!c.naturalsOnly ||
                instrument
                    .pitchAt(FretPosition(c.string, f))
                    .pitchClass
                    .isNatural)
              FretMarker(
                FretPosition(c.string, f),
                label: instrument
                    .pitchAt(FretPosition(c.string, f))
                    .pitchClass
                    .name(acc),
                color:
                    instrument
                        .pitchAt(FretPosition(c.string, f))
                        .pitchClass
                        .isNatural
                    ? markerColor
                    : stringColor,
              ),
        ],
      ),
      final FretboardTeachCard c => FretboardView(
        instrument: instrument,
        firstFret: 0,
        lastFret: c.maxFret < 12 ? 12 : c.maxFret,
        leftHanded: settings.leftHanded,
        stringSpacing: 30,
        markers: [
          for (var s = 0; s < instrument.stringCount; s++)
            for (var f = c.minFret; f <= c.maxFret; f++)
              if (!c.naturalsOnly ||
                  instrument.pitchAt(FretPosition(s, f)).pitchClass.isNatural)
                FretMarker(
                  FretPosition(s, f),
                  label: instrument
                      .pitchAt(FretPosition(s, f))
                      .pitchClass
                      .name(acc),
                  color:
                      instrument
                          .pitchAt(FretPosition(s, f))
                          .pitchClass
                          .isNatural
                      ? markerColor
                      : stringColor,
                ),
        ],
      ),
      final ChordTeachCard c => Column(
        children: [
          FretboardView.chord(
            c.voicing,
            leftHanded: settings.leftHanded,
            showNames: true,
            accidentals: acc,
            stringSpacing: 30,
            compact: false,
          ),
          const SizedBox(height: 6),
          Text(
            c.voicing.tab,
            style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 2),
          ),
        ],
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(card.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        figure,
        const SizedBox(height: 16),
        Text(card.body, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.lesson,
    required this.result,
    required this.passed,
    required this.next,
    required this.onRetry,
    required this.onReview,
  });

  final Lesson lesson;
  final DrillResult result;
  final bool passed;
  final Lesson? next;
  final VoidCallback onRetry;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (result.score * 100).round();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Icon(
            passed ? Icons.emoji_events : Icons.replay,
            size: 72,
            color: passed ? correctColor : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            passed ? 'Lesson complete' : 'Not quite yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${result.correct} of ${result.total} correct ($pct%). '
            '${passed ? '' : 'You need ${(lesson.passScore * 100).round()}% to pass.'}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          if (result.misses.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Worth another look', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final m in result.misses.toSet())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, size: 8),
                    const SizedBox(width: 10),
                    Expanded(child: Text(m)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 32),
          if (next != null)
            FilledButton(
              onPressed: () => context.pushReplacement('/lesson/${next!.id}'),
              child: Text('Next: ${next!.title}'),
            ),
          if (next != null) const SizedBox(height: 8),
          if (passed)
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Practice again'),
            )
          else
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          const SizedBox(height: 8),
          if (!lesson.isTest)
            TextButton(
              onPressed: onReview,
              child: const Text('Review the notes'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to the path'),
          ),
        ],
      ),
    );
  }
}
