import 'package:flutter/material.dart';

/// Warm wood-and-brass palette; the fretboard painter reads these too.
const seedColor = Color(0xFF8B4A1F);
const fretboardWood = Color(0xFF5A3A21);
const fretboardWoodDark = Color(0xFF3E2716);
const fretWire = Color(0xFFC9C3B8);
const nutColor = Color(0xFFEDE6D6);
const inlayColor = Color(0xFFD8CDB6);
const stringColor = Color(0xFFE6DFCF);
const markerColor = Color(0xFFE8A33D);
const markerText = Color(0xFF2A1A0E);
const correctColor = Color(0xFF2E8B46);
const wrongColor = Color(0xFFC93030);

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: b);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
    dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
