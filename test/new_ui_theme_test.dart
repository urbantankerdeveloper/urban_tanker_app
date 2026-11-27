import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_tanker_app/core/design_system/app_colors.dart';
import 'package:urban_tanker_app/core/design_system/new_ui_theme.dart';
import 'package:urban_tanker_app/screens/splash_screen.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('the light redesign uses the published website palette',
      (tester) async {
    final theme = buildNewUiLightTheme();
    final colors = theme.extension<AppColors>()!;
    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const Text('Urban Tanker')),
    );
    await tester.pumpAndSettle();

    expect(colors.primary, NewUiTokens.primary);
    expect(colors.ink, const Color(0xFF10343A));
    expect(colors.scaffold, const Color(0xFFF5FBFC));
    expect(colors.hairline, const Color(0xFFDCE9E8));
    expect(
      _contrast(theme.colorScheme.onSurface, theme.scaffoldBackgroundColor),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(colors.success.fg, colors.success.bg),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(colors.warning.fg, colors.warning.bg),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(colors.danger.fg, colors.danger.bg),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('the dark redesign preserves its semantic contrast pairs',
      (tester) async {
    final theme = buildNewUiDarkTheme();
    final colors = theme.extension<AppColors>()!;
    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const Text('Urban Tanker')),
    );
    await tester.pumpAndSettle();

    expect(colors.primary, NewUiTokens.primary);
    expect(colors.scaffold, const Color(0xFF0B1418));
    expect(colors.surface, const Color(0xFF121E24));
    expect(
      _contrast(theme.colorScheme.onSurface, theme.scaffoldBackgroundColor),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(colors.success.fg, colors.success.bg),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(colors.warning.fg, colors.warning.bg),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(colors.danger.fg, colors.danger.bg),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(theme.colorScheme.onPrimary, theme.colorScheme.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('the startup splash uses the brand mark and loading state',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildNewUiLightTheme(),
        home: const SplashScreen(),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Urban Tanker logo'), findsOneWidget);
    expect(find.text('URBAN TANKER'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
