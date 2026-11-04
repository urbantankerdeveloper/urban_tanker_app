import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';
import 'package:urban_tanker_app/screens/auth_screen.dart';
import 'package:urban_tanker_app/services/api_client.dart';

Widget _host(
  Widget child, {
  required ThemeData theme,
  bool disableAnimations = false,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 740),
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child,
    ),
  );
}

Future<AppController> _controller(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await tester.runAsync(SharedPreferences.getInstance);
  return AppController(api: ApiClient(), preferences: preferences!);
}

void main() {
  testWidgets('auth renders in both themes at 1.3x text without exceptions',
      (tester) async {
    final controller = await _controller(tester);
    for (final theme in [buildLightTheme(), buildDarkTheme()]) {
      await tester.pumpWidget(
        _host(
          AuthScreen(
            key: ValueKey(theme.brightness),
            controller: controller,
          ),
          theme: theme,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedTabs),
          matching: find.text('Sign in'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Username'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    addTearDown(controller.dispose);
  });

  testWidgets('reduced motion lets the auth screen settle with no loops',
      (tester) async {
    final controller = await _controller(tester);
    await tester.pumpWidget(
      _host(
        AuthScreen(controller: controller),
        theme: buildDarkTheme(),
        disableAnimations: true,
      ),
    );
    // Would time out if the backdrop or logo kept animating.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    addTearDown(controller.dispose);
  });

  testWidgets('PIN pad shakes on a new signal and settles', (tester) async {
    var digits = 0;
    Widget pad(int signal) => _host(
          Scaffold(
            body: PinPad(
              entered: digits,
              onDigit: (_) => digits++,
              onDelete: () {},
              onSubmit: () {},
              shakeSignal: signal,
            ),
          ),
          theme: buildLightTheme(),
        );

    await tester.pumpWidget(pad(0));
    expect(
      tester.getCenter(find.text('4')).dy - tester.getCenter(find.text('1')).dy,
      greaterThan(72),
    );
    await tester.tap(find.text('4'));
    await tester.pumpWidget(pad(1));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(digits, 1);
    expect(tester.takeException(), isNull);
  });
}
