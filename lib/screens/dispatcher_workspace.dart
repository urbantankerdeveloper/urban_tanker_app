import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../models/account.dart';

class DispatcherDispatchScreen extends ConsumerStatefulWidget {
  const DispatcherDispatchScreen({super.key});

  @override
  ConsumerState<DispatcherDispatchScreen> createState() =>
      _DispatcherDispatchScreenState();
}

class _DispatcherDispatchScreenState
    extends ConsumerState<DispatcherDispatchScreen> {
  String? status;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(dispatcherOrdersProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dispatcherOrdersProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String?>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Filter status'),
            items: const [
              DropdownMenuItem(value: null, child: Text('All statuses')),
              DropdownMenuItem(
                value: 'pending_vendor',
                child: Text('Pending assignment'),
              ),
              DropdownMenuItem(value: 'vendor_assigned', child: Text('Assigned')),
              DropdownMenuItem(value: 'en_route', child: Text('En route')),
              DropdownMenuItem(value: 'arrived', child: Text('Arrived')),
              DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
            ],
            onChanged: (value) => setState(() => status = value),
          ),
          const SizedBox(height: 12),
          orders.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _DispatcherError(
              message: error.toString(),
              retry: () => ref.invalidate(dispatcherOrdersProvider),
            ),
            data: (page) {
              final rows = (page['rows'] as List?)
                      ?.whereType<Map<String, dynamic>>()
                      .where(
                        (row) => status == null || row['status'] == status,
                      )
                      .toList() ??
                  const [];
              if (rows.isEmpty) {
                return const _DispatcherEmpty(message: 'No dispatch orders.');
              }
              return Column(
                children: rows
                    .map((row) => _DispatchOrderCard(order: row))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DispatchOrderCard extends ConsumerWidget {
  const _DispatchOrderCard({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = order['vendor_id'] != null;
    return Card(
      child: ListTile(
        leading: Icon(
          assigned ? Icons.local_shipping_outlined : Icons.warning_amber_outlined,
        ),
        title: Text((order['reference'] ?? order['id']).toString()),
        subtitle: Text(
          '${order['status'] ?? ''}\n'
          '${order['address_text'] ?? 'Address unavailable'}\n'
          'Schedule: ${order['scheduled_for'] ?? 'Not scheduled'}',
        ),
        isThreeLine: true,
        onTap: () => _showActions(context, ref),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.assignment_ind_outlined),
              title: const Text('Assign vendor / fleet'),
              onTap: () => Navigator.pop(context, 'assign'),
            ),
            ListTile(
              leading: const Icon(Icons.sync_alt_outlined),
              title: const Text('Update status'),
              onTap: () => Navigator.pop(context, 'status'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('Cancel order'),
              onTap: () => Navigator.pop(context, 'cancel'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'assign') {
      await _assign(context, ref);
    } else if (action == 'status') {
      await _status(context, ref);
    } else if (action == 'cancel') {
      await _cancel(context, ref);
    }
  }

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final vendors = await ref.read(dispatcherVendorsProvider.future);
    final eligible = vendors
        .where((vendor) =>
            vendor.status == 'approved' || vendor.data['verification'] == 'approved')
        .toList();
    if (!context.mounted) return;
    if (eligible.isEmpty) {
      _message(context, 'No approved vendors are available.');
      return;
    }
    String vendorId = eligible.first.id;
    final selected = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Assign vendor'),
          content: DropdownButtonFormField<String>(
            initialValue: vendorId,
            items: eligible
                .map(
                  (vendor) => DropdownMenuItem(
                    value: vendor.id,
                    child: Text(vendor.title),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => vendorId = value ?? vendorId),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (selected != true || !context.mounted) return;
    try {
      await ref.read(appControllerProvider).api.dispatcherAssignOrder(
            order['id'].toString(),
            vendorId: vendorId,
          );
      ref.invalidate(dispatcherOrdersProvider);
      if (!context.mounted) return;
      _message(context, 'Order assigned.');
    } catch (error) {
      if (!context.mounted) return;
      _message(context, 'Assignment failed: $error');
    }
  }

  Future<void> _status(BuildContext context, WidgetRef ref) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['pending_vendor', 'vendor_assigned', 'accepted', 'en_route', 'arrived', 'delivered']
              .map(
                (value) => ListTile(
                  title: Text(value.replaceAll('_', ' ')),
                  onTap: () => Navigator.pop(context, value),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (value == null || !context.mounted) return;
    try {
      await ref.read(appControllerProvider).api.dispatcherUpdateStatus(
            order['id'].toString(),
            value,
          );
      ref.invalidate(dispatcherOrdersProvider);
      if (!context.mounted) return;
      _message(context, 'Order status updated.');
    } catch (error) {
      if (!context.mounted) return;
      _message(context, 'Status update failed: $error');
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel order'),
        content: TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Cancellation reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reason.text.trim().isNotEmpty),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    final value = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(appControllerProvider).api.dispatcherCancelOrder(
            order['id'].toString(),
            value,
          );
      ref.invalidate(dispatcherOrdersProvider);
      if (!context.mounted) return;
      _message(context, 'Order cancelled.');
    } catch (error) {
      if (!context.mounted) return;
      _message(context, 'Cancellation failed: $error');
    }
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class DispatcherLiveScreen extends ConsumerWidget {
  const DispatcherLiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(dispatcherOrdersProvider);
    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _DispatcherError(
        message: error.toString(),
        retry: () => ref.invalidate(dispatcherOrdersProvider),
      ),
      data: (page) {
        final rows = (page['rows'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .where((row) => !['delivered', 'cancelled'].contains(row['status']))
                .toList() ??
            const [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Live operations', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const _DispatcherEmpty(message: 'No active live operations.')
            else
              ...rows.map(
                (row) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.radar_outlined),
                    title: Text((row['reference'] ?? row['id']).toString()),
                    subtitle: Text(
                      '${row['status'] ?? ''}\n'
                      'Location: ${row['latitude'] ?? '—'}, ${row['longitude'] ?? '—'}',
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class DispatcherAlertsScreen extends ConsumerWidget {
  const DispatcherAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(dispatcherAlertsProvider);
    return alerts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _DispatcherError(
        message: error.toString(),
        retry: () => ref.invalidate(dispatcherAlertsProvider),
      ),
      data: (items) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(dispatcherAlertsProvider),
        child: items.isEmpty
            ? const _DispatcherEmpty(message: 'No dispatch alerts.')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: items
                    .map(
                      (item) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber_outlined),
                          title: Text(item.title),
                          subtitle: Text(item.detail),
                          onTap: () => _showAlert(context, item),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  void _showAlert(BuildContext context, AccountRecord item) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item.title),
        content: Text(item.data.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Dismiss')),
        ],
      ),
    );
  }
}

class _DispatcherEmpty extends StatelessWidget {
  const _DispatcherEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}

class _DispatcherError extends StatelessWidget {
  const _DispatcherError({required this.message, required this.retry});
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
