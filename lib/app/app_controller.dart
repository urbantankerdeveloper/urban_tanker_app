import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';
import '../services/api_client.dart';
import '../services/biometric_auth_service.dart';
import '../services/friendly_error.dart';
import '../services/invoice_files.dart';
import '../services/mpin_service.dart';
import '../services/realtime_service.dart';
import '../services/push_notification_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.api,
    required SharedPreferences preferences,
    BiometricAuthService? biometricAuth,
    MpinService? mpin,
  })  : _preferences = preferences,
        biometricAuth = biometricAuth ?? BiometricAuthService(),
        mpin = mpin ?? MpinService(store: const SecureMpinStore());

  final ApiClient api;
  final SharedPreferences _preferences;
  final BiometricAuthService biometricAuth;
  final MpinService mpin;
  SessionUser? user;
  RealtimeService? realtime;
  ThemeMode themeMode = ThemeMode.system;
  bool busy = false;
  bool biometricEnabled = false;
  bool mpinEnabled = false;
  bool sessionLocked = false;
  bool biometricPromptOffered = false;
  bool pendingUnlockSetup = false;
  String? phoneOtpChallengeId;
  String? errorMessage;
  String? successMessage;
  late final PushNotificationService pushNotifications =
      PushNotificationService(
    api: api,
    appId: const String.fromEnvironment('ONESIGNAL_APP_ID'),
  );

  bool get isSignedIn => user != null;

  bool get requiresSelfie => user?.selfieRequired ?? false;

  static Future<AppController> create() async {
    final preferences = await SharedPreferences.getInstance();
    final controller = AppController(
      api: ApiClient(),
      preferences: preferences,
    );
    controller.themeMode =
        themeModeFromName(preferences.getString('theme_mode')) ??
            ThemeMode.system;
    controller.biometricEnabled =
        preferences.getBool('biometric_enabled') ?? false;
    controller.biometricPromptOffered =
        preferences.getBool('biometric_prompt_offered') ?? false;
    controller.mpinEnabled = await controller.mpin.isSet();
    final token = await controller.api.readAccessToken();
    final refreshToken = await controller.api.readRefreshToken();
    var rawUser = await controller.api.readSessionUser();
    // Older builds kept the profile in SharedPreferences. Move it to secure
    // storage once and remove the plain copy.
    final legacyUser = preferences.getString('session_user');
    if (legacyUser != null) {
      await preferences.remove('session_user');
      try {
        final decoded = jsonDecode(legacyUser);
        if (rawUser == null && decoded is Map<String, dynamic>) {
          rawUser = decoded;
          await controller.api.saveSessionUser(decoded);
        }
      } on FormatException {
        // A corrupt legacy copy is simply dropped.
      }
    }
    if (rawUser != null && token != null) {
      try {
        controller._setSession(
          AuthResult(
            user: SessionUser.fromJson(rawUser),
            accessToken: token,
            refreshToken: refreshToken,
          ),
        );
      } on FormatException {
        await controller.api.clearSession();
      }
    }
    controller.sessionLocked =
        controller.user != null && controller.quickUnlockEnabled;
    return controller;
  }

  Future<void> requestPhoneAuthOtp(String phone) async {
    await _run(() async {
      phoneOtpChallengeId = await api.requestPhoneAuthOtp(phone);
      successMessage = 'Verification code sent. It expires in 10 minutes.';
    });
  }

  Future<void> signInWithPhoneAuthOtp({
    required String phone,
    required String otp,
    String? name,
  }) async {
    await _run(() async {
      final challengeId = phoneOtpChallengeId;
      if (challengeId == null) {
        throw StateError('Request a verification code before signing in.');
      }
      final result = await api.verifyPhoneAuthOtp(
        phone: phone,
        challengeId: challengeId,
        otp: otp,
        name: name,
      );
      phoneOtpChallengeId = null;
      _setSession(result);
      pendingUnlockSetup = !quickUnlockEnabled && !biometricPromptOffered;
    });
  }

  Future<void> markBiometricPromptOffered() async {
    biometricPromptOffered = true;
    await _preferences.setBool('biometric_prompt_offered', true);
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    biometricEnabled = enabled;
    sessionLocked = false;
    pendingUnlockSetup = false;
    await _preferences.setBool('biometric_enabled', enabled);
    if (!enabled) {
      biometricPromptOffered = false;
      await _preferences.setBool('biometric_prompt_offered', false);
    }
    notifyListeners();
  }

  void lockSession() {
    if (user == null || !quickUnlockEnabled || sessionLocked) return;
    sessionLocked = true;
    notifyListeners();
  }

  /// Fingerprint or MPIN can unlock the session.
  bool get quickUnlockEnabled => biometricEnabled || mpinEnabled;

  Future<void> setMpin(String pin) async {
    await mpin.setPin(pin);
    mpinEnabled = true;
    pendingUnlockSetup = false;
    notifyListeners();
  }

  /// Unlocks on a correct MPIN. After too many wrong tries the user is signed
  /// out and must use the phone OTP flow again.
  Future<MpinCheck> unlockWithMpin(String pin) async {
    final check = await mpin.verify(pin);
    if (check.isAccepted) {
      unlockSession();
    } else if (check.isLocked) {
      await usePhoneOtpRecovery();
    }
    return check;
  }

  Future<void> disableMpin() async {
    await mpin.clear();
    mpinEnabled = false;
    if (!biometricEnabled) sessionLocked = false;
    notifyListeners();
  }

  void unlockSession() {
    if (!sessionLocked) return;
    sessionLocked = false;
    notifyListeners();
  }

  Future<void> usePhoneOtpRecovery() async {
    await disableMpin();
    await setBiometricEnabled(false);
    await signOut();
  }

  Future<void> signIn(String credential, String password) async {
    await _run(() async {
      final result = await api.login(credential.trim(), password);
      _setSession(result);
      pendingUnlockSetup = !quickUnlockEnabled && !biometricPromptOffered;
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    await _run(() async {
      final result = await api.signup(
        email: email.trim(),
        password: password,
        name: name.trim(),
        phone: phone.trim(),
        themeMode: themeMode.name,
      );
      if (result == null) {
        successMessage =
            'Account created. Check your email for the confirmation link, then sign in.';
        return;
      }
      _setSession(result);
    });
  }

  Future<void> requestPasswordReset(String email) async {
    await _run(() async {
      await api.requestPasswordReset(email);
      successMessage =
          'If an account exists for that email, password reset instructions have been sent.';
    });
  }

  /// Signs out. Each remote step is best effort; local state is always cleared.
  Future<void> signOut() async {
    String? refreshToken;
    try {
      refreshToken = await api.readRefreshToken();
    } catch (_) {
      refreshToken = null;
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await api.logout(refreshToken);
      } catch (_) {
        // The server session expires on its own if this call fails.
      }
    }
    try {
      await pushNotifications.unregister();
    } catch (_) {
      // The device token is replaced the next time someone signs in here.
    }
    try {
      await pushNotifications.clearIdentity();
    } catch (_) {
      // OneSignal keeps its own state; the app session is still cleared.
    }
    realtime?.dispose();
    realtime = null;
    user = null;
    sessionLocked = false;
    try {
      await api.clearSession();
    } catch (_) {
      // Secure storage failed; the in-memory session is already gone.
    }
    try {
      await _preferences.remove('session_user');
    } catch (_) {
      // Only a legacy key lives here, so a failure is harmless.
    }
    await deleteSavedInvoiceFiles();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _preferences.setString('theme_mode', mode.name);
    notifyListeners();
    if (user != null) {
      try {
        await api.updateThemePreference(mode.name);
      } catch (_) {
        // The local choice is kept; it is sent again the next time it changes.
      }
    }
  }

  void clearError() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }

  static ThemeMode? themeModeFromName(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };

  void markSelfieCaptured() {
    final current = user;
    if (current == null) return;
    final updated = current.copyWith(selfieRequired: false);
    user = updated;
    unawaited(_persistSessionUser(updated));
    notifyListeners();
  }

  Future<void> _persistSessionUser(SessionUser sessionUser) async {
    try {
      await api.saveSessionUser({
        'id': sessionUser.id,
        'name': sessionUser.name,
        'username': sessionUser.username,
        'role': sessionUser.role.name,
        'email': sessionUser.email,
        'selfieRequired': sessionUser.selfieRequired,
      });
    } catch (_) {
      // The session stays in memory and is saved again on the next change.
    }
  }

  void _setSession(AuthResult result) {
    user = result.user;
    final savedTheme = themeModeFromName(result.user.themeMode);
    if (savedTheme != null) {
      themeMode = savedTheme;
      unawaited(_preferences.setString('theme_mode', savedTheme.name));
    }
    final userId = result.user.id;
    if (userId != null) {
      unawaited(pushNotifications.identify(userId));
    }
    unawaited(_persistSessionUser(result.user));
    final socketUrl = const String.fromEnvironment('SOCKET_URL');
    realtime?.dispose();
    realtime = RealtimeService(
      socketUrl: socketUrl.isNotEmpty
          ? socketUrl
          : api.baseUrl.replaceFirst(RegExp(r'/api$'), ''),
      readToken: api.readAccessToken,
    );
    realtime!.connect((_, __) {});
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() operation) async {
    busy = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();
    try {
      await operation();
    } catch (error) {
      errorMessage = friendlyError(error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
