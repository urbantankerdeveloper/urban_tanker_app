import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/page_components.dart';
import '../models/account.dart';
import '../models/dispatcher.dart';

class DispatcherDispatchScreen extends ConsumerStatefulWidget {
  const DispatcherDispatchScreen({super.key});

  @override
  ConsumerState<DispatcherDispatchScreen> createState() =>
      _DispatcherDispatchScreenState();
}

class _DispatcherDispatchScreenState
    extends ConsumerState<DispatcherDispatchScreen> {
  String? status;
  String? service;
  String? vendorId;
  String? from;
  String? to;
  bool? assigned;
  int page = 1;

  @override
  Widget build(BuildContext context) {
    final filter = DispatcherOrderFilter(
      page: page,
      status: status,
      service: service,
      vendorId: vendorId,
      from: from,
      to: to,
      assigned: assigned,
    );
    final orders = ref.watch(dispatcherOrdersProvider(filter));
    final vendors = ref.watch(dispatcherVendorsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dispatcherOrdersProvider(filter)),
      child: ListView(
        padding: AppPageInsets.standard,
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
              DropdownMenuItem(
                  value: 'vendor_assigned', child: Text('Assigned')),
              DropdownMenuItem(value: 'en_route', child: Text('En route')),
              DropdownMenuItem(value: 'arrived', child: Text('Arrived')),
              DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
            ],
            onChanged: (value) => setState(() {
              status = value;
              page = 1;
            }),
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Service code',
              prefixIcon: Icon(Icons.water_drop_outlined),
            ),
            onChanged: (value) => setState(() {
              service = value.trim().isEmpty ? null : value.trim();
              page = 1;
            }),
          ),
          const SizedBox(height: 12),
          vendors.when(
            loading: () => const AppStateInline.loading(),
            error: (error, _) => AppStateInline.error(
              error: error,
              message: 'Vendor filter unavailable: $error',
              onRetry: () => ref.invalidate(dispatcherVendorsProvider),
            ),
            data: (items) => DropdownButtonFormField<String?>(
              initialValue: vendorId,
              decoration: const InputDecoration(labelText: 'Vendor'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All vendors'),
                ),
                ...items.map(
                  (vendor) => DropdownMenuItem<String?>(
                    value: vendor.id,
                    child: Text(vendor.title),
                  ),
                ),
              ],
              onChanged: (value) => setState(() {
                vendorId = value;
                page = 1;
              }),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<bool?>(
            initialValue: assigned,
            decoration: const InputDecoration(labelText: 'Assignment'),
            items: const [
              DropdownMenuItem<bool?>(
                value: null,
                child: Text('Assigned and unassigned'),
              ),
              DropdownMenuItem<bool?>(
                value: true,
                child: Text('Assigned only'),
              ),
              DropdownMenuItem<bool?>(
                value: false,
                child: Text('Unassigned only'),
              ),
            ],
            onChanged: (value) => setState(() {
              assigned = value;
              page = 1;
            }),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _chooseDate(
                  (value) => setState(() {
                    from = value;
                    page = 1;
                  }),
                ),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(from == null ? 'From date' : 'From $from'),
              ),
              OutlinedButton.icon(
                onPressed: () => _chooseDate(
                  (value) => setState(() {
                    to = value;
                    page = 1;
                  }),
                ),
                icon: const Icon(Icons.event_outlined),
                label: Text(to == null ? 'To date' : 'To $to'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          orders.when(
            loading: () => const AppStateInline.loading(),
            error: (error, _) => _DispatcherError(
              message: error.toString(),
              retry: () => ref.invalidate(dispatcherOrdersProvider(filter)),
            ),
            data: (pageData) {
              final rows = (pageData['rows'] as List?)
                      ?.whereType<Map<String, dynamic>>()
                      .toList() ??
                  const [];
              if (rows.isEmpty) {
                return const _DispatcherEmpty(message: 'No dispatch orders.');
              }
              final currentPage = (pageData['page'] as num?)?.toInt() ?? page;
              final total = (pageData['total'] as num?)?.toInt() ?? rows.length;
              final pageSize = (pageData['pageSize'] as num?)?.toInt() ?? 25;
              return Column(
                children: [
                  ...rows.map((row) => _DispatchOrderCard(order: row)),
                  if (total > pageSize)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            'Page $currentPage of ${(total / pageSize).ceil()}'),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Previous page',
                              onPressed: currentPage > 1
                                  ? () => setState(() => page = currentPage - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              tooltip: 'Next page',
                              onPressed: currentPage * pageSize < total
                                  ? () => setState(() => page = currentPage + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _chooseDate(ValueChanged<String> onSelected) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    onSelected(
      '${selected.year.toString().padLeft(4, '0')}-'
      '${selected.month.toString().padLeft(2, '0')}-'
      '${selected.day.toString().padLeft(2, '0')}',
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
          assigned
              ? Icons.local_shipping_outlined
              : Icons.warning_amber_outlined,
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
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('View order details'),
              onTap: () => Navigator.pop(context, 'details'),
            ),
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
    if (action == 'details') {
      _details(context);
    } else if (action == 'assign') {
      await _assign(context, ref);
    } else if (action == 'status') {
      await _status(context, ref);
    } else if (action == 'cancel') {
      await _cancel(context, ref);
    }
  }

  void _details(BuildContext context) {
    final details = <String, dynamic>{
      'Reference': order['reference'] ?? order['id'],
      'Status': order['status'] ?? '—',
      'Service': order['service_code'] ?? '—',
      'Address': order['address_text'] ?? '—',
      'Amount':
          '₹${((order['quoted_amount_paise'] as num?)?.toDouble() ?? 0) / 100}',
      'Schedule': order['scheduled_for'] ?? '—',
      'Vendor': order['vendor_id'] ?? 'Unassigned',
      'Vehicle': order['vehicle_id'] ?? 'Unassigned',
      'Driver': order['driver_id'] ?? 'Unassigned',
      'Cancellation reason':
          order['cancellation_reason'] ?? order['cancellationReason'] ?? '—',
    };
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dispatch order details'),
        content: SingleChildScrollView(
          child: Text(
            details.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final vendors = await ref.read(dispatcherVendorsProvider.future);
    final eligible = vendors
        .where((vendor) =>
            vendor.status == 'approved' ||
            vendor.data['verification'] == 'approved')
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
    final allowed = DispatcherOrder.fromJson(order).allowedNextStatuses;
    if (allowed.isEmpty) {
      _message(context, 'No status transitions are available for this order.');
      return;
    }
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: allowed
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
            onPressed: () =>
                Navigator.pop(context, reason.text.trim().isNotEmpty),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class DispatcherLiveScreen extends ConsumerWidget {
  const DispatcherLiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(
      dispatcherOrdersProvider(const DispatcherOrderFilter()),
    );
    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _DispatcherError(
        message: error.toString(),
        retry: () => ref.invalidate(dispatcherOrdersProvider),
      ),
      data: (page) {
        final rows = (page['rows'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .where((row) =>
                    !['delivered', 'cancelled'].contains(row['status']))
                .toList() ??
            const [];
        return ListView(
          padding: AppPageInsets.standard,
          children: [
            Text('Live operations',
                style: Theme.of(context).textTheme.headlineSmall),
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

class DispatcherAlertsScreen extends ConsumerStatefulWidget {
  const DispatcherAlertsScreen({super.key});

  @override
  ConsumerState<DispatcherAlertsScreen> createState() =>
      _DispatcherAlertsScreenState();
}

class _DispatcherAlertsScreenState
    extends ConsumerState<DispatcherAlertsScreen> {
  String? status;

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(dispatcherAlertsProvider(status));
    return alerts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _DispatcherError(
        message: error.toString(),
        retry: () => ref.invalidate(dispatcherAlertsProvider(status)),
      ),
      data: (items) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(dispatcherAlertsProvider(status)),
        child: ListView(
          padding: AppPageInsets.standard,
          children: [
            DropdownButtonFormField<String?>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Alert status'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Open alerts')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'dismissed', child: Text('Dismissed')),
              ],
              onChanged: (value) => setState(() => status = value),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const _DispatcherEmpty(message: 'No dispatch alerts.')
            else
              ...items.map(
                (item) => Card(
                  child: ListTile(
                    leading: Icon(
                      item.status == 'open'
                          ? Icons.warning_amber_outlined
                          : Icons.check_circle_outline,
                    ),
                    title: Text(item.title),
                    subtitle: Text('${item.detail}\nStatus: ${item.status}'),
                    isThreeLine: true,
                    onTap: () => _showAlert(context, item),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAlert(BuildContext context, AccountRecord item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('View alert details'),
              onTap: () => Navigator.pop(context, 'details'),
            ),
            if (item.status == 'open') ...[
              ListTile(
                leading: const Icon(Icons.check),
                title: const Text('Resolve alert'),
                onTap: () => Navigator.pop(context, 'resolved'),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Dismiss alert'),
                onTap: () => Navigator.pop(context, 'dismissed'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'details') {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(item.title),
          content: SingleChildScrollView(
            child: Text(item.data.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join('\n')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    if (action == null) return;
    try {
      await ref.read(appControllerProvider).api.updateDispatcherAlert(
            item.id,
            action,
          );
      ref.invalidate(dispatcherAlertsProvider(status));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Alert ${action == 'resolved' ? 'resolved' : 'dismissed'}.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alert update failed: $error')),
      );
    }
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
  Widget build(BuildContext context) => AppStateInline.error(
        error: message,
        onRetry: retry,
      );
}
