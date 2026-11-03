import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';
import '../vendor_shared.dart';
import 'order_actions_sheet.dart';

/// Order in the vendor queue. Tapping the card opens the actions sheet. The
/// details button expands the card in place to show the service lines.
class VendorOrderCard extends StatefulWidget {
  const VendorOrderCard({required this.order, super.key});

  final VendorOrder order;

  @override
  State<VendorOrderCard> createState() => _VendorOrderCardState();
}

class _VendorOrderCardState extends State<VendorOrderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: EdgeInsets.zero,
      onTap: () => showAppBottomSheet<void>(
        context,
        builder: (_) => OrderActionsSheet(order: order),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
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
                BookingStatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              order.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            if (order.statusMessage?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: Text(
                  order.statusMessage!,
                  style: theme.textTheme.bodyMedium,
                ),
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
                Text(
                  formatDate(order.scheduledFor),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? 'Hide details' : 'Show details'),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.duration(context, AppMotion.base),
              curve: AppMotion.curve,
              alignment: Alignment.topCenter,
              child:
                  _expanded ? _Details(order: order) : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.order});

  final VendorOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          if (order.serviceDetails.isNotEmpty)
            for (final detail in order.serviceDetails) ...[
              Text(detail.service, style: theme.textTheme.titleSmall),
              if (detail.capacity.isNotEmpty)
                Text('Capacity/quantity: ${detail.capacity}'),
              if (detail.waterType?.isNotEmpty == true)
                Text('Water type: ${detail.waterType}'),
              if (detail.tankerCount?.isNotEmpty == true)
                Text('Tanker count: ${detail.tankerCount}'),
              if (detail.details.isNotEmpty) Text(detail.details),
              const SizedBox(height: AppSpace.sm),
            ]
          else if (order.serviceCode.isNotEmpty)
            Text(order.serviceCode.replaceAll('_', ' ')),
          if (order.latitude != null && order.longitude != null)
            Text(
              'Delivery coordinates: ${order.latitude!.toStringAsFixed(5)}, '
              '${order.longitude!.toStringAsFixed(5)}',
            ),
          if (order.cancellationReason?.trim().isNotEmpty == true)
            Text('Cancellation reason: ${order.cancellationReason}'),
          if (order.vehicle != null) Text('Vehicle: ${order.vehicle}'),
          if (order.driver != null) Text('Driver: ${order.driver}'),
        ],
      ),
    );
  }
}
