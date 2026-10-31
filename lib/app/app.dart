import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/biometric_lock_screen.dart';
import '../screens/public_tracking_screen.dart';
import '../services/tracking_link.dart';
import 'providers.dart';
import 'page_components.dart';
import 'theme.dart';
import '../screens/auth_screen.dart';
import '../screens/home_shell.dart';
import '../screens/selfie_capture_screen.dart';

class UrbanTankerApp extends ConsumerStatefulWidget {
  const UrbanTankerApp({super.key});

  @override
  ConsumerState<UrbanTankerApp> createState() => _UrbanTankerAppState();
}

class _UrbanTankerAppState extends ConsumerState<UrbanTankerApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final appLinks = AppLinks();
    unawaited(appLinks.getInitialLink().then(_openTrackingLink));
    _linkSubscription = appLinks.uriLinkStream.listen(_openTrackingLink);
  }

  void _openTrackingLink(Uri? uri) {
    if (!mounted || uri == null) return;
    final token = trackingTokenFromUri(uri);
    if (token == null) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openTrackingLink(uri));
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => PublicTrackingScreen(
          token: token,
          api: ref.read(appControllerProvider).api,
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(appControllerProvider).lockBiometricSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Urban Tanker',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: controller.themeMode,
      builder: (context, child) => ConnectivityBanner(
        child: child ?? const SizedBox.shrink(),
      ),
      home: controller.biometricLocked
          ? BiometricLockScreen(controller: controller)
          : controller.isSignedIn
              ? controller.requiresSelfie
                  ? SelfieCaptureScreen(controller: controller)
                  : HomeShell(controller: controller)
              : AuthScreen(controller: controller),
    );
  }
}
