import 'package:flutter/material.dart';
import 'package:fretboard_theory/fretboard_theory.dart';

import '../app/theme.dart';
import 'fretboard.dart';
import 'staff.dart';

/// Renders one [Question] with its choices. [selected] is the index the
/// learner tapped (null until they answer); once set the correct choice is
/// shown green and a wrong pick red.
class QuestionView extends StatelessWidget {
  const QuestionView({
    super.key,
    required this.question,
    required this.selected,
    required this.onSelect,
    required this.accidentals,
    this.leftHanded = false,
    this.onListen,
  });

  final Question question;
  final int? selected;
  final ValueChanged<int> onSelect;
  final Accidentals accidentals;
  final bool leftHanded;

  /// Replays an ear question's sound.
  final VoidCallback? onListen;

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) => switch (question) {
    final FretToNoteQuestion q => _fretToNote(context, q),
    final NoteToFretQuestion q => _noteToFret(context, q),
    final OctaveQuestion q => _octave(context, q),
    final ChordToNameQuestion q => _chordToName(context, q),
    final NameToChordQuestion q => _nameToChord(context, q),
    final EarStringQuestion q => _earString(context, q),
    final EarNoteQuestion q => _earNote(context, q),
    final EarIntervalQuestion q => _earInterval(context, q),
  };

  Color? _border(int i) {
    if (selected == null) return null;
    if (question.isCorrect(i)) return correctColor;
    if (i == selected) return wrongColor;
    return null;
  }

  Widget _choice(BuildContext context, int i, Widget child, {double? height}) {
    final border = _border(i);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: ValueKey('choice$i'),
      button: true,
      label: 'choice ${_letters[i]}',
      child: Material(
        color: border == null
            ? scheme.surfaceContainerHigh
            : border.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: border ?? scheme.outlineVariant,
            width: border == null ? 1 : 2.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selected == null ? () => onSelect(i) : null,
          child: SizedBox(
            height: height,
            child: Padding(padding: const EdgeInsets.all(8), child: child),
          ),
        ),
      ),
    );
  }

  Widget _prompt(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleLarge,
    ),
  );

  Widget _grid(List<Widget> tiles, {double aspect = 1.1}) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: aspect,
    children: tiles,
  );

  int _lastFret(Instrument i, int fret) => fret <= 12 ? 12 : i.fretCount;

  Widget _fretToNote(BuildContext context, FretToNoteQuestion q) {
    final i = q.instrument;
    final where = q.position.isOpen ? 'open' : 'fret ${q.position.fret}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _prompt(context, 'What note is this?'),
        FretboardView(
          instrument: i,
          lastFret: _lastFret(i, q.position.fret),
          leftHanded: leftHanded,
          dimStringsExcept: q.position.string,
          markers: [FretMarker(q.position, label: '?')],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${i.stringLabel(q.position.string, accidentals)} string, $where',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _grid([
          for (final (n, p) in q.choices.indexed)
            _choice(
              context,
              n,
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: FittedBox(
                      child: StaffView.forInstrument(
                        p,
                        i,
                        accidentals: accidentals,
                        height: 90,
                      ),
                    ),
                  ),
                  Text(
                    p.pitchClass.name(accidentals),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ], aspect: 1.25),
      ],
    );
  }

  Widget _noteToFret(BuildContext context, NoteToFretQuestion q) {
    final i = q.instrument;
    final maxFret = q.choices.fold(0, (m, p) => p.fret > m ? p.fret : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _prompt(context, 'Where is this note?'),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StaffView.forInstrument(q.target, i, accidentals: accidentals),
            const SizedBox(width: 16),
            Text(
              q.target.pitchClass.name(accidentals),
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FretboardView(
          instrument: i,
          lastFret: _lastFret(i, maxFret),
          leftHanded: leftHanded,
          markers: [
            for (final (n, p) in q.choices.indexed)
              FretMarker(
                p,
                label: _letters[n],
                color: switch (_border(n)) {
                  null => markerColor,
                  final c => c,
                },
                textColor: _border(n) == null ? markerText : Colors.white,
              ),
          ],
        ),
        const SizedBox(height: 12),
        _grid([
          for (final (n, p) in q.choices.indexed)
            _choice(
              context,
              n,
              Center(
                child: Text(
                  '${_letters[n]}  ·  ${i.stringLabel(p.string, accidentals)} string, '
                  '${p.isOpen ? 'open' : 'fret ${p.fret}'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ], aspect: 3.2),
      ],
    );
  }

  Widget _octave(BuildContext context, OctaveQuestion q) {
    final i = q.instrument;
    final name = q.pitch.pitchClass.name(accidentals);
    final target = i.stringLabel(q.shape.target, accidentals);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _prompt(context, 'Find $name on the $target string'),
        FretboardView(
          instrument: i,
          lastFret: 12,
          leftHanded: leftHanded,
          markers: [
            FretMarker(q.source, label: name),
            for (final (n, p) in q.choices.indexed)
              FretMarker(
                p,
                label: '${n + 1}',
                color: switch (_border(n)) {
                  null => stringColor,
                  final c => c,
                },
                textColor: _border(n) == null ? markerText : Colors.white,
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '$name is on the ${i.stringLabel(q.source.string, accidentals)} '
            'string at ${q.source.isOpen ? 'the open string' : 'fret ${q.source.fret}'}. '
            'Where is it on the $target string?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _grid([
          for (final (n, p) in q.choices.indexed)
            _choice(
              context,
              n,
              Center(
                child: Text(
                  '${n + 1}  ·  ${p.isOpen ? 'open' : 'fret ${p.fret}'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ], aspect: 3.2),
      ],
    );
  }

  Widget _listen(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Center(
      child: FilledButton.tonalIcon(
        key: const ValueKey('listen'),
        onPressed: onListen,
        icon: const Icon(Icons.hearing),
        label: const Text('Play again'),
      ),
    ),
  );

  /// Lettered markers for fret choices along one string; once answered the
  /// right one turns green and a wrong pick red, and every marker shows its
  /// note.
  List<FretMarker> _fretChoices(Instrument i, List<FretPosition> choices) => [
    for (final (n, p) in choices.indexed)
      FretMarker(
        p,
        label: selected == null
            ? _letters[n]
            : i.pitchAt(p).pitchClass.name(accidentals),
        color: switch (_border(n)) {
          null => markerColor,
          final c => c,
        },
        textColor: _border(n) == null ? markerText : Colors.white,
      ),
  ];

  Widget _fretTiles(
    BuildContext context,
    List<FretPosition> choices, {
    FretPosition? from,
  }) => _grid([
    for (final (n, p) in choices.indexed)
      _choice(
        context,
        n,
        Center(
          child: Text(
            '${_letters[n]}  ·  ${p.isOpen ? 'open' : 'fret ${p.fret}'}'
            '${from == null ? '' : '  (${p.fret - from.fret} up)'}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
  ], aspect: 3.2);

  Widget _earString(BuildContext context, EarStringQuestion q) {
    final i = q.instrument;
    String label(int s) {
      final l = i.stringLabel(s, accidentals);
      return '${l[0].toUpperCase()}${l.substring(1)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _prompt(context, 'Which open string was that?'),
        _listen(context),
        FretboardView(
          instrument: i,
          lastFret: 5,
          leftHanded: leftHanded,
          markers: _fretChoices(i, [
            for (final s in q.choices) FretPosition(s, 0),
          ]),
        ),
        const SizedBox(height: 12),
        _grid([
          for (final (n, s) in q.choices.indexed)
            _choice(
              context,
              n,
              Center(
                child: Text(
                  '${_letters[n]}  ·  ${label(s)} string',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ], aspect: 3.2),
      ],
    );
  }

  Widget _earNote(BuildContext context, EarNoteQuestion q) {
    final i = q.instrument;
    final s = i.stringLabel(q.position.string, accidentals);
    final open = i.openPitch(q.position.string).pitchClass.name(accidentals);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _prompt(context, 'Which fret was that?'),
        _listen(context),
        FretboardView(
          instrument: i,
          lastFret: 12,
          leftHanded: leftHanded,
          dimStringsExcept: q.position.string,
          markers: [
            // The open string is a choice itself when it is one of them.
            if (!q.choices.contains(q.reference))
              FretMarker(q.reference, label: open, color: stringColor),
            ..._fretChoices(i, q.choices),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'First the open $s string, then a note on it.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _fretTiles(context, q.choices),
      ],
    );
  }

  Widget _earInterval(BuildContext context, EarIntervalQuestion q) {
    final i = q.instrument;
    final s = i.stringLabel(q.root.string, accidentals);
    final root = i.pitchAt(q.root).pitchClass.name(accidentals);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _prompt(context, 'Where was the second note?'),
        _listen(context),
        FretboardView(
          instrument: i,
          lastFret: 12,
          leftHanded: leftHanded,
          dimStringsExcept: q.root.string,
          markers: [
            FretMarker(q.root, label: root, color: stringColor),
            ..._fretChoices(i, q.choices),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'First $root on the $s string, then a note higher on the same '
            'string.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _fretTiles(context, q.choices, from: q.root),
      ],
    );
  }

  Widget _chordToName(BuildContext context, ChordToNameQuestion q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _prompt(context, 'Which chord is this?'),
        FretboardView.chord(
          q.voicing,
          leftHanded: leftHanded,
          stringSpacing: 28,
          compact: false,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            q.voicing.tab,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 2,
            ),
          ),
        ),
        _grid([
          for (final (n, name) in q.choices.indexed)
            _choice(
              context,
              n,
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name.label(accidentals),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      name.longLabel(accidentals),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ], aspect: 2.2),
      ],
    );
  }

  Widget _nameToChord(BuildContext context, NameToChordQuestion q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _prompt(context, 'Which shape is this chord?'),
        Text(
          q.target.label(accidentals),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800),
        ),
        Text(
          q.target.longLabel(accidentals),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        _grid([
          for (final (n, v) in q.choices.indexed)
            _choice(
              context,
              n,
              FretboardView.chord(v, leftHanded: leftHanded, stringSpacing: 14),
            ),
        ], aspect: 1.35),
      ],
    );
  }
}
