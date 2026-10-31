import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'page_components.dart';
import 'theme.dart';
import '../screens/auth_screen.dart';
import '../screens/home_shell.dart';

class UrbanTankerApp extends ConsumerWidget {
  const UrbanTankerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      home: controller.isSignedIn
          ? HomeShell(controller: controller)
          : AuthScreen(controller: controller),
    );
  }
}
