import 'package:flutter/foundation.dart';

const _configuredMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

class MapProviderResolver extends ChangeNotifier {
  MapProviderResolver({
    String? apiKey,
    bool? platformSupported,
  })  : _hasApiKey = (apiKey ?? _configuredMapsApiKey).trim().isNotEmpty,
        _platformSupported = platformSupported ??
            (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS));

  static final MapProviderResolver instance = MapProviderResolver();

  final bool _hasApiKey;
  final bool _platformSupported;
  bool _unavailable = false;

  bool get useGoogleMaps => _hasApiKey && _platformSupported && !_unavailable;

  void markUnavailable() {
    if (_unavailable) return;
    _unavailable = true;
    notifyListeners();
  }
}
