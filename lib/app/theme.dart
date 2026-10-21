import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

const ink = Color(0xFF10343A);
const aqua = Color(0xFF007C91);
const aquaDark = Color(0xFF005C6C);
const paper = Color(0xFFF5FBFC);
const line = Color(0xFFDCE9E8);
const mint = Color(0xFFC7EADB);
const yellow = Color(0xFFF8CA63);
const coral = Color(0xFFD96250);

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final theme = (dark
          ? FlexColorScheme.dark(
              primary: const Color(0xFF62D3DF),
              secondary: mint,
              surface: const Color(0xFF13282C),
              error: const Color(0xFFFF9E8F),
              appBarBackground: const Color(0xFF0B1B1E),
              scaffoldBackground: const Color(0xFF0B1B1E),
            )
          : FlexColorScheme.light(
              primary: aqua,
              secondary: aquaDark,
              surface: Colors.white,
              error: coral,
              scaffoldBackground: paper,
              appBarBackground: paper,
            ))
      .toTheme;
  final scheme = theme.colorScheme;
  return theme.copyWith(
    useMaterial3: true,
    fontFamily: 'Manrope',
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF0B1B1E) : paper,
      foregroundColor: scheme.onSurface,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dark ? const Color(0xFF274449) : line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF13282C) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? const Color(0xFF274449) : line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? const Color(0xFF274449) : line),
      ),
    ),
  );
}

ThemeData buildLightTheme() => _theme(Brightness.light);
ThemeData buildDarkTheme() => _theme(Brightness.dark);
