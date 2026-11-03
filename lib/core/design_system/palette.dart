import 'package:flutter/material.dart';

/// Raw brand and neutral colors. Screens should read colors through
/// `context.colors` (see app_colors.dart) rather than using these directly.
abstract final class AppPalette {
  // Brand, derived from the logo: teal mark with near-black ink accents.
  static const teal = Color(0xFF007C91);
  static const tealDeep = Color(0xFF005C6C);
  static const tealLight = Color(0xFF62D3DF);
  static const ink = Color(0xFF10343A);

  // Teal tonal ramp (approximate steps around the brand teal).
  static const teal50 = Color(0xFFE8F6F8);
  static const teal100 = Color(0xFFCDEBF0);
  static const teal200 = Color(0xFF9ADBE5);
  static const teal400 = Color(0xFF2AA3B7);
  static const teal700 = Color(0xFF006475);
  static const teal900 = Color(0xFF00434E);

  // Accents.
  static const mint = Color(0xFFC7EADB);
  static const amber = Color(0xFFF8CA63);
  // Darkened from the brand coral so error text meets WCAG AA on white.
  static const coral = Color(0xFFB8432F);
  static const coralDark = Color(0xFFFF9E8F);

  // Light neutrals.
  static const paper = Color(0xFFF5FBFC);
  static const hairline = Color(0xFFDCE9E8);
  static const white = Color(0xFFFFFFFF);

  // Dark neutrals.
  static const darkScaffold = Color(0xFF0B1B1E);
  static const darkSurface = Color(0xFF13282C);
  static const darkHairline = Color(0xFF274449);
}
