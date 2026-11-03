import 'package:flutter/material.dart';

/// 4-pt spacing scale. Use these instead of literal padding values.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Horizontal page gutter.
  static const gutter = 20.0;
}

/// Corner radii. Use the border getters for `BorderRadius` values.
abstract final class AppRadius {
  static const chip = 10.0;
  static const input = 14.0;
  static const card = 20.0;
  static const sheet = 28.0;
  static const pill = 999.0;

  static const chipBorder = BorderRadius.all(Radius.circular(chip));
  static const inputBorder = BorderRadius.all(Radius.circular(input));
  static const cardBorder = BorderRadius.all(Radius.circular(card));
  static const sheetBorder = BorderRadius.vertical(top: Radius.circular(sheet));
  static const pillBorder = BorderRadius.all(Radius.circular(pill));
}

/// Sizes that must stay large enough to tap on a phone.
abstract final class AppSize {
  /// Minimum touch target (Material and WCAG guidance).
  static const minTouchTarget = 48.0;

  /// Height of primary, secondary and ghost buttons.
  static const buttonHeight = 52.0;
}
