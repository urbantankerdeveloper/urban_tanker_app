import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_controller.dart';
import 'app/providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final controller = await AppController.create();
  runApp(
    ProviderScope(
      overrides: [
        appControllerProvider.overrideWith((ref) => controller),
      ],
      child: const UrbanTankerApp(),
    ),
  );
}
