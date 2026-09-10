import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'services/settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FretboardTrainerApp()));
}

class FretboardTrainerApp extends ConsumerStatefulWidget {
  const FretboardTrainerApp({super.key});

  @override
  ConsumerState<FretboardTrainerApp> createState() =>
      _FretboardTrainerAppState();
}

class _FretboardTrainerAppState extends ConsumerState<FretboardTrainerApp> {
  final _router = createRouter();

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: 'Fretboard Trainer',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      routerConfig: _router,
    );
  }
}
