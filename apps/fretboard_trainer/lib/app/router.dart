import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:go_router/go_router.dart';

import '../features/drill/drill_run_screen.dart';
import '../features/drill/drill_screen.dart';
import '../features/learn/learn_screen.dart';
import '../features/learn/lesson_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';

/// Debug builds can be launched straight onto a screen, which is how the
/// screenshots in `docs/` are taken (`FRETBOARD_ROUTE=/lesson/g6-string0-a`).
String _initialLocation() {
  if (!kDebugMode) return '/learn';
  try {
    return Platform.environment['FRETBOARD_ROUTE'] ?? '/learn';
  } catch (_) {
    return '/learn';
  }
}

/// One router per app instance (a global would keep its location across
/// widget tests).
GoRouter createRouter() => GoRouter(
  initialLocation: _initialLocation(),
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/learn', builder: (c, s) => const LearnScreen()),
        GoRoute(path: '/drill', builder: (c, s) => const DrillScreen()),
        GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      ],
    ),
    // Full-screen flows sit outside the shell so the tab bar goes away.
    GoRoute(
      path: '/lesson/:id',
      pageBuilder: (c, s) => MaterialPage(
        fullscreenDialog: true,
        child: LessonScreen(lessonId: s.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/drill/run',
      pageBuilder: (c, s) {
        final q = s.uri.queryParameters;
        return MaterialPage(
          fullscreenDialog: true,
          child: DrillRunScreen(
            modes: q['modes'] == null
                ? null
                : {
                    for (final m in q['modes']!.split(','))
                      DrillMode.values.byName(m),
                  },
          ),
        );
      },
    ),
  ],
);
