import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../app/providers.dart';
import '../models/account.dart';
import '../models/notification.dart';

class AdminPulseScreen extends ConsumerWidget {
  const AdminPulseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(adminHealthProvider);
    return healthState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _AdminError(error: error.toString()),
      data: (health) {
        final migrations = health['migrations'] is List
            ? (health['migrations'] as List).whereType<Map>().toList()
            : const [];
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminHealthProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Platform pulse',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _MetricTile(
                label: 'System status',
                value: health['ok'] == true ? 'Healthy' : 'Attention required',
                icon: health['ok'] == true
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
              ),
              _MetricTile(
                label: 'Realtime',
                value: (health['realtime'] as Map?)?['connected'] == true
                    ? 'Connected'
                    : 'Unavailable',
                icon: Icons.radar_outlined,
              ),
              _MetricTile(
                label: 'Storage',
                value: (health['storage'] as Map?)?['configured'] == true
                    ? 'Configured'
                    : 'Not configured',
                icon: Icons.storage_outlined,
              ),
              const SizedBox(height: 12),
              const Text('Migration checks'),
              ...migrations.map(
                (item) => ListTile(
                  dense: true,
                  leading: Icon(
                    item['applied'] == true ? Icons.check : Icons.error_outline,
                  ),
                  title: Text((item['table'] ?? 'Table').toString()),
                  subtitle: Text(item['applied'] == true
                      ? 'Available'
                      : (item['error'] ?? 'Unavailable').toString()),
                  trailing: item['applied'] == true
                      ? null
                      : TextButton(
                          onPressed: () => ref.invalidate(adminHealthProvider),
                          child: const Text('Retry'),
                        ),
                ),
              ),
              if ((health['configuration'] as Map?)
                      ?.values
                      .any((value) => value != true) ==
                  true)
                const ListTile(
                  leading: Icon(Icons.warning_amber_outlined),
                  title: Text('Configuration warnings'),
                  subtitle:
                      Text('One or more integrations are not configured.'),
                ),
              FilledButton.tonal(
                onPressed: () async {
                  try {
                    await ref
                        .read(appControllerProvider)
                        .api
                        .adminStorageCleanup();
                    ref.invalidate(adminHealthProvider);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Cleanup failed: $error')),
                      );
                    }
                  }
                },
                child: const Text('Run storage cleanup'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminOperationsScreen extends ConsumerWidget {
  const AdminOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _AdminOrdersSection(),
        _AdminRecordsSection(
          title: 'Vendors',
          icon: Icons.storefront_outlined,
          loader: (api) => api.adminVendors(),
          onVendorStatus: (record, status) async {
            await ref.read(appControllerProvider).api.updateVendorVerification(
                  record.id,
                  status,
                );
          },
          onAdd: () => _createVendor(context, ref),
        ),
        _AdminRecordsSection(
          title: 'Customers',
          icon: Icons.people_outline,
          loader: (api) => api.adminCustomers(),
          onAdd: () => _createCustomer(context, ref),
        ),
        _AdminRecordsSection(
          title: 'Coupons',
          icon: Icons.local_offer_outlined,
          loader: (api) => api.adminCoupons(),
          onAdd: () => _createCoupon(context, ref),
        ),
        const _AdminServicesSection(),
        const _AdminPayoutsSection(),
        const _AdminPartnerSection(),
        const _AdminNotificationSection(),
        const _AdminAuditSection(),
      ],
    );
  }
}

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<AccountRecord>>(
      future: ref.read(appControllerProvider).api.adminVendors(),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Reports', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _MetricTile(
              label: 'Registered vendors',
              value: '$count',
              icon: Icons.storefront_outlined,
            ),
            _AdminReportForm(),
          ],
        );
      },
    );
  }
}

class _AdminOrdersSection extends ConsumerStatefulWidget {
  const _AdminOrdersSection();

  @override
  ConsumerState<_AdminOrdersSection> createState() =>
      _AdminOrdersSectionState();
}

class _AdminOrdersSectionState extends ConsumerState<_AdminOrdersSection> {
  String? status;
  int page = 1;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: const Text('Orders'),
        children: [
          DropdownButton<String?>(
            value: status,
            hint: const Text('All statuses'),
            items: const [
              DropdownMenuItem(value: null, child: Text('All statuses')),
              DropdownMenuItem(value: 'pending_vendor', child: Text('Pending')),
              DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
              DropdownMenuItem(value: 'en_route', child: Text('En route')),
              DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
            onChanged: (value) => setState(() {
              status = value;
              page = 1;
            }),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: ref.read(appControllerProvider).api.adminOrders(
                  page: page,
                  status: status,
                ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              final rows = (snapshot.data?['rows'] as List?)
                      ?.whereType<Map>()
                      .toList() ??
                  const [];
              if (rows.isEmpty) {
                return const ListTile(title: Text('No orders found.'));
              }
              return Column(
                children: [
                  ...rows.map(
                    (row) => ListTile(
                      title: Text((row['reference'] ?? row['id']).toString()),
                      subtitle: Text(
                        '${row['status'] ?? ''}\n${row['address_text'] ?? ''}',
                      ),
                      isThreeLine: true,
                      onTap: () => _showOrder(context, row),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed:
                            page > 1 ? () => setState(() => page--) : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('Page $page'),
                      IconButton(
                        onPressed: rows.length >= 25
                            ? () => setState(() => page++)
                            : null,
                        icon: const Icon(Icons.chevron_right),
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

  void _showOrder(BuildContext context, Map row) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text((row['reference'] ?? 'Order').toString()),
        content: Text(row.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }
}

class _AdminServicesSection extends ConsumerWidget {
  const _AdminServicesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AdminSimpleRecords(
      title: 'Services',
      icon: Icons.water_drop_outlined,
      loader: (api) => api.adminServices(),
      action: () async {
        final code = TextEditingController();
        final name = TextEditingController();
        final price = TextEditingController();
        await _adminForm(
          context,
          title: 'Create service',
          fields: [
            ('Code', code),
            ('Name', name),
            ('Base price (paise)', price)
          ],
          submit: () async {
            final value = int.tryParse(price.text.trim());
            if (value == null || value < 0) {
              throw const FormatException('Enter a valid price.');
            }
            await ref.read(appControllerProvider).api.createAdminService({
              'code': code.text.trim(),
              'name': name.text.trim(),
              'basePricePaise': value,
              'isActive': true,
            });
          },
        );
        code.dispose();
        name.dispose();
        price.dispose();
      },
    );
  }
}

class _AdminPayoutsSection extends ConsumerWidget {
  const _AdminPayoutsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _AdminSimpleRecords(
        title: 'Payouts',
        icon: Icons.payments_outlined,
        loader: (api) => api.adminPayouts(),
      );
}

class _AdminPartnerSection extends ConsumerWidget {
  const _AdminPartnerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _AdminSimpleRecords(
        title: 'Partner applications',
        icon: Icons.handshake_outlined,
        loader: (api) => api.adminPartnerApplications(),
      );
}

class _AdminNotificationSection extends ConsumerStatefulWidget {
  const _AdminNotificationSection();

  @override
  ConsumerState<_AdminNotificationSection> createState() =>
      _AdminNotificationSectionState();
}

class _AdminNotificationSectionState
    extends ConsumerState<_AdminNotificationSection> {
  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Send customer notification'),
              onTap: () async {
                final customer = TextEditingController();
                final title = TextEditingController();
                final detail = TextEditingController();
                await _adminForm(
                  context,
                  title: 'Send notification',
                  fields: [
                    ('Customer ID', customer),
                    ('Title', title),
                    ('Message', detail)
                  ],
                  submit: () => ref
                      .read(appControllerProvider)
                      .api
                      .sendAdminNotification({
                    'customerId': customer.text.trim(),
                    'title': title.text.trim(),
                    'detail': detail.text.trim(),
                  }),
                );
                customer.dispose();
                title.dispose();
                detail.dispose();
              },
            ),
            FutureBuilder<List<NotificationItem>>(
              future: ref.read(appControllerProvider).api.adminNotifications(),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const [];
                return ExpansionTile(
                  title: const Text('Admin inbox'),
                  children: items.isEmpty
                      ? [const ListTile(title: Text('No admin notifications.'))]
                      : items
                          .map(
                            (item) => ListTile(
                              title: Text(item.title),
                              subtitle: Text(item.message),
                              onTap: () async {
                                if (!item.read) {
                                  await ref
                                      .read(appControllerProvider)
                                      .api
                                      .markAdminNotificationRead(item.id);
                                  if (context.mounted) setState(() {});
                                }
                              },
                            ),
                          )
                          .toList(),
                );
              },
            ),
          ],
        ),
      );
}

class _AdminAuditSection extends ConsumerStatefulWidget {
  const _AdminAuditSection();

  @override
  ConsumerState<_AdminAuditSection> createState() => _AdminAuditSectionState();
}

class _AdminAuditSectionState extends ConsumerState<_AdminAuditSection> {
  int page = 1;
  String action = '';
  String entityType = '';

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.history_outlined),
          title: const Text('Audit logs'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Action'),
                      onChanged: (value) => setState(() => action = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Entity'),
                      onChanged: (value) => setState(() => entityType = value),
                    ),
                  ),
                ],
              ),
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: ref.read(appControllerProvider).api.adminAuditLogs(
                    page: page,
                    action: action,
                    entityType: entityType,
                  ),
              builder: (context, snapshot) {
                final rows = (snapshot.data?['rows'] as List?)
                        ?.whereType<Map>()
                        .toList() ??
                    const [];
                return Column(
                  children: [
                    ...rows.map(
                      (row) => ListTile(
                        title: Text(
                            '${row['action'] ?? ''} • ${row['entity_type'] ?? ''}'),
                        subtitle: Text((row['metadata'] ?? '').toString()),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed:
                              page > 1 ? () => setState(() => page--) : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Page $page'),
                        IconButton(
                          onPressed: rows.length >= 50
                              ? () => setState(() => page++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
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

class _AdminSimpleRecords extends ConsumerWidget {
  const _AdminSimpleRecords({
    required this.title,
    required this.icon,
    required this.loader,
    this.action,
  });

  final String title;
  final IconData icon;
  final Future<List<AccountRecord>> Function(dynamic api) loader;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: ExpansionTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: action == null
              ? null
              : IconButton(onPressed: action, icon: const Icon(Icons.add)),
          children: [
            FutureBuilder<List<AccountRecord>>(
              future: loader(ref.read(appControllerProvider).api),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  );
                }
                final records = snapshot.data ?? const [];
                if (records.isEmpty) {
                  return const ListTile(title: Text('No records found.'));
                }
                return Column(
                  children: records
                      .map((record) => ListTile(
                            title: Text(record.title),
                            subtitle: Text(record.detail),
                            trailing: Text(record.status),
                            onTap: () => _showAdminRecord(context, record),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      );
}

void _showAdminRecord(BuildContext context, AccountRecord record) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(record.title),
      content: SingleChildScrollView(
        child: Text(record.data.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n')),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close'))
      ],
    ),
  );
}

Future<void> _adminForm(
  BuildContext context, {
  required String title,
  required List<(String, TextEditingController)> fields,
  required Future<void> Function() submit,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: fields
            .map((field) => TextField(
                  controller: field.$2,
                  decoration: InputDecoration(labelText: field.$1),
                ))
            .toList(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            try {
              await submit();
              if (context.mounted) Navigator.pop(context);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.toString())));
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _AdminReportForm extends ConsumerStatefulWidget {
  const _AdminReportForm();

  @override
  ConsumerState<_AdminReportForm> createState() => _AdminReportFormState();
}

class _AdminReportFormState extends ConsumerState<_AdminReportForm> {
  Map<String, dynamic>? report;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.filter_alt_outlined),
          title: const Text('Filtered report'),
          children: [
            FilledButton(
              onPressed: () async {
                final today = DateTime.now().toIso8601String().split('T').first;
                try {
                  final value =
                      await ref.read(appControllerProvider).api.adminReport({
                    'type': 'revenue',
                    'from': today,
                    'to': today,
                  });
                  if (mounted) setState(() => report = value);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())));
                  }
                }
              },
              child: const Text('Run today report'),
            ),
            if (report != null)
              ListTile(
                title: Text('Total: ₹${report!['total'] ?? 0}'),
                subtitle:
                    Text('Rows: ${(report!['rows'] as List?)?.length ?? 0}'),
                trailing: IconButton(
                  tooltip: 'Share report',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => Share.share(
                    'Urban Tanker report\n'
                    'Total: ₹${report!['total'] ?? 0}\n'
                    'Rows: ${(report!['rows'] as List?)?.length ?? 0}',
                  ),
                ),
              ),
          ],
        ),
      );
}

class _AdminRecordsSection extends ConsumerWidget {
  const _AdminRecordsSection({
    required this.title,
    required this.icon,
    required this.loader,
    this.onVendorStatus,
    this.onAdd,
  });

  final String title;
  final IconData icon;
  final Future<List<AccountRecord>> Function(dynamic api) loader;
  final Future<void> Function(AccountRecord record, String status)?
      onVendorStatus;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: title == 'Vendors',
        leading: Icon(icon),
        title: Text(title),
        trailing: onAdd == null
            ? null
            : IconButton(onPressed: onAdd, icon: const Icon(Icons.add)),
        children: [
          FutureBuilder<List<AccountRecord>>(
            future: loader(ref.read(appControllerProvider).api),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return ListTile(
                  title: Text('Could not load $title'),
                  subtitle: Text(snapshot.error.toString()),
                );
              }
              final records = snapshot.data ?? const [];
              if (records.isEmpty) {
                return const ListTile(title: Text('No records found.'));
              }
              return Column(
                children: records
                    .map(
                      (record) => ListTile(
                        title: Text(record.title),
                        subtitle: Text(record.detail),
                        onTap: () => _showAdminRecord(context, record),
                        trailing: onVendorStatus == null
                            ? Text(record.status)
                            : PopupMenuButton<String>(
                                onSelected: (status) async {
                                  await onVendorStatus!(record, status);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'approved',
                                      child: Text('Approve')),
                                  PopupMenuItem(
                                      value: 'suspended',
                                      child: Text('Suspend')),
                                  PopupMenuItem(
                                      value: 'rejected', child: Text('Reject')),
                                ],
                              ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _createVendor(BuildContext context, WidgetRef ref) async {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final business = TextEditingController();
  final zone = TextEditingController();
  await _adminForm(
    context,
    title: 'Create vendor',
    fields: [
      ('Email', email),
      ('Password', password),
      ('Contact name', name),
      ('10-digit phone', phone),
      ('Business name', business),
      ('Service zone', zone),
    ],
    submit: () => ref.read(appControllerProvider).api.createAdminVendor({
      'email': email.text.trim(),
      'password': password.text,
      'name': name.text.trim(),
      'phone': phone.text.trim(),
      'businessName': business.text.trim(),
      'serviceZone': zone.text.trim(),
    }),
  );
  for (final controller in [email, password, name, phone, business, zone]) {
    controller.dispose();
  }
}

Future<void> _createCustomer(BuildContext context, WidgetRef ref) async {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  await _adminForm(
    context,
    title: 'Create customer',
    fields: [
      ('Email', email),
      ('Password', password),
      ('Name', name),
      ('10-digit phone', phone),
    ],
    submit: () => ref.read(appControllerProvider).api.createAdminCustomer({
      'email': email.text.trim(),
      'password': password.text,
      'name': name.text.trim(),
      'phone': phone.text.trim(),
    }),
  );
  for (final controller in [email, password, name, phone]) {
    controller.dispose();
  }
}

Future<void> _createCoupon(BuildContext context, WidgetRef ref) async {
  final code = TextEditingController();
  final label = TextEditingController();
  final discount = TextEditingController();
  final expires = TextEditingController();
  await _adminForm(
    context,
    title: 'Create coupon',
    fields: [
      ('Code', code),
      ('Label', label),
      ('Discount (10% or 100)', discount),
      ('Expiry (YYYY-MM-DD)', expires),
    ],
    submit: () {
      final expiry = DateTime.tryParse(expires.text.trim());
      if (expiry == null || expiry.isBefore(DateTime.now())) {
        throw const FormatException('Enter a valid future expiry date.');
      }
      return ref.read(appControllerProvider).api.createAdminCoupon({
        'code': code.text.trim(),
        'label': label.text.trim(),
        'discount': discount.text.trim(),
        'expires': expires.text.trim(),
        'active': true,
      });
    },
  );
  for (final controller in [code, label, discount, expires]) {
    controller.dispose();
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: Text(value),
        ),
      );
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
}
