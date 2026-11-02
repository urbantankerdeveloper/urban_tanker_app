import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/screens/app_lock_screen.dart';
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

Future<AppController> _lockedController() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final controller = AppController(
    api: ApiClient(),
    preferences: preferences,
    mpin: MpinService(store: _MemoryStore()),
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
}
