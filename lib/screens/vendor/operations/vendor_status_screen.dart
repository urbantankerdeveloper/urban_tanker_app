import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';

class VendorStatusScreen extends StatelessWidget {
  const VendorStatusScreen({required this.profile, super.key});

  final VendorBusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final verification = profile.verification.toLowerCase();
    final status = switch (verification) {
      'pending' => (
        title: 'Your application is under review',
        message:
            'We will notify you when the review is complete. You can continue to manage your business details while you wait.',
        icon: Icons.hourglass_top_outlined,
        tone: colors.warning,
      ),
      'rejected' || 'suspended' => (
        title: verification == 'rejected'
            ? 'Application not approved'
            : 'Account suspended',
        message:
            'Contact Urban Tanker support for help with your account status.',
        icon: Icons.info_outline,
        tone: colors.danger,
      ),
      'approved' when !profile.isOnline => (
        title: 'You are offline',
        message:
            'You are not receiving new orders. Turn on service availability when you are ready to work.',
        icon: Icons.cloud_off_outlined,
        tone: colors.neutral,
      ),
      _ => (
        title: 'Vendor status',
        message: 'Your account status is up to date.',
        icon: Icons.verified_outlined,
        tone: colors.success,
      ),
    };

    return AppScaffold(
      title: 'Vendor status',
      body: Center(
        child: SingleChildScrollView(
          padding: AppPageInsets.standard,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: status.tone.bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(status.icon, size: 44, color: status.tone.fg),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                Text(
                  status.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  status.message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                if (profile.businessName.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xl),
                  SurfaceCard(
                    child: AppListRow(
                      leading: const Icon(Icons.storefront_outlined),
                      title: profile.businessName,
                      subtitle: profile.serviceZone,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.xl),
                PrimaryButton(
                  label: 'Back to operations',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
