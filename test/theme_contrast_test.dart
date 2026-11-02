import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/app/theme.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final entry in {
    'light': buildLightTheme(),
    'dark': buildDarkTheme(),
  }.entries) {
    final name = entry.key;
    final theme = entry.value;
    final scheme = theme.colorScheme;
    final background = theme.scaffoldBackgroundColor;

    test('$name theme: body text meets WCAG AA on surfaces', () {
      expect(_contrast(scheme.onSurface, background), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onSurface, scheme.surface), greaterThanOrEqualTo(4.5));
      expect(
        _contrast(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('$name theme: error text and brand text meet WCAG AA', () {
      expect(_contrast(scheme.error, scheme.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.error, background), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.primary, background), greaterThanOrEqualTo(4.5));
    });

    test('$name theme: filled buttons meet WCAG AA', () {
      expect(
        _contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
