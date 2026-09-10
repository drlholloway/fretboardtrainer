// Renders every screen at iPhone size with a real font and writes PNGs to
// docs/screenshots. Run with `just screenshots` (sets SCREENSHOTS=1 and
// --update-goldens); skipped otherwise because the output depends on the
// fonts installed on the machine.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:fretboard_trainer/app/theme.dart';
import 'package:fretboard_trainer/features/learn/lesson_screen.dart';
import 'package:fretboard_trainer/main.dart';
import 'package:fretboard_trainer/widgets/question_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fonts = [
  '/System/Library/Fonts/Supplemental/Arial.ttf',
  '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
  '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
];

Future<void> _loadFonts() async {
  final loader = FontLoader('Roboto');
  for (final f in _fonts) {
    final file = File(f);
    if (file.existsSync()) {
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await loader.load();

  // Material icons live in the Flutter SDK cache next to the test runner.
  final exe = Platform.resolvedExecutable;
  final at = exe.indexOf('/bin/cache/');
  if (at < 0) return;
  final icons = File(
    '${exe.substring(0, at)}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final il = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await il.load();
  }
}

void main() {
  final enabled = Platform.environment.containsKey('SCREENSHOTS');

  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../../../../docs/screenshots/$name.png'),
    );
  }

  Widget wrap(Widget child, {ThemeMode mode = ThemeMode.light}) =>
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: mode,
          home: Scaffold(
            appBar: AppBar(title: const Text('Drill')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      );

  testWidgets('app screens', (tester) async {
    await phone(tester);
    await tester.pumpWidget(const ProviderScope(child: FretboardTrainerApp()));
    await shot(tester, 'learn');
    await tester.tap(find.byIcon(Icons.bolt_outlined));
    await shot(tester, 'drill');
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await shot(tester, 'settings');
    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await shot(tester, 'lesson-teach');
    await tester.tap(find.text('Start questions'));
    await shot(tester, 'lesson-question');
  }, skip: !enabled);

  testWidgets('question types', (tester) async {
    await phone(tester);
    final guitar = Instrument.standard(InstrumentKind.guitar);
    Question pick(DrillMode m, int seed) => DrillGenerator(
      DrillConfig(instrument: guitar, modes: {m}),
      seed: seed,
    ).next();
    final cases = {
      'q-fret-to-note': (pick(DrillMode.fretToNote, 5), null),
      'q-note-to-fret': (pick(DrillMode.noteToFret, 6), null),
      'q-chord-to-name': (pick(DrillMode.chordToName, 7), null),
      'q-name-to-chord': (pick(DrillMode.nameToChord, 8), null),
      'q-wrong-answer': (pick(DrillMode.fretToNote, 9), 0),
    };
    for (final e in cases.entries) {
      final (q, sel) = e.value;
      final selected = sel == null ? null : (q.isCorrect(0) ? 1 : 0);
      await tester.pumpWidget(
        wrap(
          QuestionView(
            question: q,
            selected: selected,
            onSelect: (_) {},
            accidentals: Accidentals.sharps,
          ),
          mode: e.key == 'q-name-to-chord' ? ThemeMode.dark : ThemeMode.light,
        ),
      );
      await shot(tester, e.key);
    }
  }, skip: !enabled);

  testWidgets('teach cards', (tester) async {
    await phone(tester);
    final c = Curriculum(InstrumentKind.guitar, 6);
    final barre = c.lessonById('g6-barre-e')!;
    final card = barre.teach().first;
    await tester.pumpWidget(
      wrap(TeachCardView(card: card, instrument: barre.instrument)),
    );
    await shot(tester, 'teach-barre');
    final bass = Curriculum(
      InstrumentKind.bass,
      4,
    ).lessonById('b4-fretboard-b')!;
    await tester.pumpWidget(
      wrap(
        TeachCardView(card: bass.teach().first, instrument: bass.instrument),
      ),
    );
    await shot(tester, 'teach-bass-fretboard');
  }, skip: !enabled);
}
