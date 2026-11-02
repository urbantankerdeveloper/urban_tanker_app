import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_controller.dart';
import 'app/providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only local reads (preferences and the saved session) happen before runApp.
  final controller = await AppController.create();
  runApp(
    ProviderScope(
      overrides: [
        appControllerProvider.overrideWith((ref) => controller),
      ],
      child: const UrbanTankerApp(),
    ),
  );
  unawaited(_startFirebaseAndPush(controller));
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
