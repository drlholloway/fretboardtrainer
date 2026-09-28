import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretboard_theory/fretboard_theory.dart';

import '../app/theme.dart';
import '../services/settings.dart';
import '../services/sound.dart';
import '../services/stats.dart';
import 'ear_notice.dart';
import 'question_view.dart';

class DrillResult {
  const DrillResult({
    required this.correct,
    required this.total,
    required this.misses,
  });
  final int correct;
  final int total;

  /// Explanations for the questions answered wrongly, in order.
  final List<String> misses;

  double get score => total == 0 ? 0 : correct / total;
}

/// Asks questions from [config] until [total] have been answered (or the
/// learner stops an endless run) and reports the result.
class DrillRunner extends ConsumerStatefulWidget {
  const DrillRunner({
    super.key,
    required this.config,
    required this.total,
    required this.onFinished,
  });

  final DrillConfig config;

  /// Null means endless; the runner shows a Finish button instead.
  final int? total;
  final ValueChanged<DrillResult> onFinished;

  @override
  ConsumerState<DrillRunner> createState() => _DrillRunnerState();
}

class _DrillRunnerState extends ConsumerState<DrillRunner> {
  late DrillGenerator _gen;
  late Question _q;

  /// The choice tapped on a single-answer question.
  int? _selected;

  /// The choices toggled on a multi-select question, before Check.
  final _picks = <int>{};

  /// Null until the question is answered, then whether it was right.
  bool? _ok;
  int _answered = 0;
  int _correct = 0;
  int _streak = 0;
  final _misses = <String>[];
  Timer? _advance;

  /// Time from showing the question to the answer, for the stats.
  final _clock = Stopwatch();

  @override
  void initState() {
    super.initState();
    // Spaced repetition reads the live stats, so a miss in this run makes
    // that spot come back sooner.
    _gen = DrillGenerator(
      widget.config,
      stats: ref.read(settingsProvider).focusWeakSpots
          ? (key) =>
                ref.read(statsProvider).forLayout(widget.config.instrument)[key]
          : null,
    );
    _q = _gen.next();
    _clock.start();
    _listen();
  }

  /// Ear questions are asked out loud.
  void _listen() => ref.read(soundProvider).prompt(_q);

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  void _select(int i) {
    if (_ok != null) return;
    if (_q.multiSelect) {
      setState(() => _picks.contains(i) ? _picks.remove(i) : _picks.add(i));
      return;
    }
    _selected = i;
    _answer(_q.isCorrect(i));
  }

  /// Multi-select: right only if exactly the right places are picked.
  void _check() {
    if (_ok != null || _picks.isEmpty) return;
    _answer(_q.isRightSet(_picks));
  }

  void _answer(bool ok) {
    final time = _clock.elapsed;
    setState(() {
      _ok = ok;
      _answered++;
      if (ok) {
        _correct++;
        _streak++;
      } else {
        _streak = 0;
        _misses.add(_q.explain(ref.read(accidentalsProvider)));
      }
    });
    ref.read(soundProvider).answer(_q);
    ref
        .read(statsProvider.notifier)
        .record(
          widget.config.instrument,
          _q,
          correct: ok,
          time: time,
          answerStreak: _streak,
        );
    if (ok) _advance = Timer(const Duration(milliseconds: 650), _next);
  }

  void _next() {
    _advance?.cancel();
    if (!mounted) return;
    if (widget.total != null && _answered >= widget.total!) {
      _finish();
      return;
    }
    setState(() {
      _selected = null;
      _picks.clear();
      _ok = null;
      _q = _gen.next();
    });
    _clock.reset();
    _listen();
  }

  void _finish() => widget.onFinished(
    DrillResult(correct: _correct, total: _answered, misses: List.of(_misses)),
  );

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final answered = _ok != null;
    final wrong = _ok == false;
    final total = widget.total;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: total == null
                    ? Text(
                        '$_correct / $_answered correct',
                        style: theme.textTheme.labelLarge,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _answered / total,
                          minHeight: 10,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              if (total != null)
                Text('$_answered / $total', style: theme.textTheme.labelLarge),
              if (_streak >= 3) ...[
                const SizedBox(width: 12),
                Text('🔥 $_streak', style: theme.textTheme.labelLarge),
              ],
            ],
          ),
        ),
        if (widget.config.modes.any((m) => m.isEar))
          const EarNotice(compact: true),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: QuestionView(
              key: ValueKey(_q.promptKey + _answered.toString()),
              question: _q,
              selected: _selected,
              picks: _picks,
              revealed: answered,
              onSelect: _select,
              accidentals: settings.accidentals,
              leftHanded: settings.leftHanded,
              onListen: _listen,
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wrong)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _q.explain(settings.accidentals),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: wrongColor,
                            ),
                          ),
                        ),
                        if (settings.soundOn)
                          IconButton(
                            tooltip: 'Hear it again',
                            icon: const Icon(Icons.volume_up_outlined),
                            onPressed: () => ref.read(soundProvider).answer(_q),
                          ),
                      ],
                    ),
                  ),
                if (wrong)
                  FilledButton(onPressed: _next, child: const Text('Continue'))
                else if (answered)
                  FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: correctColor,
                      disabledForegroundColor: Colors.white,
                    ),
                    child: const Text('Correct!'),
                  )
                else ...[
                  if (_q.multiSelect)
                    FilledButton(
                      key: const ValueKey('check'),
                      onPressed: _picks.isEmpty ? null : _check,
                      child: Text(
                        _picks.isEmpty
                            ? 'Select every place'
                            : 'Check (${_picks.length} selected)',
                      ),
                    ),
                  if (total == null) ...[
                    if (_q.multiSelect) const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _answered == 0 ? null : _finish,
                      child: const Text('Finish'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
