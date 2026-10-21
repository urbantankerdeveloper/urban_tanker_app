import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_controller.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await AppController.create();
  runApp(
    ProviderScope(
      overrides: [
        appControllerProvider.overrideWith(() => controller),
      ],
      child: const UrbanTankerApp(),
    ),
  );
}
