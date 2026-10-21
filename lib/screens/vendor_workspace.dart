import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../models/vendor.dart';

class VendorOperationsScreen extends ConsumerWidget {
  const VendorOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(vendorOrdersProvider);
    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _VendorError(
        message: error.toString(),
        retry: () => ref.invalidate(vendorOrdersProvider),
      ),
      data: (items) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(vendorOrdersProvider),
        child: items.isEmpty
            ? ListView(
                children: const [
                  _VendorEmpty(message: 'No assigned orders yet.'),
                  _OfflineMutationsCard(),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OrderCard(order: item),
                      )),
                  const _OfflineMutationsCard(),
                ],
              ),
      ),
    );
  }
}

class _OfflineMutationsCard extends ConsumerWidget {
  const _OfflineMutationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutations = ref.watch(vendorOfflineMutationsProvider);
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.sync_problem_outlined),
        title: const Text('Offline sync'),
        children: [
          mutations.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => ListTile(
              title: const Text('Could not load pending mutations'),
              subtitle: Text(error.toString()),
              trailing: IconButton(
                onPressed: () => ref.invalidate(vendorOfflineMutationsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (items) => items.isEmpty
                ? const ListTile(title: Text('No pending offline mutations.'))
                : Column(
                    children: items
                        .map(
                          (item) => ListTile(
                            title: Text(item.type),
                            subtitle: Text(item.lastError ?? item.status),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  tooltip: 'Retry',
                                  onPressed: () async {
                                    await ref
                                        .read(appControllerProvider)
                                        .api
                                        .retryVendorMutation(item.id);
                                    ref.invalidate(
                                        vendorOfflineMutationsProvider);
                                  },
                                  icon: const Icon(Icons.refresh),
                                ),
                                IconButton(
                                  tooltip: 'Discard',
                                  onPressed: () async {
                                    await ref
                                        .read(appControllerProvider)
                                        .api
                                        .discardVendorMutation(item.id);
                                    ref.invalidate(
                                        vendorOfflineMutationsProvider);
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});
  final VendorOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        onTap: () => _showOrder(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.reference,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(label: Text(order.status.replaceAll('_', ' '))),
                ],
              ),
              Text(order.address),
              const SizedBox(height: 8),
              Text(
                '₹${order.amountRupees.toStringAsFixed(2)} • '
                '${_formatDate(order.scheduledFor)}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOrder(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OrderActions(order: order),
    );
  }
}

class _OrderActions extends ConsumerStatefulWidget {
  const _OrderActions({required this.order});
  final VendorOrder order;

  @override
  ConsumerState<_OrderActions> createState() => _OrderActionsState();
}

class _OrderActionsState extends ConsumerState<_OrderActions> {
  String? selectedVehicle;
  String? selectedDriver;

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vendorVehiclesProvider).valueOrNull ?? const [];
    final drivers = ref.watch(vendorDriversProvider).valueOrNull ?? const [];
    final assignableVehicles =
        vehicles.where((item) => item.assignable).toList();
    final assignableDrivers = drivers.where((item) => item.assignable).toList();
    selectedVehicle ??=
        assignableVehicles.isEmpty ? null : assignableVehicles.first.id;
    selectedDriver ??=
        assignableDrivers.isEmpty ? null : assignableDrivers.first.id;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.order.reference,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.order.address),
            const SizedBox(height: 16),
            if (widget.order.status == 'pending_vendor') ...[
              if (assignableVehicles.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedVehicle,
                  decoration:
                      const InputDecoration(labelText: 'Approved vehicle'),
                  items: assignableVehicles
                      .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.registrationNumber),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedVehicle = value),
                ),
              if (assignableDrivers.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedDriver,
                  decoration:
                      const InputDecoration(labelText: 'Approved driver'),
                  items: assignableDrivers
                      .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedDriver = value),
                ),
              OutlinedButton(
                onPressed: selectedVehicle == null || selectedDriver == null
                    ? () => _showAssignmentRequired(context)
                    : () => _transition(
                          context,
                          ref,
                          action: 'accept',
                          vehicleId: selectedVehicle,
                          driverId: selectedDriver,
                        ),
                child: const Text('Accept with first approved assignment'),
              ),
            ],
            if (!['delivered', 'cancelled'].contains(widget.order.status)) ...[
              _statusButton(context, ref, 'en_route', 'Mark en route'),
              _statusButton(context, ref, 'arrived', 'Mark arrived'),
              _statusButton(context, ref, 'delivered', 'Mark delivered'),
              OutlinedButton(
                onPressed: () => _reject(context, ref),
                child: const Text('Reject order'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusButton(
    BuildContext context,
    WidgetRef ref,
    String status,
    String label,
  ) {
    return FilledButton.tonal(
      onPressed: () =>
          _transition(context, ref, action: 'status', status: status),
      child: Text(label),
    );
  }

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref, {
    required String action,
    String? status,
    String? vehicleId,
    String? driverId,
    String? reason,
  }) async {
    try {
      await ref.read(appControllerProvider).api.transitionVendorOrder(
            widget.order.id,
            action: action,
            status: status,
            vehicleId: vehicleId,
            driverId: driverId,
            reason: reason,
          );
      ref.invalidate(vendorOrdersProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order updated successfully.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        try {
          await ref.read(appControllerProvider).api.queueVendorMutation(
            mutationType: action,
            entityType: 'booking',
            entityId: widget.order.id,
            payload: {
              'status': status,
              'reason': reason,
              'vehicleId': vehicleId,
              'driverId': driverId,
            },
          );
          ref.invalidate(vendorOfflineMutationsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Update failed and was queued for retry.'),
              ),
            );
          }
        } catch (queueError) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$error\nQueue failed: $queueError')),
            );
          }
        }
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject order'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason'),
          minLines: 2,
          maxLines: 4,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reject')),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed == true && reason.length >= 2 && context.mounted) {
      await _transition(context, ref, action: 'reject', reason: reason);
    }
  }

  void _showAssignmentRequired(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Assignment required'),
        content: Text(
            'An active, approved vehicle and driver are required before accepting this order.'),
      ),
    );
  }
}

class VendorFleetScreen extends ConsumerWidget {
  const VendorFleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(vendorDashboardProvider);
    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _VendorError(
        message: error.toString(),
        retry: () => ref.invalidate(vendorDashboardProvider),
      ),
      data: (value) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(vendorDashboardProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Vehicles'),
            ...value.vehicles.map(
              (vehicle) => ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(vehicle.registrationNumber),
                subtitle: Text(
                    '${vehicle.capacityLitres} litres • ${vehicle.verification}'),
                trailing: Text(vehicle.active ? 'Active' : 'Inactive'),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Drivers'),
            ...value.drivers.map(
              (driver) => ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(driver.name),
                subtitle: Text('${driver.mobile} • ${driver.verification}'),
                trailing: Text(driver.active ? 'Active' : 'Inactive'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VendorEarningsScreen extends ConsumerWidget {
  const VendorEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(vendorPayoutsProvider);
    return payouts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _VendorError(
        message: error.toString(),
        retry: () => ref.invalidate(vendorPayoutsProvider),
      ),
      data: (items) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(vendorPayoutsProvider),
        child: items.isEmpty
            ? ListView(
                children: const [_VendorEmpty(message: 'No payouts yet.')])
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final payout = items[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: Text('₹${payout.amountRupees.toStringAsFixed(2)}'),
                      subtitle: Text(
                          '${payout.reference}\n${_formatDate(payout.createdAt)}'),
                      trailing: Text(payout.status),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _VendorEmpty extends StatelessWidget {
  const _VendorEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text(message)),
      );
}

class _VendorError extends StatelessWidget {
  const _VendorError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: retry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

String _formatDate(DateTime? value) => value == null
    ? 'Date not set'
    : value.toLocal().toString().split(' ').first;
