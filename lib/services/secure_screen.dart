import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Blocks screenshots and screen recording (Android FLAG_SECURE) while sensitive
/// screens are visible. Calls are reference counted on the native side, so
/// nested screens do not clear the flag for each other. A no-op on iOS and in tests.
class SecureScreen {
  SecureScreen._();

  static const _channel = MethodChannel('urban_tanker/secure');

  static Future<void> enable() => _set(true);

  static Future<void> disable() => _set(false);

  static Future<void> _set(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on MissingPluginException {
      // Not every platform or test host provides the channel.
    } on PlatformException {
      // The screen still works without the flag.
    }
  }
}

/// Sets the secure flag while [child] is in the tree and clears it on dispose.
class SecureScope extends StatefulWidget {
  const SecureScope({required this.child, super.key});

  final Widget child;

  @override
  State<SecureScope> createState() => _SecureScopeState();
}

class _SecureScopeState extends State<SecureScope> {
  @override
  void initState() {
    super.initState();
    unawaited(SecureScreen.enable());
  }

  @override
  void dispose() {
    unawaited(SecureScreen.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
