import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'features/splash/splash.dart';
import 'services/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final splash = launchRoute() == null ? await nextSighting() : null;
  runApp(ProviderScope(child: FretboardTrainerApp(splash: splash)));
}

class FretboardTrainerApp extends ConsumerStatefulWidget {
  const FretboardTrainerApp({super.key, this.splash});

  /// Cryptid splash shown over the first screen; null (tests) shows none.
  final Sighting? splash;

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
      title: 'Fretman',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      routerConfig: _router,
      builder: widget.splash == null
          ? null
          : (context, child) =>
                SplashGate(sighting: widget.splash!, child: child!),
    );
  }
}
