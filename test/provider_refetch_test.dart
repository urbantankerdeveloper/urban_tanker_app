import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/services/api_client.dart';
import 'package:urban_tanker_app/services/biometric_auth_service.dart';

class _FakeBiometricAuthService extends BiometricAuthService {
  bool authenticated = false;
  int authenticationCalls = 0;

  @override
  Future<bool> authenticate(String reason) async {
    authenticationCalls++;
    return authenticated;
  }
}

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
    await controller.setBookingBiometricEnabled(true);
    controller.lockSession();
    controller.unlockSession();
    await Future<void>.delayed(Duration.zero);

    expect(api.adminHealthCalls, 1);
    expect(preferences.getBool('booking_biometric_enabled'), isTrue);
    subscription.close();
  });

  test(
    'booking confirmation only prompts when its biometric setting is on',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final biometricAuth = _FakeBiometricAuthService();
      final controller = AppController(
        api: _CountingApi(),
        preferences: preferences,
        biometricAuth: biometricAuth,
      );

      expect(await controller.authorizeBookingConfirmation(), isTrue);
      expect(biometricAuth.authenticationCalls, 0);

      await controller.setBookingBiometricEnabled(true);
      expect(await controller.authorizeBookingConfirmation(), isFalse);
      expect(biometricAuth.authenticationCalls, 1);
      expect(preferences.getBool('booking_biometric_enabled'), isTrue);

      biometricAuth.authenticated = true;
      expect(await controller.authorizeBookingConfirmation(), isTrue);
      expect(biometricAuth.authenticationCalls, 2);
    },
  );
}
