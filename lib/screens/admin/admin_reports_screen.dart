import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/page_components.dart';
import '../../models/account.dart';
import '../../services/friendly_error.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(dispatcherVendorsProvider);
    return vendors.when(
      loading: () => const AppStateView.loading(message: 'Loading reports...'),
      error: (error, _) => AppStateView.error(
        error: error,
        onRetry: () => ref.invalidate(dispatcherVendorsProvider),
      ),
      data: (items) {
        return ListView(
          padding: AppPageInsets.standard,
          children: [
            Text('Reports', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text('Registered vendors (${items.length})'),
                subtitle: const Text('Tap to view registered vendor accounts'),
                children: items.isEmpty
                    ? const [
                        ListTile(
                          title: Text('No registered vendors yet.'),
                        ),
                      ]
                    : items
                        .map(
                          (vendor) => ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.storefront_outlined),
                            ),
                            title: Text(_registeredVendorName(vendor)),
                            subtitle: Text(_registeredVendorDetails(vendor)),
                          ),
                        )
                        .toList(growable: false),
              ),
            ),
            _AdminReportForm(),
          ],
        );
      },
    );
  }
}

String _registeredVendorName(AccountRecord vendor) {
  for (final key in [
    'business_name',
    'businessName',
    'company_name',
    'companyName',
    'vendor_name',
    'vendorName',
    'display_name',
    'displayName',
    'name',
    'title',
  ]) {
    final value = vendor.data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return vendor.id.isEmpty ? 'Unnamed vendor' : 'Vendor ${vendor.id}';
}

String _registeredVendorDetails(AccountRecord vendor) {
  final details = <String>[
    for (final key in ['email', 'phone', 'phone_number', 'phoneNumber'])
      if (vendor.data[key]?.toString().trim().isNotEmpty == true)
        vendor.data[key].toString().trim(),
    for (final key in ['verification_status', 'verificationStatus', 'status'])
      if (vendor.data[key]?.toString().trim().isNotEmpty == true)
        vendor.data[key].toString().trim().replaceAll('_', ' '),
  ];
  return details.isEmpty
      ? 'No contact or status details available.'
      : details.join(' • ');
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
                        SnackBar(content: Text(friendlyError(error))));
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
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: 'Urban Tanker report\n'
                          'Total: ₹${report!['total'] ?? 0}\n'
                          'Rows: ${(report!['rows'] as List?)?.length ?? 0}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
