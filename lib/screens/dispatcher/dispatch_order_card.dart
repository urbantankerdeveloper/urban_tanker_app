import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/design_system.dart';
import '../../models/dispatcher.dart';
import '../common/booking_format.dart';
import 'dispatch_actions.dart';
import 'dispatch_urgency.dart';

/// One order in the dispatch queue. An unassigned order gets a one-tap assign
/// button. Every other action is in the more menu.
class DispatchOrderCard extends ConsumerWidget {
  const DispatchOrderCard({required this.raw, super.key});

  /// The order as the server sent it. Actions still take this map.
  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final order = DispatcherOrder.fromJson(raw);
    final urgency = dispatchUrgency(order);
    final (label, tone, icon) = switch (urgency) {
      DispatchUrgency.urgent => ('Urgent', colors.danger, Icons.priority_high),
      DispatchUrgency.needsVendor => (
          'Needs vendor',
          colors.warning,
          Icons.assignment_late_outlined,
        ),
      DispatchUrgency.inProgress => (
          'In progress',
          colors.info,
          Icons.local_shipping_outlined,
        ),
      DispatchUrgency.scheduled => (
          'Scheduled',
          colors.neutral,
          Icons.schedule,
        ),
      DispatchUrgency.done => ('Done', colors.success, Icons.check),
    };
    final canAssign = !order.isAssigned && order.status == 'pending_vendor';
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      onTap: () => showOrderDetails(context, raw),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              StatusChip(label: label, tone: tone, icon: icon),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            '${StatusChip.statusLabel(order.status)} • '
            '${formatBookingDate(order.scheduledFor)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            order.address.isEmpty ? 'Address unavailable' : order.address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: AmountText(
                  '₹${order.amountRupees.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (canAssign)
                PrimaryButton(
                  label: 'Assign',
                  icon: Icons.assignment_ind_outlined,
                  expand: false,
                  onPressed: () => assignOrder(context, ref, raw),
                ),
              IconButton(
                tooltip: 'More actions',
                onPressed: () => showDispatchActions(context, ref, raw),
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
