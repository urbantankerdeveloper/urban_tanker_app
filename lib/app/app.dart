import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/biometric_lock_screen.dart';
import 'providers.dart';
import 'page_components.dart';
import 'theme.dart';
import '../screens/auth_screen.dart';
import '../screens/home_shell.dart';

class UrbanTankerApp extends ConsumerStatefulWidget {
  const UrbanTankerApp({super.key});

  @override
  ConsumerState<UrbanTankerApp> createState() => _UrbanTankerAppState();
}

class _UrbanTankerAppState extends ConsumerState<UrbanTankerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    return MaterialApp(
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
              ? HomeShell(controller: controller)
              : AuthScreen(controller: controller),
    );
  }
}
