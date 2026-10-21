import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../models/account.dart';

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
                ),
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
        ),
        _AdminRecordsSection(
          title: 'Customers',
          icon: Icons.people_outline,
          loader: (api) => api.adminCustomers(),
        ),
        _AdminRecordsSection(
          title: 'Coupons',
          icon: Icons.local_offer_outlined,
          loader: (api) => api.adminCoupons(),
        ),
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
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Detailed report exports'),
              subtitle: Text(
                  'Use the admin web workspace for date-filtered exports until the mobile report endpoint is added.'),
            ),
          ],
        );
      },
    );
  }
}

class _AdminRecordsSection extends ConsumerWidget {
  const _AdminRecordsSection({
    required this.title,
    required this.icon,
    required this.loader,
    this.onVendorStatus,
  });

  final String title;
  final IconData icon;
  final Future<List<AccountRecord>> Function(dynamic api) loader;
  final Future<void> Function(AccountRecord record, String status)?
      onVendorStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: title == 'Vendors',
        leading: Icon(icon),
        title: Text(title),
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
