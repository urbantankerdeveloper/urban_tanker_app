import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_controller.dart';
import 'app/auth_feature_flags.dart';
import 'app/providers.dart';
import 'core/design_system/new_ui_theme.dart';
import 'core/design_system/theme.dart';
import 'core/design_system/tokens.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UrbanTankerBootstrap());
}

class UrbanTankerBootstrap extends StatefulWidget {
  const UrbanTankerBootstrap({super.key});

  @override
  State<UrbanTankerBootstrap> createState() => _UrbanTankerBootstrapState();
}

class _UrbanTankerBootstrapState extends State<UrbanTankerBootstrap> {
  late Future<AppController> _controllerFuture;
  bool _pushInitializationStarted = false;

  @override
  void initState() {
    super.initState();
    _controllerFuture = AppController.create();
  }

  void _retryInitialization() {
    setState(() {
      _pushInitializationStarted = false;
      _controllerFuture = AppController.create();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppController>(
      future: _controllerFuture,
      builder: (context, snapshot) {
        final controller = snapshot.data;
        if (controller != null) {
          if (!_pushInitializationStarted) {
            _pushInitializationStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(_startFirebaseAndPush(controller));
            });
          }
          return ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: const UrbanTankerApp(),
          );
        }

        return MaterialApp(
          title: 'Urban Tanker',
          debugShowCheckedModeBanner: false,
          theme: AuthFeatureFlags.newUiEnabled
              ? buildNewUiLightTheme()
              : buildLightTheme(),
          darkTheme: AuthFeatureFlags.newUiEnabled
              ? buildNewUiDarkTheme()
              : buildDarkTheme(),
          themeMode: ThemeMode.system,
          home: snapshot.hasError
              ? _StartupErrorScreen(onRetry: _retryInitialization)
              : AuthFeatureFlags.newUiEnabled
                  ? const SplashScreen()
                  : const SizedBox.shrink(),
        );
      },
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: AppSize.stateIcon,
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Urban Tanker could not start.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Check your device and try again.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.xl),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Starts Firebase, then push, without blocking the first frame. A failure is
/// logged and the app keeps working without push.
Future<void> _startFirebaseAndPush(AppController controller) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    if (kDebugMode) debugPrint('Firebase failed to start: $error');
  }
  try {
    await controller.pushNotifications.initialize();
  } catch (error) {
    if (kDebugMode) debugPrint('Push notifications failed to start: $error');
  }
}
