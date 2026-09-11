import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:fretboard_trainer/main.dart';
import 'package:fretboard_trainer/widgets/drill_runner.dart';
import 'package:fretboard_trainer/widgets/fretboard.dart';
import 'package:fretboard_trainer/widgets/question_view.dart';
import 'package:fretboard_trainer/widgets/staff.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('app opens on the learning path and tabs work', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: FretboardTrainerApp()));
    await tester.pumpAndSettle();
    expect(find.text('The low E string'), findsOneWidget);
    expect(find.text('Naturals, frets 0–5'), findsWidgets);

    await tester.tap(find.byIcon(Icons.bolt_outlined));
    await tester.pumpAndSettle();
    expect(find.text('What to ask'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Start'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('choice0')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Tuning'), findsOneWidget);
  });

  testWidgets('switching to bass rebuilds the path', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: FretboardTrainerApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bass'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    expect(find.text('The E string'), findsOneWidget);
    expect(find.text('Open chords'), findsNothing);
  });

  testWidgets('a lesson can be taken from teach cards to the result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: FretboardTrainerApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Low E string, frets 0–5'), findsOneWidget);
    await tester.tap(find.text('Start questions'));
    await tester.pumpAndSettle();

    // Answer every question by tapping the first choice; continue on misses.
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(const ValueKey('choice0')));
      await tester.pump();
      final cont = find.text('Continue');
      if (cont.evaluate().isNotEmpty) {
        await tester.tap(cont);
      } else {
        await tester.pump(const Duration(milliseconds: 700));
      }
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('of 8 correct'), findsOneWidget);
  });

  testWidgets('drill runner scores answers', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    DrillResult? result;
    final config = DrillConfig(
      instrument: Instrument.standard(InstrumentKind.guitar),
      modes: {DrillMode.fretToNote},
      strings: {0},
      maxFret: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DrillRunner(
              config: config,
              total: 2,
              onFinished: (r) => result = r,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('E').last);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
    }
    expect(result, isNotNull);
    expect(result!.correct, 2);
    expect(result!.total, 2);
  });

  testWidgets('question views render for every question type', (tester) async {
    final g = DrillGenerator(
      DrillConfig(
        instrument: Instrument.standard(InstrumentKind.guitar),
        modes: DrillMode.values.toSet(),
      ),
      seed: 3,
    );
    for (var i = 0; i < DrillMode.values.length; i++) {
      final q = g.next();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuestionView(
                question: q,
                selected: null,
                onSelect: (_) {},
                accidentals: Accidentals.flats,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('choice0')), findsOneWidget);
      expect(find.byKey(const ValueKey('choice3')), findsOneWidget);
    }
  });

  testWidgets('fretboard and staff paint without errors', (tester) async {
    final guitar = Instrument.standard(InstrumentKind.guitar);
    final v = ChordLibrary.barreShapes[0].resolve(guitar, 8)!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              FretboardView(
                instrument: guitar,
                leftHanded: true,
                markers: const [FretMarker(FretPosition(0, 3), label: 'G')],
                mutedStrings: const {5},
              ),
              FretboardView.chord(v),
              StaffView(pitch: const Pitch(40), clef: Clef.treble),
              StaffView(
                pitch: const Pitch(28),
                clef: Clef.bass,
                accidentals: Accidentals.flats,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(FretboardView), findsNWidgets(2));
    expect(find.byType(StaffView), findsNWidgets(2));
  });
}
