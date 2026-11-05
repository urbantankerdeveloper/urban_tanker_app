import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';
import 'package:urban_tanker_app/screens/app_lock_screen.dart';
import 'package:urban_tanker_app/screens/home/shell/unlock_offer.dart';
import 'package:urban_tanker_app/screens/unlock_setup_screen.dart';
import 'package:urban_tanker_app/services/api_client.dart';
import 'package:urban_tanker_app/services/mpin_service.dart';

class _MemoryStore implements MpinStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _MpinApi extends ApiClient {
  _MpinApi() : super(baseUrl: 'https://example.test/api');

  @override
  Future<void> saveMpin(String pin) async {}

  @override
  Future<void> deleteMpin() async {}
}

/// Stands in for PBKDF2 so widget tests don't wait on a background isolate,
/// which fake-async never completes. The real derivation is covered in
/// mpin_service_test.dart.
Future<List<int>> _fastKdf(String pin, List<int> salt, int iterations) async =>
    sha256.convert([...salt, ...utf8.encode(pin)]).bytes;

Future<AppController> _lockedController() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final controller = AppController(
    api: _MpinApi(),
    preferences: preferences,
    mpin: MpinService(store: _MemoryStore(), kdf: _fastKdf),
  );
  await controller.setMpin('1234');
  controller.sessionLocked = true;
  return controller;
}

Future<void> _enter(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
  await tester.tap(find.byTooltip('Unlock'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a wrong MPIN keeps the app locked and shows attempts left',
      (tester) async {
    final controller = await _lockedController();
    await tester.pumpWidget(
      MaterialApp(home: AppLockScreen(controller: controller)),
    );

    expect(find.text('Forgot MPIN? Recover with phone OTP'), findsOneWidget);
    await _enter(tester, '9999');

    expect(find.text('Incorrect MPIN. 4 attempts left.'), findsOneWidget);
    expect(controller.sessionLocked, isTrue);
  });

  testWidgets('the correct MPIN unlocks the session', (tester) async {
    final controller = await _lockedController();
    await tester.pumpWidget(
      MaterialApp(home: AppLockScreen(controller: controller)),
    );

    await _enter(tester, '1234');

    expect(controller.sessionLocked, isFalse);
  });

  testWidgets('the MPIN reset screen explains and labels the reset flow',
      (tester) async {
    final controller = await _lockedController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: UnlockSetupScreen(controller: controller, isReset: true),
      ),
    );

    expect(find.text('Reset your MPIN'), findsOneWidget);
    expect(find.text('Choose a new 4 to 6 digit MPIN.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byTooltip('Continue'), findsOneWidget);
  });

  testWidgets('phone recovery opens the reset screen after sign-in',
      (tester) async {
    final controller = await _lockedController();
    controller.pendingMpinReset = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => offerUnlockSetup(context, controller),
              child: const Text('Continue recovery'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue recovery'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your MPIN'), findsOneWidget);
  });
}
