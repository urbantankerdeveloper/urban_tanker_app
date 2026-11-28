import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/auth_feature_flags.dart';
import '../../core/design_system/design_system.dart';
import '../security_settings_screen.dart';
import 'admin_pulse_screen.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({
    required this.controller,
    required this.onBackToHome,
    super.key,
  });

  final AppController controller;
  final VoidCallback onBackToHome;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Settings',
    body: ListView(
      padding: AppPageInsets.withSafeAreaBottom(
        context,
        AppPageInsets.standard,
      ),
      children: [
        Text('Account', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpace.md),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: AppListRow(
            leading: const Icon(Icons.lock_outline),
            title: 'Security settings',
            subtitle: 'Manage your MPIN and fingerprint sign-in.',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SecuritySettingsScreen(controller: controller),
              ),
            ),
          ),
        ),
        if (AuthFeatureFlags.showPlatformDiagnostics) ...[
          const SizedBox(height: AppSpace.xl),
          Text('Platform', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpace.md),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: AppListRow(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: 'Platform diagnostics',
              subtitle: 'Check integrations, storage and database migrations.',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminPulseScreen(onBackToHome: onBackToHome),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
