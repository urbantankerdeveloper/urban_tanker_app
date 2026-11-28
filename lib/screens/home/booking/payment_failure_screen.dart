import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';

class PaymentFailureScreen extends StatelessWidget {
  const PaymentFailureScreen({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return AppScaffold(
      title: 'Payment not completed',
      body: ListView(
        padding: AppPageInsets.withSafeAreaBottom(
          context,
          AppPageInsets.standard,
        ),
        children: [
          SurfaceCard(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.danger.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.credit_card_off_outlined,
                    size: 44,
                    color: colors.danger.fg,
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Your payment was not completed.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: AppSpace.md),
                Text(
                  'Your booking is still available. You can try again or keep cash on delivery.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          PrimaryButton(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpace.sm),
          SecondaryButton(
            label: 'Keep cash on delivery',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
