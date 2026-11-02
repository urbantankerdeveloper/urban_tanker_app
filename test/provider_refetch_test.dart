import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _CountingApi extends ApiClient {
  int adminHealthCalls = 0;

  @override
  Future<Map<String, dynamic>> adminHealth() async {
    adminHealthCalls++;
    return const {};
  }
}

void main() {
  test('theme and biometric changes do not re-run API providers', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = _CountingApi();
    final controller = AppController(api: api, preferences: preferences);
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => controller)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(adminHealthProvider, (_, __) {});
    await container.read(adminHealthProvider.future);
    expect(api.adminHealthCalls, 1);

    await controller.setThemeMode(ThemeMode.dark);
    await controller.setBiometricEnabled(true);
    controller.lockSession();
    controller.unlockSession();
    await Future<void>.delayed(Duration.zero);

    expect(api.adminHealthCalls, 1);
    subscription.close();
  });
}
