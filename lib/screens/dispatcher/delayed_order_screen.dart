import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/design_system.dart';
import '../../models/dispatcher.dart';
import '../common/booking_format.dart';
import 'dispatch_actions.dart';
import 'dispatch_assignment_screen.dart';

class DelayedOrderScreen extends ConsumerWidget {
  const DelayedOrderScreen({required this.rawOrder, super.key});

  final Map<String, dynamic> rawOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = DispatcherOrder.fromJson(rawOrder);
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Delayed order',
      body: ListView(
        padding: AppPageInsets.withSafeAreaBottom(
          context,
          AppPageInsets.standard,
        ),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.reference,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    StatusChip(
                      label: 'Delayed',
                      tone: context.colors.danger,
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                AppListRow(
                  leading: const Icon(Icons.sync_alt_outlined),
                  title: StatusChip.statusLabel(order.status),
                  subtitle: order.serviceCode.isEmpty
                      ? null
                      : order.serviceCode.replaceAll('_', ' '),
                ),
                AppListRow(
                  leading: const Icon(Icons.event_outlined),
                  title: formatBookingDate(order.scheduledFor),
                ),
                AppListRow(
                  leading: const Icon(Icons.location_on_outlined),
                  title: order.address.isEmpty
                      ? 'Address unavailable'
                      : order.address,
                ),
                AppListRow(
                  leading: const Icon(Icons.currency_rupee),
                  title: '₹${order.amountRupees.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('Resolve delivery delay', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpace.md),
          PrimaryButton(
            label: 'Call driver',
            icon: Icons.call_outlined,
            onPressed: order.driverId == null
                ? null
                : () => callAssignedDriver(context, ref, rawOrder),
          ),
          const SizedBox(height: AppSpace.md),
          SecondaryButton(
            label: 'Notify customer',
            icon: Icons.notifications_active_outlined,
            onPressed: () => notifyDelayedCustomer(context, ref, rawOrder),
          ),
          const SizedBox(height: AppSpace.md),
          SecondaryButton(
            label: 'Reassign order',
            icon: Icons.assignment_ind_outlined,
            onPressed: () => openDispatchAssignment(context, rawOrder),
          ),
        ],
      ),
    );
  }
}
