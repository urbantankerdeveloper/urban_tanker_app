import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? localAuthentication})
      : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  Future<bool> canAuthenticate() async {
    if (kIsWeb) return false;
    try {
      return await _localAuthentication.isDeviceSupported() &&
          (await _localAuthentication.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    if (kIsWeb) return false;
    return _localAuthentication.authenticate(
      localizedReason: reason,
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}
