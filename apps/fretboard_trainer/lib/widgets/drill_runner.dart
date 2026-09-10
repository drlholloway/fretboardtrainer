import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretboard_theory/fretboard_theory.dart';

import '../app/theme.dart';
import '../services/settings.dart';
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
  int? _selected;
  int _answered = 0;
  int _correct = 0;
  int _streak = 0;
  final _misses = <String>[];
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    _gen = DrillGenerator(widget.config);
    _q = _gen.next();
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  void _select(int i) {
    if (_selected != null) return;
    final ok = _q.isCorrect(i);
    setState(() {
      _selected = i;
      _answered++;
      if (ok) {
        _correct++;
        _streak++;
      } else {
        _streak = 0;
        _misses.add(_q.explain(ref.read(accidentalsProvider)));
      }
    });
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
      _q = _gen.next();
    });
  }

  void _finish() => widget.onFinished(
    DrillResult(correct: _correct, total: _answered, misses: List.of(_misses)),
  );

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final answered = _selected != null;
    final wrong = answered && !_q.isCorrect(_selected!);
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
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: QuestionView(
              key: ValueKey(_q.promptKey + _answered.toString()),
              question: _q,
              selected: _selected,
              onSelect: _select,
              accidentals: settings.accidentals,
              leftHanded: settings.leftHanded,
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
                    child: Text(
                      _q.explain(settings.accidentals),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: wrongColor,
                      ),
                    ),
                  ),
                if (answered && !_q.isCorrect(_selected!))
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
                else if (total == null)
                  OutlinedButton(
                    onPressed: _answered == 0 ? null : _finish,
                    child: const Text('Finish'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
