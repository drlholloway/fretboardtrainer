import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:fretboard_trainer/features/learn/lesson_screen.dart';
import 'package:fretboard_trainer/features/splash/splash.dart';
import 'package:fretboard_trainer/services/stats.dart';
import 'package:fretboard_trainer/main.dart';
import 'package:go_router/go_router.dart';
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

    // "Next" (only offered on a pass) must open the following lesson.
    final next = find.textContaining('Next: ');
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Naturals, frets 5–12'), findsOneWidget);
      expect(find.text('Start questions'), findsOneWidget);
      expect(find.textContaining('of 8 correct'), findsNothing);
    }
  });

  testWidgets('next lesson from the result screen starts fresh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'unlockAll': true});
    await tester.pumpWidget(const ProviderScope(child: FretboardTrainerApp()));
    await tester.pumpAndSettle();
    // Open a lesson, skip the cards, then answer until the result shows;
    // always tapping the first choice gives a mix of right and wrong.
    await tester.tap(find.text('Naturals, frets 0–5').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start questions'));
    await tester.pumpAndSettle();
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
    // Whether passed or not, jump to another lesson through the router as
    // the Next button does, and expect a fresh teach phase.
    final ctx = tester.element(find.byType(LessonScreen));
    unawaited(GoRouter.of(ctx).pushReplacement('/lesson/g6-string0-b'));
    await tester.pumpAndSettle();
    expect(find.text('Naturals, frets 5–12'), findsOneWidget);
    expect(find.text('Start questions'), findsOneWidget);
    expect(find.textContaining('correct'), findsNothing);
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

  testWidgets('splash shows a sighting, fades on its own, and a tap skips it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(child: FretboardTrainerApp(splash: sightings.first)),
    );
    await tester.pump();
    expect(find.byType(SplashView), findsOneWidget);
    expect(find.text('FRETMAN'), findsOneWidget);
    await tester.pump(SplashGate.hold);
    await tester.pumpAndSettle();
    expect(find.byType(SplashView), findsNothing);
    expect(find.text('The low E string'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: SplashGate(sighting: sightings.last, child: const Text('behind')),
      ),
    );
    expect(find.byType(SplashView), findsOneWidget);
    await tester.tap(find.byType(SplashView));
    await tester.pumpAndSettle();
    expect(find.byType(SplashView), findsNothing);
    expect(find.text('behind'), findsOneWidget);
  });

  test('every sighting has its picture', () {
    for (final s in sightings) {
      expect(
        File('assets/splash/${s.asset}.png').existsSync(),
        isTrue,
        reason: s.asset,
      );
    }
  });

  test('the splash never repeats the previous launch', () async {
    final random = Random(1);
    var last = (await nextSighting(random)).asset;
    for (var i = 0; i < 30; i++) {
      final next = (await nextSighting(random)).asset;
      expect(next, isNot(last));
      last = next;
    }
  });

  testWidgets('answers in a drill are recorded in the stats', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: FretboardTrainerApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bolt_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Start'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('choice0')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DrillRunner)),
    );
    final book = container.read(statsProvider);
    expect(book.total.attempts, 1);
    expect(book.currentDayStreak(DateTime.now()), 1);
  });

  testWidgets('stats screen: empty, then heatmap and weak spots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: FretboardTrainerApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Answer a few questions'), findsOneWidget);

    final guitar = Instrument.standard(InstrumentKind.guitar);
    final missed = FretToNoteQuestion(
      instrument: guitar,
      position: const FretPosition(0, 6),
      choices: [guitar.pitchAt(const FretPosition(0, 6))],
      correctIndex: 0,
    );
    var book = const StatsBook();
    for (final ok in [false, false, true]) {
      book = book.record(
        guitar,
        missed,
        correct: ok,
        time: const Duration(seconds: 3),
        at: DateTime.now(),
        answerStreak: ok ? 1 : 0,
      );
    }
    SharedPreferences.setMockInitialValues({
      'stats': jsonEncode(book.toJson()),
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const ProviderScope(child: FretboardTrainerApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(find.text('day streak'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.byType(FretboardView), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('low E string, fret 6'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Notes to work on'), findsOneWidget);
    expect(find.text('A♯, low E string, fret 6'), findsOneWidget);
    await tester.tap(find.text('How fast'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Only right answers are timed'), findsOneWidget);
  });

  testWidgets('weak-spot practice is on by default and can be turned off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: FretboardTrainerApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(
      SwitchListTile,
      'Practice weak spots more',
    );
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Middle of the screen, clear of the navigation bar, before tapping.
    await Scrollable.ensureVisible(tester.element(tile), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('focusWeakSpots'), isFalse);
  });
}
