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
    if (AuthFeatureFlags.newUiEnabled) {
      final vendors = ref.watch(dispatcherVendorsProvider);
      return ListView(
        padding: AppPageInsets.withSafeAreaBottom(
          context,
          AppPageInsets.standard,
        ),
        children: [
          AdminSalesReportPanel(vendors: vendors.value ?? const []),
          if (vendors.hasError) ...[
            const SizedBox(height: AppSpace.md),
            ErrorState(
              error: vendors.error!,
              message: friendlyError(vendors.error!),
              onRetry: () => ref.invalidate(dispatcherVendorsProvider),
            ),
          ],
        ],
      );
    }

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
            const _RevenueReport(),
            const SizedBox(height: AppSpace.xl),
            _VendorDirectory(vendors: items),
          ],
        );
      },
    );
  }
}

/// Sales report with day, week and month navigation.
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
  int _periodOffset = 0;
  String? _vendorId;
  bool _running = false;
  bool _sending = false;
  String? _error;
  List<Map<String, dynamic>>? _rows;

  static const _rangeLabels = ['Day', 'Week', 'Month'];
  static const _monthLabels = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  (DateTime, DateTime) _selectedWindow() {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    if (_rangeIndex == 0) {
      final selected = date.subtract(Duration(days: _periodOffset));
      return (selected, selected);
    }
    if (_rangeIndex == 1) {
      final start = date.subtract(
        Duration(days: date.weekday - 1 + 7 * _periodOffset),
      );
      final end = _periodOffset == 0
          ? date
          : start.add(const Duration(days: 6));
      return (start, end);
    }
    final start = DateTime(today.year, today.month - _periodOffset, 1);
    final end = _periodOffset == 0
        ? date
        : DateTime(start.year, start.month + 1, 0);
    return (start, end);
  }

  int get _maximumOffset => _rangeIndex == 0 ? 6 : 2;

  String _dateLabel(DateTime date) =>
      '${_monthLabels[date.month - 1]} ${date.day}';

  String _periodLabel((DateTime, DateTime) window) {
    if (_rangeIndex == 0) {
      if (_periodOffset == 0) return 'Today';
      if (_periodOffset == 1) return 'Yesterday';
      return _dateLabel(window.$1);
    }
    if (_rangeIndex == 1) {
      return _periodOffset == 0
          ? 'This week'
          : 'Week of ${_dateLabel(window.$1)}';
    }
    return _periodOffset == 0
        ? 'This month'
        : '${_monthLabels[window.$1.month - 1]} ${window.$1.year}';
  }

  Future<void> _changeRange(int index) async {
    setState(() {
      _rangeIndex = index;
      _periodOffset = 0;
    });
    await _run();
  }

  Future<void> _changePeriod(int direction) async {
    setState(() => _periodOffset += direction);
    await _run();
  }

  Future<void> _run() async {
    final window = _selectedWindow();
    final runReport =
        widget.loadReport ??
        ((Map<String, dynamic> body) =>
            ref.read(appControllerProvider).api.adminReport(body));

    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final report = await runReport({
        'type': 'revenue',
        'from': _isoDate(window.$1),
        'to': _isoDate(window.$2),
        if (_vendorId != null) 'vendorId': _vendorId,
      });
      if (!mounted) return;
      setState(() {
        _rows = _reportRows(report);
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

  Future<void> _openReportSettings() async {
    final selected = _selectedWindow();
    final emailRequest = await showAppBottomSheet<_ReportEmailRequest>(
      context,
      builder: (_) => _ReportEmailSettingsSheet(
        initialFrom: selected.$1,
        initialTo: selected.$2,
      ),
    );
    if (emailRequest == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final report = await ref.read(appControllerProvider).api.adminReport({
        'type': 'revenue',
        'from': _isoDate(emailRequest.from),
        'to': _isoDate(emailRequest.to),
        'email': emailRequest.email,
        if (_vendorId != null) 'vendorId': _vendorId,
      });
      if (report['emailSent'] != true) {
        throw const FormatException('The report email was not sent.');
      }
      if (mounted) {
        showAppSnack(
          context,
          'Sales report sent to ${emailRequest.email}.',
          variant: AppSnackVariant.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'Sales report could not be sent: ${friendlyError(error)}',
          variant: AppSnackVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows == null
        ? const <Map<String, dynamic>>[]
        : AdminRevenueReport.filterRows(_rows!, vendorId: _vendorId);
    final total = AdminRevenueReport.total(rows);
    final breakdown = AdminRevenueReport._byService(rows);
    final window = _selectedWindow();
    final values = _dailyValues(rows, window.$1, window.$2);
    final selectedVendor = widget.vendors
        .where((vendor) => vendor.id == _vendorId)
        .firstOrNull;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sales report',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Report settings and email',
                onPressed: _sending ? null : _openReportSettings,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          SegmentedTabs(
            labels: _rangeLabels,
            selectedIndex: _rangeIndex,
            onChanged: _changeRange,
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous ${_rangeLabels[_rangeIndex].toLowerCase()}',
                onPressed: _periodOffset < _maximumOffset
                    ? () => _changePeriod(1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _periodLabel(window),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next ${_rangeLabels[_rangeIndex].toLowerCase()}',
                onPressed: _periodOffset > 0 ? () => _changePeriod(-1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
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
          if (_running) ...[
            const SizedBox(height: AppSpace.md),
            const LinearProgressIndicator(),
          ],
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

  List<double> _dailyValues(
    List<Map<String, dynamic>> rows,
    DateTime start,
    DateTime end,
  ) {
    final days = end.difference(start).inDays + 1;
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

class _ReportEmailRequest {
  const _ReportEmailRequest({
    required this.from,
    required this.to,
    required this.email,
  });

  final DateTime from;
  final DateTime to;
  final String email;
}

class _ReportEmailSettingsSheet extends StatefulWidget {
  const _ReportEmailSettingsSheet({
    required this.initialFrom,
    required this.initialTo,
  });

  final DateTime initialFrom;
  final DateTime initialTo;

  @override
  State<_ReportEmailSettingsSheet> createState() =>
      _ReportEmailSettingsSheetState();
}

class _ReportEmailSettingsSheetState extends State<_ReportEmailSettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  late DateTime _from = widget.initialFrom;
  late DateTime _to = widget.initialTo;
  String? _dateError;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _chooseDate({required bool from}) async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (from) {
        _from = selected;
      } else {
        _to = selected;
      }
      _dateError = null;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_to.isBefore(_from)) {
      setState(
        () => _dateError = 'The end date must be on or after the start date.',
      );
      return;
    }
    Navigator.of(
      context,
    ).pop(_ReportEmailRequest(from: _from, to: _to, email: _email.text.trim()));
  }

  String _dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.gutter,
      AppSpace.sm,
      AppSpace.gutter,
      AppSpace.xl,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Report settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Choose a date range and recipient for the emailed dashboard and sales report.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpace.md),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: AppListRow(
              title: 'From',
              subtitle: _dateText(_from),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _chooseDate(from: true),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: AppListRow(
              title: 'To',
              subtitle: _dateText(_to),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _chooseDate(from: false),
            ),
          ),
          if (_dateError != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              _dateError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Recipient email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                  ? null
                  : 'Enter a valid email address.';
            },
          ),
          const SizedBox(height: AppSpace.lg),
          PrimaryButton(
            label: 'Send report',
            icon: Icons.send_outlined,
            onPressed: _submit,
          ),
        ],
      ),
    ),
  );
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
    final barWidth = values.length == 1 ? slot : slot * 0.6;
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
