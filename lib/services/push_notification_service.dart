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

  Future<void> initialize() async {
    if (kIsWeb || _appId.isEmpty) return;
    OneSignal.initialize(_appId);
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
    await OneSignal.login(userId);
    final id = OneSignal.User.pushSubscription.id;
    if (id != null && id.isNotEmpty) await _register(id);
  }

  Future<void> clearIdentity() async {
    if (kIsWeb || _appId.isEmpty) return;
    await OneSignal.logout();
  }

  Future<void> _register(String id) async {
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await _api.registerDevice(token: id, platform: platform);
    } catch (error) {
      debugPrint('OneSignal device registration failed: $error');
    }
  }
}
