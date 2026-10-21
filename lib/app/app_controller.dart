import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';
import '../services/api_client.dart';
import '../services/realtime_service.dart';
import '../services/push_notification_service.dart';

class AppController extends ChangeNotifier {
  AppController._(this.api, this._preferences);

  final ApiClient api;
  final SharedPreferences _preferences;
  SessionUser? user;
  RealtimeService? realtime;
  ThemeMode themeMode = ThemeMode.system;
  bool busy = false;
  String? errorMessage;
  late final PushNotificationService pushNotifications =
      PushNotificationService(
    api: api,
    appId: const String.fromEnvironment('ONESIGNAL_APP_ID'),
  );

  bool get isSignedIn => user != null;

  static Future<AppController> create() async {
    final preferences = await SharedPreferences.getInstance();
    final controller = AppController._(ApiClient(), preferences);
    await controller.pushNotifications.initialize();
    controller.themeMode = switch (preferences.getString('theme_mode')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
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
    return controller;
  }

  Future<void> signIn(String credential, String password) async {
    await _run(() async {
      final result = await api.login(credential.trim(), password);
      _setSession(result);
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
      );
      _setSession(result);
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
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void _setSession(AuthResult result) {
    user = result.user;
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
    realtime = RealtimeService(
      socketUrl: socketUrl.isNotEmpty
          ? socketUrl
          : api.baseUrl.replaceFirst(RegExp(r'/api$'), ''),
      token: result.accessToken,
    );
    realtime!.connect((_, __) {});
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() operation) async {
    busy = true;
    errorMessage = null;
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
