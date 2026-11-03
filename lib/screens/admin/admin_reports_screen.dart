import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../models/account.dart';
import '../../services/friendly_error.dart';

/// Ranges the revenue report can cover, ending today.
const _ranges = <(String, int)>[
  ('Today', 0),
  ('Last 7 days', 6),
  ('Last 30 days', 29),
];

String _isoDate(DateTime date) => date.toIso8601String().split('T').first;

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(dispatcherVendorsProvider);
    return vendors.when(
      loading: () => const LoadingState(message: 'Loading reports...'),
      error: (error, _) => ErrorState(
        error: error,
        message: friendlyError(error),
        onRetry: () => ref.invalidate(dispatcherVendorsProvider),
      ),
      data: (items) {
        return ListView(
          padding: const EdgeInsets.all(AppSpace.gutter),
          children: [
            Text(
              'Reports',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpace.lg),
            const _RevenueReport(),
            const SizedBox(height: AppSpace.xl),
            _VendorDirectory(vendors: items),
          ],
        );
      },
    );
  }
}

/// Revenue for a chosen range: totals, a bar per day, and a share action.
class _RevenueReport extends ConsumerStatefulWidget {
  const _RevenueReport();

  @override
  ConsumerState<_RevenueReport> createState() => _RevenueReportState();
}

class _RevenueReportState extends ConsumerState<_RevenueReport> {
  int _range = 0;
  bool _running = false;
  Map<String, dynamic>? _report;

  Future<void> _run() async {
    final now = DateTime.now();
    final days = _ranges[_range].$2;
    setState(() => _running = true);
    try {
      final value = await ref.read(appControllerProvider).api.adminReport({
        'type': 'revenue',
        'from': _isoDate(now.subtract(Duration(days: days))),
        'to': _isoDate(now),
      });
      if (mounted) setState(() => _report = value);
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          friendlyError(error),
          variant: AppSnackVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = _report;
    final rows =
        (report?['rows'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
    final values = [
      for (final row in rows)
        ((row['amount'] ?? row['total'] ?? row['revenue']) as num?)
                ?.toDouble() ??
            0,
    ];
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Revenue', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (var i = 0; i < _ranges.length; i++)
                ChoiceChip(
                  label: Text(_ranges[i].$1),
                  selected: _range == i,
                  onSelected: (_) => setState(() => _range = i),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          PrimaryButton(
            label: _running ? 'Running...' : 'Run report',
            icon: Icons.insights_outlined,
            loading: _running,
            onPressed: _running ? null : _run,
          ),
          if (report != null) ...[
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total',
                    value: '₹${report['total'] ?? 0}',
                    icon: Icons.currency_rupee,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: StatCard(
                    label: 'Rows',
                    value: '${rows.length}',
                    icon: Icons.table_rows_outlined,
                  ),
                ),
                IconButton(
                  tooltip: 'Share report',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: 'Urban Tanker report\n'
                          'Range: ${_ranges[_range].$1}\n'
                          'Total: ₹${report['total'] ?? 0}\n'
                          'Rows: ${rows.length}',
                    ),
                  ),
                ),
              ],
            ),
            if (values.length > 1) ...[
              const SizedBox(height: AppSpace.lg),
              SizedBox(
                height: 120,
                width: double.infinity,
                child: CustomPaint(
                  painter: BarPainter(
                    values: values,
                    color: context.colors.primary,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// One bar per value, scaled to the largest. Drawn without a chart package.
class BarPainter extends CustomPainter {
  const BarPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final max = values.fold<double>(0, (a, b) => b > a ? b : a);
    if (max <= 0) return;
    final slot = size.width / values.length;
    final barWidth = slot * 0.6;
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final height = size.height * (values[i] / max);
      final left = i * slot + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(BarPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

/// Registered vendor accounts, collapsed by default.
class _VendorDirectory extends StatelessWidget {
  const _VendorDirectory({required this.vendors});

  final List<AccountRecord> vendors;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: AppRadius.cardBorder,
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            leading: const Icon(Icons.storefront_outlined),
            title: Text('Registered vendors (${vendors.length})'),
            subtitle: const Text('Tap to view registered vendor accounts'),
            children: vendors.isEmpty
                ? const [AppListRow(title: 'No registered vendors yet.')]
                : [
                    for (final vendor in vendors)
                      AppListRow(
                        leading: const CircleAvatar(
                          child: Icon(Icons.storefront_outlined),
                        ),
                        title: _registeredVendorName(vendor),
                        subtitle: _registeredVendorDetails(vendor),
                      ),
                  ],
          ),
        ),
      );
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
