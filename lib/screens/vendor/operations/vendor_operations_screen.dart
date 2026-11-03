import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';
import '../../../services/friendly_error.dart';
import '../../../services/realtime_service.dart';
import '../vendor_shared.dart';
import 'order_card.dart';
import 'saved_updates_card.dart';

const _needsActionStatuses = ['pending_vendor', 'vendor_assigned'];
const _inProgressStatuses = ['accepted', 'en_route', 'arrived'];
const _completedStatuses = ['delivered', 'cancelled'];

/// Vendor operations tab: a summary of the queue, search and filters, the
/// order cards, and the saved update records.
class VendorOperationsScreen extends ConsumerStatefulWidget {
  const VendorOperationsScreen({super.key});

  @override
  ConsumerState<VendorOperationsScreen> createState() =>
      _VendorOperationsScreenState();
}

class _VendorOperationsScreenState
    extends ConsumerState<VendorOperationsScreen> {
  final _searchController = TextEditingController();
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _realtimeSubscription =
        ref.read(appControllerProvider).realtime?.events.listen((event) {
      if (event.name != 'vendor.order.created' &&
          event.name != 'vendor.order.taken' &&
          event.name != 'vendor.order.declined' &&
          event.name != 'booking.updated') {
        return;
      }
      ref
        ..invalidate(vendorOrdersProvider)
        ..invalidate(vendorDashboardProvider);
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(vendorOrdersProvider);
    return orders.when(
      loading: () => const LoadingState(message: 'Loading your orders...'),
      error: (error, _) => VendorError(
        message: friendlyError(error),
        retry: () => ref.invalidate(vendorOrdersProvider),
      ),
      data: (items) {
        final filtered = items.where(_matchesOrder).toList();
        // Fixed summary, search and filter controls above the order cards, and
        // the saved update records below them. Only the order cards are lazy.
        final header = <Widget>[
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Needs action',
                  value: '${_count(items, _needsActionStatuses)}',
                  icon: Icons.pending_actions_outlined,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: StatCard(
                  label: 'In progress',
                  value: '${_count(items, _inProgressStatuses)}',
                  icon: Icons.local_shipping_outlined,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: StatCard(
                  label: 'Completed',
                  value: '${_count(items, _completedStatuses)}',
                  icon: Icons.check_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          AppTextField(
            controller: _searchController,
            label: 'Search orders',
            prefix: const Icon(Icons.search),
            suffix: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final status in [
                'All',
                'Needs action',
                'In progress',
                'Completed',
              ])
                ChoiceChip(
                  label: Text(status),
                  selected: _statusFilter == status,
                  onSelected: (_) => setState(() => _statusFilter = status),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            '${filtered.length} of ${items.length} orders',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpace.md),
        ];
        final footer = <Widget>[const SavedUpdatesCard()];
        // An empty-state message takes the place of the order cards.
        final rowCount =
            items.isEmpty || filtered.isEmpty ? 1 : filtered.length;
        return RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(vendorOrdersProvider)
              ..invalidate(vendorDashboardProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.lg,
              AppSpace.gutter,
              AppSpace.xxxl,
            ),
            itemCount: header.length + rowCount + footer.length,
            itemBuilder: (_, index) {
              if (index < header.length) return header[index];
              index -= header.length;
              if (index < rowCount) {
                if (items.isEmpty) {
                  return const VendorEmpty(message: 'No assigned orders yet.');
                }
                if (filtered.isEmpty) {
                  return const VendorEmpty(
                    message: 'No orders match these filters.',
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: VendorOrderCard(order: filtered[index]),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: footer[index - rowCount],
              );
            },
          ),
        );
      },
    );
  }

  static int _count(List<VendorOrder> items, List<String> statuses) =>
      items.where((order) => statuses.contains(order.status)).length;

  bool _matchesOrder(VendorOrder order) {
    final statusMatches = switch (_statusFilter) {
      'Needs action' => _needsActionStatuses.contains(order.status),
      'In progress' => _inProgressStatuses.contains(order.status),
      'Completed' => _completedStatuses.contains(order.status),
      _ => true,
    };
    if (!statusMatches) return false;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      order.reference,
      order.serviceCode,
      order.address,
      ...order.serviceDetails.map((detail) => detail.service),
      ...order.serviceDetails.map((detail) => detail.details),
    ].any((value) => value.toLowerCase().contains(query));
  }
}
