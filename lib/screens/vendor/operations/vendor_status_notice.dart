import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';

class VendorStatusNotice extends StatelessWidget {
  const VendorStatusNotice({
    required this.profile,
    this.onViewStatus,
    super.key,
  });

  final VendorBusinessProfile profile;
  final VoidCallback? onViewStatus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final notice = switch (profile.verification.toLowerCase()) {
      'pending' => (
        title: 'Awaiting approval',
        message: 'Your vendor application is being reviewed.',
        icon: Icons.hourglass_top_outlined,
        tone: colors.warning,
      ),
      'rejected' => (
        title: 'Application not approved',
        message: 'Contact Urban Tanker support for help with your account.',
        icon: Icons.info_outline,
        tone: colors.danger,
      ),
      'suspended' => (
        title: 'Account suspended',
        message: 'Contact Urban Tanker support for help with your account.',
        icon: Icons.info_outline,
        tone: colors.danger,
      ),
      'approved' when !profile.isOnline => (
        title: 'You are offline',
        message:
            'Turn on your availability when you are ready to receive work.',
        icon: Icons.cloud_off_outlined,
        tone: colors.neutral,
      ),
      _ => null,
    };
    if (notice == null) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: '${notice.title}. ${notice.message}',
      child: SurfaceCard(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(notice.icon, color: notice.tone.fg),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    notice.message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (onViewStatus != null) ...[
                    const SizedBox(height: AppSpace.xs),
                    TextButton(
                      onPressed: onViewStatus,
                      child: const Text('View status'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
