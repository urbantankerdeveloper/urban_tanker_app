import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';
import '../../common/booking_format.dart';

class VendorOrderAcceptedScreen extends StatelessWidget {
  const VendorOrderAcceptedScreen({required this.order, super.key});

  final VendorOrder order;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Order accepted',
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
                      color: colors.success.bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 48,
                      color: colors.success.fg,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                Text(
                  'Order accepted',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  '${order.reference} is now in your active orders.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpace.xl),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppListRow(
                        leading: const Icon(Icons.local_shipping_outlined),
                        title: order.serviceCode.isEmpty
                            ? 'Service details unavailable'
                            : order.serviceCode.replaceAll('_', ' '),
                      ),
                      AppListRow(
                        leading: const Icon(Icons.location_on_outlined),
                        title: order.address.isEmpty
                            ? 'Address unavailable'
                            : order.address,
                      ),
                      AppListRow(
                        leading: const Icon(Icons.schedule_outlined),
                        title: formatBookingDate(order.scheduledFor),
                      ),
                      AppListRow(
                        leading: const Icon(Icons.currency_rupee),
                        title: '₹${order.amountRupees.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                PrimaryButton(
                  label: 'Continue to operations',
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
