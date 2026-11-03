import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/core/design_system/app_colors.dart';
import 'package:urban_tanker_app/core/design_system/theme.dart';

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
    'light': AppColors.light,
    'dark': AppColors.dark,
  }.entries) {
    final name = entry.key;
    final colors = entry.value;

    test('$name: every status and semantic tone meets WCAG AA', () {
      final tones = {
        'success': colors.success,
        'warning': colors.warning,
        'danger': colors.danger,
        'info': colors.info,
        'neutral': colors.neutral,
        'pending': colors.statusPending,
        'accepted': colors.statusAccepted,
        'assigned': colors.statusAssigned,
        'onTheWay': colors.statusOnTheWay,
        'delivered': colors.statusDelivered,
        'cancelled': colors.statusCancelled,
        'rejected': colors.statusRejected,
      };
      for (final tone in tones.entries) {
        expect(
          _contrast(tone.value.fg, tone.value.bg),
          greaterThanOrEqualTo(4.5),
          reason: '${tone.key} text on its background',
        );
      }
    });

    test('$name: text on brand and hero gradients meets WCAG AA', () {
      for (final gradient in [
        colors.brandGradient,
        colors.heroGradient,
      ]) {
        for (final stop in gradient.colors) {
          expect(
            _contrast(colors.onHero, stop),
            greaterThanOrEqualTo(4.5),
            reason: 'onHero on $stop',
          );
        }
      }
    });

    test('$name theme exposes AppColors', () {
      final theme = name == 'light' ? buildLightTheme() : buildDarkTheme();
      expect(theme.extension<AppColors>(), isNotNull);
      expect(theme.extension<AppColors>()!.isDark, name == 'dark');
    });
  }

  test('statusTone maps backend statuses and falls back to neutral', () {
    final colors = AppColors.light;
    expect(colors.statusTone('pending_vendor'), colors.statusPending);
    expect(colors.statusTone('in_transit'), colors.statusOnTheWay);
    expect(colors.statusTone('completed'), colors.statusDelivered);
    expect(colors.statusTone('something_new'), colors.neutral);
  });
}
