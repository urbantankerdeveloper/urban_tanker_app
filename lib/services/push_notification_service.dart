import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'api_client.dart';

class PushNotificationService {
  PushNotificationService({
    required ApiClient api,
    required String appId,
  })  : _api = api,
        _appId = appId;

  final ApiClient _api;
  final String _appId;
  // Completes once initialize() has run, so identity calls never reach
  // OneSignal before it is set up.
  final _ready = Completer<void>();

  Future<void> initialize() async {
    if (kIsWeb || _appId.isEmpty) {
      _markReady();
      return;
    }
    try {
      OneSignal.initialize(_appId);
    } finally {
      _markReady();
    }
    await OneSignal.Notifications.requestPermission(true);
    OneSignal.User.pushSubscription.addObserver((state) {
      final id = state.current.id;
      if (id != null && id.isNotEmpty) {
        _register(id);
      }
    });
    final id = OneSignal.User.pushSubscription.id;
    if (id != null && id.isNotEmpty) await _register(id);
  }

  Future<void> identify(String userId) async {
    if (kIsWeb || _appId.isEmpty) return;
    await _ready.future;
    await OneSignal.login(userId);
    final id = OneSignal.User.pushSubscription.id;
    if (id != null && id.isNotEmpty) await _register(id);
  }

  Future<void> clearIdentity() async {
    if (kIsWeb || _appId.isEmpty) return;
    await _ready.future;
    await OneSignal.logout();
  }

  /// Removes this device from the server. Must run while the session is still valid.
  Future<void> unregister() async {
    if (kIsWeb || _appId.isEmpty) return;
    await _ready.future;
    final id = OneSignal.User.pushSubscription.id;
    if (id != null && id.isNotEmpty) await _api.unregisterDevice(id);
  }

  void _markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<void> _register(String id) async {
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await _api.registerDevice(token: id, platform: platform);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('OneSignal device registration failed: $error');
      }
    }
  }
}
