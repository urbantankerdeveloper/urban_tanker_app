import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';
import '../services/api_client.dart';
import '../services/biometric_auth_service.dart';
import '../services/realtime_service.dart';
import '../services/push_notification_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.api,
    required SharedPreferences preferences,
    BiometricAuthService? biometricAuth,
  })  : _preferences = preferences,
        biometricAuth = biometricAuth ?? BiometricAuthService();

  final ApiClient api;
  final SharedPreferences _preferences;
  final BiometricAuthService biometricAuth;
  SessionUser? user;
  RealtimeService? realtime;
  ThemeMode themeMode = ThemeMode.system;
  bool busy = false;
  bool biometricEnabled = false;
  bool biometricLocked = false;
  bool biometricPromptOffered = false;
  bool pendingBiometricEnrollment = false;
  String? phoneOtpChallengeId;
  String? errorMessage;
  String? successMessage;
  late final PushNotificationService pushNotifications =
      PushNotificationService(
    api: api,
    appId: const String.fromEnvironment('ONESIGNAL_APP_ID'),
  );

  bool get isSignedIn => user != null;

  static Future<AppController> create() async {
    final preferences = await SharedPreferences.getInstance();
    final controller = AppController(
      api: ApiClient(),
      preferences: preferences,
    );
    await controller.pushNotifications.initialize();
    controller.themeMode =
        themeModeFromName(preferences.getString('theme_mode')) ??
            ThemeMode.system;
    controller.biometricEnabled =
        preferences.getBool('biometric_enabled') ?? false;
    controller.biometricPromptOffered =
        preferences.getBool('biometric_prompt_offered') ?? false;
    final rawUser = preferences.getString('session_user');
    final token = await controller.api.readAccessToken();
    final refreshToken = await controller.api.readRefreshToken();
    if (rawUser != null && token != null) {
      try {
        final decoded = jsonDecode(rawUser);
        if (decoded is Map<String, dynamic>) {
          controller._setSession(
            AuthResult(
              user: SessionUser.fromJson(decoded),
              accessToken: token,
              refreshToken: refreshToken,
            ),
          );
        }
      } on FormatException {
        await preferences.remove('session_user');
        await controller.api.clearTokens();
      }
    }
    controller.biometricLocked =
        controller.user != null && controller.biometricEnabled;
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
      pendingBiometricEnrollment = !biometricEnabled && !biometricPromptOffered;
    });
  }

  Future<void> markBiometricPromptOffered() async {
    biometricPromptOffered = true;
    await _preferences.setBool('biometric_prompt_offered', true);
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    biometricEnabled = enabled;
    biometricLocked = false;
    pendingBiometricEnrollment = false;
    await _preferences.setBool('biometric_enabled', enabled);
    if (!enabled) {
      biometricPromptOffered = false;
      await _preferences.setBool('biometric_prompt_offered', false);
    }
    notifyListeners();
  }

  void lockBiometricSession() {
    if (user == null || !biometricEnabled || biometricLocked) return;
    biometricLocked = true;
    notifyListeners();
  }

  void unlockBiometricSession() {
    if (!biometricLocked) return;
    biometricLocked = false;
    notifyListeners();
  }

  Future<void> usePhoneOtpRecovery() async {
    await setBiometricEnabled(false);
    await signOut();
  }

  Future<void> signIn(String credential, String password) async {
    await _run(() async {
      final result = await api.login(credential.trim(), password);
      _setSession(result);
      pendingBiometricEnrollment = !biometricEnabled && !biometricPromptOffered;
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

  Future<void> signOut() async {
    await pushNotifications.clearIdentity();
    realtime?.dispose();
    realtime = null;
    user = null;
    await _preferences.remove('session_user');
    await api.clearTokens();
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
    _preferences.setString(
      'session_user',
      jsonEncode({
        'id': result.user.id,
        'name': result.user.name,
        'username': result.user.username,
        'role': result.user.role.name,
        'email': result.user.email,
      }),
    );
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
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
