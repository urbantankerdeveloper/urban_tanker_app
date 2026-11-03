import 'package:flutter/material.dart';

/// Manrope type scale. Material slots are mapped to the design names:
/// display 32/800, title1 24/800, title2 20/700, title3 17/700, body 15/500,
/// bodySmall 13/500, label 12/700, overline 11/800 (uppercase by the widget).
/// Weights resolve through the Manrope registrations in pubspec.yaml. Styles
/// have no fixed heights, so text scale up to 1.3 cannot clip.
TextTheme buildAppTextTheme(TextTheme base,
    {required Color ink, required Color muted}) {
  return base.apply(fontFamily: 'Manrope').copyWith(
        displaySmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: -0.5,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.4,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: ink,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: muted,
        ),
      );
}

/// Tabular figures for money and counts, so amounts line up in columns.
abstract final class AppTypography {
  static TextStyle numeric(TextStyle style) => style.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
