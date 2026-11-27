import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/auth_feature_flags.dart';
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
          padding: AppPageInsets.withSafeAreaBottom(
            context,
            AppPageInsets.standard,
          ),
          children: [
            Text('Reports', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpace.lg),
            AuthFeatureFlags.newUiEnabled
                ? AdminSalesReportPanel(vendors: items)
                : const _RevenueReport(),
            const SizedBox(height: AppSpace.xl),
            _VendorDirectory(vendors: items),
          ],
        );
      },
    );
  }
}

/// Sales report with date comparison and a server-side vendor filter.
class AdminSalesReportPanel extends ConsumerStatefulWidget {
  const AdminSalesReportPanel({
    required this.vendors,
    super.key,
    this.loadReport,
  });

  final List<AccountRecord> vendors;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? loadReport;

  @override
  ConsumerState<AdminSalesReportPanel> createState() =>
      _AdminSalesReportPanelState();
}

class _AdminSalesReportPanelState extends ConsumerState<AdminSalesReportPanel> {
  int _rangeIndex = 0;
  String? _vendorId;
  bool _running = false;
  String? _error;
  List<Map<String, dynamic>>? _rows;
  List<Map<String, dynamic>>? _previousRows;

  static const _rangeLabels = ['Day', 'Week', 'Month'];
  static const _periodLengths = [1, 7, 30];

  Future<void> _run() async {
    final length = _periodLengths[_rangeIndex];
    final today = DateTime.now();
    final currentEnd = DateTime(today.year, today.month, today.day);
    final currentStart = currentEnd.subtract(Duration(days: length - 1));
    final previousEnd = currentStart.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(Duration(days: length - 1));
    final runReport =
        widget.loadReport ??
        ((Map<String, dynamic> body) =>
            ref.read(appControllerProvider).api.adminReport(body));

    setState(() {
      _running = true;
      _error = null;
      _rows = null;
      _previousRows = null;
    });
    try {
      final reports = await Future.wait([
        runReport({
          'type': 'revenue',
          'from': _isoDate(currentStart),
          'to': _isoDate(currentEnd),
          if (_vendorId != null) 'vendorId': _vendorId,
        }),
        runReport({
          'type': 'revenue',
          'from': _isoDate(previousStart),
          'to': _isoDate(previousEnd),
          if (_vendorId != null) 'vendorId': _vendorId,
        }),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = _reportRows(reports.first);
        _previousRows = _reportRows(reports.last);
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _chooseVendor() async {
    final selection = await showAppBottomSheet<_VendorFilterSelection>(
      context,
      builder: (_) =>
          _VendorFilterSheet(vendors: widget.vendors, selectedId: _vendorId),
    );
    if (selection == null || !mounted) return;
    setState(() => _vendorId = selection.vendorId);
    await _run();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows == null
        ? const <Map<String, dynamic>>[]
        : AdminRevenueReport.filterRows(_rows!, vendorId: _vendorId);
    final total = AdminRevenueReport.total(rows);
    final previousRows = _previousRows == null
        ? const <Map<String, dynamic>>[]
        : AdminRevenueReport.filterRows(_previousRows!, vendorId: _vendorId);
    final previousTotal = AdminRevenueReport.total(previousRows);
    final breakdown = AdminRevenueReport._byService(rows);
    final length = _periodLengths[_rangeIndex];
    final values = _dailyValues(rows, length);
    final selectedVendor = widget.vendors
        .where((vendor) => vendor.id == _vendorId)
        .firstOrNull;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sales report', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpace.md),
          SegmentedTabs(
            labels: _rangeLabels,
            selectedIndex: _rangeIndex,
            onChanged: (index) => setState(() => _rangeIndex = index),
          ),
          const SizedBox(height: AppSpace.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ChoiceChip(
              label: Text(
                selectedVendor == null ? 'All vendors' : selectedVendor.title,
              ),
              avatar: const Icon(Icons.filter_list),
              selected: _vendorId != null,
              onSelected: (_) => _chooseVendor(),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          PrimaryButton(
            label: _running ? 'Running...' : 'Run report',
            icon: Icons.insights_outlined,
            loading: _running,
            onPressed: _running ? null : _run,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            AppStateInline.error(
              error: _error!,
              message: 'Sales report could not be loaded: $_error',
              onRetry: _run,
            ),
          ],
          if (_rows != null) ...[
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Revenue',
                    value: '₹${total.toStringAsFixed(2)}',
                    icon: Icons.currency_rupee,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: StatCard(
                    label: 'Orders',
                    value: '${AdminRevenueReport.orderCount(rows)}',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              _comparisonText(total, previousTotal),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              height: AppSize.reportChartHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: BarPainter(
                  values: values,
                  color: context.colors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text('BREAKDOWN', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: AppSpace.sm),
            if (breakdown.isEmpty)
              const EmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'No sales in this period.',
              )
            else
              for (final item in breakdown)
                AppListRow(
                  leading: const Icon(Icons.water_drop_outlined),
                  title: item.service,
                  subtitle: '${item.count} orders',
                  trailing: Text('₹${item.amount.toStringAsFixed(2)}'),
                ),
          ],
        ],
      ),
    );
  }

  List<double> _dailyValues(List<Map<String, dynamic>> rows, int days) {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(Duration(days: days - 1));
    final totals = List<double>.filled(days, 0);
    for (final row in rows) {
      final createdAt = DateTime.tryParse((row['created_at'] ?? '').toString());
      if (createdAt == null) continue;
      final day = createdAt.toLocal();
      final index = DateTime(
        day.year,
        day.month,
        day.day,
      ).difference(start).inDays;
      if (index >= 0 && index < totals.length) {
        totals[index] += AdminRevenueReport.rowAmount(row);
      }
    }
    return totals;
  }

  static List<Map<String, dynamic>> _reportRows(Map<String, dynamic> report) =>
      (report['rows'] as List?)
          ?.whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList() ??
      const <Map<String, dynamic>>[];

  static String _comparisonText(double current, double previous) {
    if (previous <= 0) {
      return current <= 0
          ? 'No revenue in either period.'
          : 'No revenue was recorded in the previous period.';
    }
    final percentage = ((current - previous) / previous) * 100;
    final direction = percentage > 0
        ? 'Up'
        : percentage < 0
        ? 'Down'
        : 'Unchanged';
    return '$direction ${percentage.abs().toStringAsFixed(1)}% vs previous '
        'period (₹${previous.toStringAsFixed(2)}).';
  }
}

class AdminRevenueReport {
  const AdminRevenueReport._();

  static List<Map<String, dynamic>> filterRows(
    List<Map<String, dynamic>> rows, {
    String? vendorId,
  }) {
    if (vendorId == null) return rows;
    return [
      for (final row in rows)
        if ((row['vendor_id'] ?? row['vendorId'])?.toString() == vendorId) row,
    ];
  }

  static double total(List<Map<String, dynamic>> rows) =>
      rows.fold<double>(0, (total, row) => total + rowAmount(row));

  static int orderCount(List<Map<String, dynamic>> rows) {
    final orderIds = <String>{};
    var unkeyedRows = 0;
    for (final row in rows) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) {
        unkeyedRows++;
      } else {
        orderIds.add(id);
      }
    }
    return orderIds.length + unkeyedRows;
  }

  static double rowAmount(Map<String, dynamic> row) {
    final paise =
        row['quoted_amount_paise'] ??
        row['quotedAmountPaise'] ??
        row['total_paise'];
    if (paise is num) return paise.toDouble() / 100;
    final amount = row['amount'];
    return amount is num ? amount.toDouble() : 0;
  }

  static List<_ServiceBreakdown> _byService(List<Map<String, dynamic>> rows) {
    final groups = <String, (int, double)>{};
    for (final row in rows) {
      final rawService = (row['service_code'] ?? row['serviceCode'] ?? '')
          .toString()
          .trim();
      final service = rawService.isEmpty ? 'Service not specified' : rawService;
      final current = groups[service] ?? (0, 0);
      groups[service] = (current.$1 + 1, current.$2 + rowAmount(row));
    }
    return [
      for (final entry in groups.entries)
        _ServiceBreakdown(
          service: entry.key,
          count: entry.value.$1,
          amount: entry.value.$2,
        ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
  }
}

class _ServiceBreakdown {
  const _ServiceBreakdown({
    required this.service,
    required this.count,
    required this.amount,
  });

  final String service;
  final int count;
  final double amount;
}

class _VendorFilterSelection {
  const _VendorFilterSelection(this.vendorId);

  final String? vendorId;
}

class _VendorFilterSheet extends StatefulWidget {
  const _VendorFilterSheet({required this.vendors, required this.selectedId});

  final List<AccountRecord> vendors;
  final String? selectedId;

  @override
  State<_VendorFilterSheet> createState() => _VendorFilterSheetState();
}

class _VendorFilterSheetState extends State<_VendorFilterSheet> {
  late String? _selectedId = widget.selectedId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        0,
        AppSpace.xl,
        AppSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filter sales by vendor',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpace.md),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                AppListRow(
                  leading: Icon(
                    _selectedId == null
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: 'All vendors',
                  onTap: () => setState(() => _selectedId = null),
                ),
                for (final vendor in widget.vendors)
                  AppListRow(
                    leading: Icon(
                      vendor.id == _selectedId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: vendor.title,
                    onTap: () => setState(() => _selectedId = vendor.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Reset',
                  onPressed: () => Navigator.pop(
                    context,
                    const _VendorFilterSelection(null),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: PrimaryButton(
                  label: 'Apply',
                  onPressed: () => Navigator.pop(
                    context,
                    _VendorFilterSelection(_selectedId),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
                      text:
                          'Urban Tanker report\n'
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
  return 'Unnamed vendor';
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
