import 'dart:async';

import 'package:flutter/foundation.dart';

/// Holds a resend action for [seconds] after each code is sent. Listen to it to
/// rebuild the button label as the count goes down.
class ResendCooldown extends ChangeNotifier {
  static const defaultSeconds = 30;

  int _remaining = 0;
  Timer? _timer;

  int get remaining => _remaining;

  bool get active => _remaining > 0;

  /// [seconds] comes from the server's `resendAfterSeconds`.
  void start([int seconds = defaultSeconds]) {
    _timer?.cancel();
    _remaining = seconds;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remaining--;
      notifyListeners();
      if (_remaining <= 0) timer.cancel();
    });
  }

  /// Ends the countdown early, for example when the user changes the address.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _remaining = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
