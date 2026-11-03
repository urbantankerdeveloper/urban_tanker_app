import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/design_system/design_system.dart';

/// Theme modes in the order the Menu shows them.
const appearanceModes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };

/// Light, Dark and System as an animated segmented control. Used in the Menu.
class AppearanceControl extends StatelessWidget {
  const AppearanceControl({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SegmentedTabs(
        labels: [for (final mode in appearanceModes) themeModeLabel(mode)],
        selectedIndex: appearanceModes.indexOf(controller.themeMode),
        onChanged: (index) => controller.setThemeMode(appearanceModes[index]),
      ),
    );
  }
}
